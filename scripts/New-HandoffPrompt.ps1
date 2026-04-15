param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)][ValidateSet("planner", "worker", "reviewer", "main_agent", "child_agent", "tester_agent")][string]$Role
)

. (Join-Path $PSScriptRoot "Shared.ps1")

function Get-ArtifactPathFromEvidence {
    param(
        [string]$EvidenceLine
    )

    if ([string]::IsNullOrWhiteSpace($EvidenceLine)) {
        return ""
    }

    if ($EvidenceLine -match "\|artifact=([^|]+)$") {
        return $Matches[1].Trim()
    }

    if ($EvidenceLine -notmatch "\|" -and $EvidenceLine.Trim().ToLowerInvariant().EndsWith(".md")) {
        return $EvidenceLine.Trim()
    }

    return ""
}

function Resolve-ArtifactPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PathValue
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return (Join-Path $RepoRoot $PathValue)
}

function New-ResultTemplate {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)][string]$RoleValue,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $lines = @()
    $lines += "# Task Result"
    $lines += ""
    $lines += ("task_id: {0}" -f $Task.id)
    $lines += ("request_id: {0}" -f $Task.request_id)
    $lines += ("role: {0}" -f $RoleValue)
    $lines += ("phase: {0}" -f $Task.phase)
    $lines += ("updated_at: {0}" -f (Get-Date).ToString("o"))
    $lines += ""

    switch ($Task.phase) {
        "implementation" {
            $lines += "## Changed Files"
            $lines += "- "
            $lines += ""
            $lines += "## Implementation Summary"
            $lines += "- "
            $lines += ""
            $lines += "## Validation Notes"
            $lines += "- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>"
            $lines += ""
            $lines += "## Remaining Risks"
            $lines += "- "
            break
        }
        "testing" {
            $lines += "## Overall Result"
            $lines += "PASS|FAIL"
            $lines += ""
            $lines += "## Checks Performed"
            $lines += "- "
            $lines += ""
            $lines += "## Behavior Findings"
            $lines += "- "
            $lines += ""
            $lines += "## Evidence"
            $lines += "- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>"
            $lines += ""
            $lines += "## Suggested Optimization"
            $lines += "- "
            break
        }
        "acceptance" {
            $lines += "## Decision"
            $lines += "accept|retry|block"
            $lines += ""
            $lines += "## Reason"
            $lines += "- "
            $lines += ""
            $lines += "## Evidence"
            $lines += "- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>"
            break
        }
        default {
            $lines += "## Summary"
            $lines += "- "
            $lines += ""
            $lines += "## Validation"
            $lines += "- cmd=<command>|result=<pass|fail|skipped>|log=<path>|artifact=<path-or-url>"
            $lines += ""
            $lines += "## Risks"
            $lines += "- "
            break
        }
    }

    $lines | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

$workflow = Read-Workflow
$task = Get-Task -Workflow $workflow -TaskId $TaskId
$root = Get-RepoRoot
$profile = $Role
if ($task.PSObject.Properties.Name -contains "agent_profile" -and -not [string]::IsNullOrWhiteSpace($task.agent_profile)) {
    $profile = $task.agent_profile
}
$templateFile = switch ($profile) {
    "planner" { "planner.md" }
    "worker" { "worker-handoff.md" }
    "reviewer" { "reviewer-gate.md" }
    "main_agent" { "planner.md" }
    "child_agent" { "worker-handoff.md" }
    "tester_agent" { "tester-handoff.md" }
    "frontend_child" { "frontend-child.md" }
    "backend_child" { "backend-child.md" }
    "test_child" { "test-child.md" }
    "optimization_child" { "optimization-handoff.md" }
    default { "worker-handoff.md" }
}
$templatePath = Join-Path $root ("prompts/{0}" -f $templateFile)
$reportDir = Join-Path $root "reports"
Ensure-Directory -Path $reportDir

$template = Get-Content -Raw -LiteralPath $templatePath
$scopeText = if ($task.scope.Count -gt 0) { $task.scope -join ", " } else { "<none>" }
$contextText = if ($task.context_files.Count -gt 0) { $task.context_files -join ", " } else { "<none>" }
$criteriaText = if ($task.acceptance_criteria.Count -gt 0) { $task.acceptance_criteria -join "; " } else { "<none>" }
$goal = $task.description
$failureText = "<none>"
if ($task.PSObject.Properties.Name -contains "failure_reason" -and -not [string]::IsNullOrWhiteSpace($task.failure_reason)) {
    $failureText = $task.failure_reason
}
$evidenceText = "<none>"
if ($task.PSObject.Properties.Name -contains "evidence" -and $task.evidence.Count -gt 0) {
    $evidenceText = ($task.evidence -join ", ")
}

$resultDir = Join-Path $reportDir "results"
$handoffDir = Join-Path $reportDir "handoff"
Ensure-Directory -Path $resultDir
Ensure-Directory -Path $handoffDir

$stamp = New-Stamp
$writebackReportPath = Join-Path $resultDir ("result-{0}-{1}-{2}.md" -f $task.id, $Role, $stamp)
New-ResultTemplate -Task $task -RoleValue $Role -OutputPath $writebackReportPath

$requestGoal = "<none>"
if (-not [string]::IsNullOrWhiteSpace($task.request_id)) {
    $requestRecord = Get-RequestRecord -Workflow $workflow -RequestId $task.request_id
    if ($null -ne $requestRecord -and $requestRecord.PSObject.Properties.Name -contains "goal" -and -not [string]::IsNullOrWhiteSpace($requestRecord.goal)) {
        $requestGoal = $requestRecord.goal
    }
}

$packetLines = @()
$packetLines += "# Task Handoff Packet"
$packetLines += ""
$packetLines += ("generated_at: {0}" -f (Get-Date).ToString("o"))
$packetLines += ("task_id: {0}" -f $task.id)
$packetLines += ("request_id: {0}" -f $task.request_id)
$packetLines += ("role: {0}" -f $Role)
$packetLines += ("phase: {0}" -f $task.phase)
$packetLines += ""
$packetLines += "## Request Goal"
$packetLines += $requestGoal
$packetLines += ""
$packetLines += "## Task Contract"
$packetLines += ("- title: {0}" -f $task.title)
$packetLines += ("- description: {0}" -f $task.description)
$packetLines += ("- scope: {0}" -f $scopeText)
$packetLines += ("- context_files: {0}" -f $contextText)
$packetLines += ("- acceptance_criteria: {0}" -f $criteriaText)
$packetLines += ""
$packetLines += "## Context Files"
if ($task.context_files.Count -gt 0) {
    foreach ($contextFile in $task.context_files) {
        $packetLines += ("- {0}" -f $contextFile)
    }
} else {
    $packetLines += "- <none>"
}
$packetLines += ""
$packetLines += "## Dependency Snapshot"
if ($task.dependencies.Count -eq 0) {
    $packetLines += "- <none>"
} else {
    foreach ($dependencyId in $task.dependencies) {
        $dependencyTask = Get-Task -Workflow $workflow -TaskId $dependencyId
        $packetLines += ("### {0} - {1}" -f $dependencyTask.id, $dependencyTask.title)
        $packetLines += ("- status: {0}" -f $dependencyTask.status)
        $packetLines += ("- failure_reason: {0}" -f $(if ([string]::IsNullOrWhiteSpace($dependencyTask.failure_reason)) { "<none>" } else { $dependencyTask.failure_reason }))
        $packetLines += "- evidence:"
        if ($dependencyTask.evidence.Count -gt 0) {
            foreach ($evidenceLine in $dependencyTask.evidence) {
                $packetLines += ("  - {0}" -f $evidenceLine)
            }
        } else {
            $packetLines += "  - <none>"
        }
        $packetLines += "- md_artifacts:"
        $artifactAdded = $false
        foreach ($evidenceLine in $dependencyTask.evidence) {
            $artifactPath = Get-ArtifactPathFromEvidence -EvidenceLine $evidenceLine
            if ([string]::IsNullOrWhiteSpace($artifactPath)) {
                continue
            }
            if (-not $artifactPath.ToLowerInvariant().EndsWith(".md")) {
                continue
            }
            $resolved = Resolve-ArtifactPath -RepoRoot $root -PathValue $artifactPath
            if (Test-Path -LiteralPath $resolved) {
                $packetLines += ("  - {0}" -f $resolved)
            } else {
                $packetLines += ("  - {0} (missing)" -f $artifactPath)
            }
            $artifactAdded = $true
        }
        if (-not $artifactAdded) {
            $packetLines += "  - <none>"
        }
        $packetLines += ""
    }
}

$packetLines += "## Execution Rules"
$packetLines += "- Read this packet first and treat it as the primary handoff source."
$packetLines += "- Do not rely on prior chat context; if details are missing, report the gap in result markdown."
$packetLines += ("- Write the final task result to: {0}" -f $writebackReportPath)
$packetLines += "- Return the markdown report path to the main AGENT."

$handoffPacketPath = Join-Path $handoffDir ("packet-{0}-{1}-{2}.md" -f $task.id, $Role, $stamp)
$packetLines | Set-Content -LiteralPath $handoffPacketPath -Encoding UTF8

$content = $template
$content = $content.Replace("{{task_id}}", $task.id)
$content = $content.Replace("{{title}}", $task.title)
$content = $content.Replace("{{description}}", $task.description)
$content = $content.Replace("{{goal}}", $goal)
$content = $content.Replace("{{scope}}", $scopeText)
$content = $content.Replace("{{context_files}}", $contextText)
$content = $content.Replace("{{acceptance_criteria}}", $criteriaText)
$content = $content.Replace("{{failure_reason}}", $failureText)
$content = $content.Replace("{{evidence}}", $evidenceText)
$content = $content.Replace("{{handoff_packet}}", $handoffPacketPath)
$content = $content.Replace("{{writeback_report}}", $writebackReportPath)

$outputPath = Join-Path $reportDir ("prompt-{0}-{1}-{2}.md" -f $task.id, $Role, $stamp)
Set-Content -LiteralPath $outputPath -Value $content -Encoding UTF8

Write-WorkflowLog -Message ("generated_prompt task={0} role={1} path={2} packet={3} result={4}" -f $task.id, $Role, $outputPath, $handoffPacketPath, $writebackReportPath)
Write-Output $outputPath
