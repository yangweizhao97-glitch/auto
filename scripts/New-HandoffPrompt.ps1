param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)][ValidateSet("planner", "worker", "reviewer", "main_agent", "child_agent", "tester_agent")][string]$Role
)

. (Join-Path $PSScriptRoot "Shared.ps1")

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

$outputPath = Join-Path $reportDir ("prompt-{0}-{1}-{2}.md" -f $task.id, $Role, (New-Stamp))
Set-Content -LiteralPath $outputPath -Value $content -Encoding UTF8

Write-WorkflowLog -Message ("generated_prompt task={0} role={1} path={2}" -f $task.id, $Role, $outputPath)
Write-Output $outputPath
