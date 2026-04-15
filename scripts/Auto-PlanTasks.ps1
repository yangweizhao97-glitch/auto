param(
    [Parameter(Mandatory = $true)][string]$Request,
    [string[]]$Areas = @(),
    [ValidateSet("P0", "P1", "P2", "P3")][string]$Priority = "P2",
    [switch]$PreemptLowerPriority
)

. (Join-Path $PSScriptRoot "Shared.ps1")

function New-Keyword {
    param(
        [Parameter(Mandatory = $true)][int[]]$CodePoints
    )

    $chars = foreach ($code in $CodePoints) {
        [char]$code
    }
    return (-join $chars)
}

function Get-InferredAreas {
    param(
        [Parameter(Mandatory = $true)][string]$Text
    )

    $normalized = $Text.ToLowerInvariant()
    $areas = New-Object System.Collections.Generic.List[string]
    $zhFrontend = @(
        (New-Keyword -CodePoints @(0x524D, 0x7AEF)),
        (New-Keyword -CodePoints @(0x9875, 0x9762)),
        (New-Keyword -CodePoints @(0x6309, 0x94AE)),
        (New-Keyword -CodePoints @(0x7EC4, 0x4EF6))
    )
    $zhBackend = @(
        (New-Keyword -CodePoints @(0x540E, 0x7AEF)),
        (New-Keyword -CodePoints @(0x63A5, 0x53E3)),
        (New-Keyword -CodePoints @(0x670D, 0x52A1))
    )
    $zhData = @(
        (New-Keyword -CodePoints @(0x6570, 0x636E, 0x5E93)),
        (New-Keyword -CodePoints @(0x8868)),
        (New-Keyword -CodePoints @(0x8FC1, 0x79FB)),
        (New-Keyword -CodePoints @(0x6A21, 0x578B))
    )
    $zhTests = @(
        (New-Keyword -CodePoints @(0x6D4B, 0x8BD5)),
        (New-Keyword -CodePoints @(0x5355, 0x6D4B)),
        (New-Keyword -CodePoints @(0x96C6, 0x6210, 0x6D4B, 0x8BD5)),
        (New-Keyword -CodePoints @(0x8986, 0x76D6, 0x7387))
    )
    $zhDocs = @(
        (New-Keyword -CodePoints @(0x8BF4, 0x660E)),
        (New-Keyword -CodePoints @(0x6587, 0x6863))
    )
    $zhCi = @(
        (New-Keyword -CodePoints @(0x6D41, 0x6C34, 0x7EBF)),
        (New-Keyword -CodePoints @(0x6784, 0x5EFA, 0x811A, 0x672C))
    )

    $rules = @(
        @{ Name = "frontend"; Patterns = @("frontend", "ui", "page", "component", "view", "button", "screen") + $zhFrontend },
        @{ Name = "backend"; Patterns = @("backend", "server", "api", "endpoint", "service", "controller") + $zhBackend },
        @{ Name = "data"; Patterns = @("database", "db", "schema", "migration", "sql", "prisma", "model") + $zhData },
        @{ Name = "tests"; Patterns = @("test", "coverage", "jest", "pytest", "e2e", "unit test") + $zhTests },
        @{ Name = "docs"; Patterns = @("doc", "readme", "guide", "instruction") + $zhDocs },
        @{ Name = "ci"; Patterns = @("ci", "pipeline", "workflow", "github action", "build script") + $zhCi }
    )

    foreach ($rule in $rules) {
        foreach ($pattern in $rule.Patterns) {
            if ($normalized.Contains($pattern)) {
                if (-not $areas.Contains($rule.Name)) {
                    $areas.Add($rule.Name)
                }
                break
            }
        }
    }

    if ($areas.Count -eq 0) {
        $areas.Add("core")
    }

    return @($areas)
}

function Get-AreaScope {
    param(
        [Parameter(Mandatory = $true)][string]$Area
    )

    switch ($Area) {
        "frontend" { return @("src/", "app/", "pages/", "components/", "web/") }
        "backend" { return @("src/", "server/", "api/", "backend/") }
        "data" { return @("db/", "prisma/", "migrations/", "sql/", "src/") }
        "tests" { return @("tests/", "__tests__/", "src/") }
        "docs" { return @("docs/", "README.md") }
        "ci" { return @(".github/", "scripts/", "ci/") }
        default { return @("src/", "scripts/", "docs/") }
    }
}

function Get-AreaCriteria {
    param(
        [Parameter(Mandatory = $true)][string]$Area
    )

    switch ($Area) {
        "frontend" {
            return @(
                "ac.scope_only: changed files stay under src/, app/, pages/, components/, or web/",
                "ac.ui_behavior: tester evidence confirms requested UI behavior",
                "ac.validation: include at least one pass result from build/typecheck/lint/test",
                "ac.worker_md_report: worker returns a markdown report path under reports/results/"
            )
        }
        "backend" {
            return @(
                "ac.scope_only: changed files stay under src/, server/, api/, or backend/",
                "ac.api_behavior: tester evidence confirms expected API or service behavior",
                "ac.validation: include at least one pass result from build/typecheck/lint/test",
                "ac.worker_md_report: worker returns a markdown report path under reports/results/"
            )
        }
        "data" {
            return @(
                "ac.scope_only: changed files stay under db/, prisma/, migrations/, sql/, or src/",
                "ac.data_consistency: evidence documents schema or migration impact",
                "ac.validation: include at least one pass result from build/typecheck/lint/test",
                "ac.worker_md_report: worker returns a markdown report path under reports/results/"
            )
        }
        "tests" {
            return @(
                "ac.scope_only: changed files stay under tests/, __tests__/, or src/",
                "ac.test_delta: evidence lists updated or added test files",
                "ac.validation: include test command result with log path",
                "ac.worker_md_report: worker returns a markdown report path under reports/results/"
            )
        }
        "docs" {
            return @(
                "ac.scope_only: changed files stay under docs/ or README.md",
                "ac.docs_match: docs evidence reflects implemented behavior",
                "ac.validation: include doc review result in evidence",
                "ac.worker_md_report: worker returns a markdown report path under reports/results/"
            )
        }
        "ci" {
            return @(
                "ac.scope_only: changed files stay under .github/, scripts/, or ci/",
                "ac.pipeline_behavior: evidence describes workflow impact",
                "ac.validation: include pipeline-related command result in evidence",
                "ac.worker_md_report: worker returns a markdown report path under reports/results/"
            )
        }
        default {
            return @(
                "ac.scope_only: changed files stay in declared scope",
                "ac.behavior_match: implementation evidence matches request",
                "ac.validation: include at least one relevant check result",
                "ac.worker_md_report: worker returns a markdown report path under reports/results/"
            )
        }
    }
}

function Get-AreaTitle {
    param(
        [Parameter(Mandatory = $true)][string]$Area
    )

    switch ($Area) {
        "frontend" { return "Implement Frontend Changes" }
        "backend" { return "Implement Backend Changes" }
        "data" { return "Implement Data Changes" }
        "tests" { return "Add or Update Tests" }
        "docs" { return "Update Developer Docs" }
        "ci" { return "Update CI or Automation" }
        default { return "Implement Core Changes" }
    }
}

function Get-AreaAgentProfile {
    param(
        [Parameter(Mandatory = $true)][string]$Area
    )

    switch ($Area) {
        "frontend" { return "frontend_child" }
        "backend" { return "backend_child" }
        "tests" { return "test_child" }
        default { return "child_agent" }
    }
}

function Get-PriorityWeight {
    param(
        [Parameter(Mandatory = $true)][string]$PriorityValue
    )

    switch ($PriorityValue) {
        "P0" { return 0 }
        "P1" { return 1 }
        "P2" { return 2 }
        "P3" { return 3 }
        default { return 2 }
    }
}

function Get-NextTaskId {
    param(
        [Parameter(Mandatory = $true)]$Workflow
    )

    $maxId = 0
    foreach ($task in $Workflow.tasks) {
        if ($task.id -match "^task_(\d+)$") {
            $number = [int]$Matches[1]
            if ($number -gt $maxId) {
                $maxId = $number
            }
        }
    }
    return ("task_{0}" -f ($maxId + 1).ToString("000"))
}

function Get-NextRequestId {
    param(
        [Parameter(Mandatory = $true)]$Workflow
    )

    if ($null -eq $Workflow.requests) {
        $Workflow | Add-Member -NotePropertyName requests -NotePropertyValue @()
    }

    $maxId = 0
    foreach ($request in $Workflow.requests) {
        if ($request.id -match "^req_(\d+)$") {
            $number = [int]$Matches[1]
            if ($number -gt $maxId) {
                $maxId = $number
            }
        }
    }
    return ("req_{0}" -f ($maxId + 1).ToString("000"))
}

function New-TaskObject {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$RequestId,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][string]$OwnerRole,
        [ValidateSet("P0", "P1", "P2", "P3")][string]$PriorityValue = "P2",
        [AllowEmptyString()][string]$AgentProfile = "",
        [AllowEmptyString()][string]$ParentTaskId = "",
        [bool]$Preemptible = $true,
        [bool]$AllowScopeOverlap = $false,
        [Parameter(Mandatory = $true)][string[]]$Dependencies,
        [Parameter(Mandatory = $true)][string[]]$Scope,
        [Parameter(Mandatory = $true)][string[]]$ContextFiles,
        [Parameter(Mandatory = $true)][string[]]$Skills,
        [Parameter(Mandatory = $true)][string[]]$AcceptanceCriteria,
        [Parameter(Mandatory = $true)][int]$MaxRetries
    )

    return [pscustomobject]@{
        id = $Id
        request_id = $RequestId
        priority = $PriorityValue
        title = $Title
        description = $Description
        phase = $Phase
        owner_role = $OwnerRole
        agent_profile = $AgentProfile
        parent_task_id = $ParentTaskId
        preemptible = $Preemptible
        allow_scope_overlap = $AllowScopeOverlap
        status = "todo"
        dependencies = @($Dependencies)
        scope = @($Scope)
        context_files = @($ContextFiles)
        skills = @($Skills)
        acceptance_criteria = @($AcceptanceCriteria)
        retries = 0
        max_retries = $MaxRetries
        failure_reason = ""
        evidence = @()
        updated_at = ""
    }
}

$workflow = Read-Workflow
$defaultRetries = [int]$workflow.workflow.default_max_retries
$baselineTask = $workflow.tasks | Where-Object { $_.id -eq "task_001" } | Select-Object -First 1
if ($null -eq $baselineTask) {
    throw "Baseline task task_001 not found."
}

$resolvedAreas = @()
if ($Areas.Count -gt 0) {
    $resolvedAreas = @($Areas | ForEach-Object { $_.ToLowerInvariant() })
} else {
    $resolvedAreas = @(Get-InferredAreas -Text $Request)
}
$resolvedAreas = @($resolvedAreas | Select-Object -Unique)

$requestId = Get-NextRequestId -Workflow $workflow
$createdAt = (Get-Date).ToString("o")
$requestRecord = [pscustomobject]@{
    id = $requestId
    goal = $Request
    priority = $Priority
    status = "queued"
    preempt_lower_priority = [bool]$PreemptLowerPriority
    preemption_applied = $false
    preempted_tasks = @()
    created_at = $createdAt
}
$workflow.requests += $requestRecord

if ($PreemptLowerPriority -and $workflow.workflow.dispatch_policy.allow_preemption) {
    $newWeight = Get-PriorityWeight -PriorityValue $Priority
    $inProgressTasks = @($workflow.tasks | Where-Object { $_.status -eq "in_progress" })
    $preempted = New-Object System.Collections.Generic.List[string]

    foreach ($task in $inProgressTasks) {
        $taskPriority = "P2"
        if ($task.PSObject.Properties.Name -contains "priority" -and -not [string]::IsNullOrWhiteSpace($task.priority)) {
            $taskPriority = $task.priority
        } elseif (-not [string]::IsNullOrWhiteSpace($task.request_id)) {
            $taskRequest = Get-RequestRecord -Workflow $workflow -RequestId $task.request_id
            if ($null -ne $taskRequest -and $taskRequest.PSObject.Properties.Name -contains "priority" -and -not [string]::IsNullOrWhiteSpace($taskRequest.priority)) {
                $taskPriority = $taskRequest.priority
            }
        }

        $taskWeight = Get-PriorityWeight -PriorityValue $taskPriority
        $isPreemptible = $true
        if ($task.PSObject.Properties.Name -contains "preemptible") {
            $isPreemptible = [bool]$task.preemptible
        }

        if ($isPreemptible -and $taskWeight -gt $newWeight) {
            $task.status = "todo"
            $task.failure_reason = ("Preempted by request {0} ({1})" -f $requestId, $Priority)
            Add-TaskEvidence -Task $task -Evidence @("cmd=auto_preempt|result=skipped|log=logs/workflow-$(Get-Date -Format yyyyMMdd).log|artifact=request:$requestId")
            Set-TaskUpdatedAt -Task $task
            $preempted.Add($task.id) | Out-Null
        }
    }

    if ($preempted.Count -gt 0) {
        $requestRecord.preemption_applied = $true
        $requestRecord.preempted_tasks = @($preempted.ToArray())
    }
}

$plannedTasks = New-Object System.Collections.Generic.List[object]
$planTaskId = Get-NextTaskId -Workflow $workflow
$planDependencies = @("task_001")
$planTask = New-TaskObject `
    -Id $planTaskId `
    -RequestId $requestId `
    -Title ("Plan Request " + $requestId) `
    -Description ("Main AGENT plans and dispatches request " + $requestId + ": " + $Request) `
    -Phase "planning" `
    -OwnerRole "main_agent" `
    -PriorityValue $Priority `
    -AgentProfile "main_agent" `
    -ParentTaskId "" `
    -Preemptible $false `
    -AllowScopeOverlap $false `
    -Dependencies $planDependencies `
    -Scope @("tasks.json", "docs/", "reports/") `
    -ContextFiles @("AGENTS.md", "tasks.json", "docs/09-统一任务拆解方案.md") `
    -Skills @("planning") `
    -AcceptanceCriteria @(
        "ac.split_order: tasks are split by deliverable then code boundary then acceptance method",
        "ac.parallel_safety: parallel tasks do not overlap in unsafe scope",
        "ac.dispatch_ready: each child task has scope, context_files, and acceptance_criteria"
    ) `
    -MaxRetries $defaultRetries
$plannedTasks.Add($planTask) | Out-Null

$implementationIds = New-Object System.Collections.Generic.List[string]

foreach ($area in $resolvedAreas) {
    $taskId = Get-NextTaskId -Workflow ([pscustomobject]@{ tasks = @($workflow.tasks) + @($plannedTasks.ToArray()) })
    $implementationIds.Add($taskId) | Out-Null
    $plannedTasks.Add((New-TaskObject `
        -Id $taskId `
        -RequestId $requestId `
        -Title (Get-AreaTitle -Area $area) `
        -Description ("Implement request " + $requestId + " for area '" + $area + "': " + $Request) `
        -Phase "implementation" `
        -OwnerRole "child_agent" `
        -PriorityValue $Priority `
        -AgentProfile (Get-AreaAgentProfile -Area $area) `
        -ParentTaskId $planTaskId `
        -Preemptible $true `
        -AllowScopeOverlap $false `
        -Dependencies @($planTaskId) `
        -Scope (Get-AreaScope -Area $area) `
        -ContextFiles @("AGENTS.md", "tasks.json", "prompts/worker-handoff.md") `
        -Skills @("implementation") `
        -AcceptanceCriteria (Get-AreaCriteria -Area $area) `
        -MaxRetries $defaultRetries)) | Out-Null
}

$testTaskId = Get-NextTaskId -Workflow ([pscustomobject]@{ tasks = @($workflow.tasks) + @($plannedTasks.ToArray()) })
$plannedTasks.Add((New-TaskObject `
    -Id $testTaskId `
    -RequestId $requestId `
    -Title "Tester Validation" `
    -Description ("Tester AGENT validates request " + $requestId + " and returns findings to the main AGENT.") `
    -Phase "testing" `
    -OwnerRole "tester_agent" `
    -PriorityValue $Priority `
    -AgentProfile "tester_agent" `
    -ParentTaskId $planTaskId `
    -Preemptible $false `
    -AllowScopeOverlap $false `
    -Dependencies ($implementationIds.ToArray()) `
    -Scope @("logs/", "reports/", "tasks.json") `
    -ContextFiles @("AGENTS.md", "tasks.json", "prompts/tester-handoff.md") `
    -Skills @("testing", "verification") `
    -AcceptanceCriteria @(
        "ac.quality_checks: build/typecheck/lint/test results are recorded",
        "ac.report_format: tester output includes pass_or_fail, checks, findings, and evidence",
        "ac.evidence_schema: evidence lines follow cmd|result|log format",
        "ac.tester_md_report: tester returns a markdown report path under reports/results/"
    ) `
    -MaxRetries $defaultRetries)) | Out-Null

$acceptTaskId = Get-NextTaskId -Workflow ([pscustomobject]@{ tasks = @($workflow.tasks) + @($plannedTasks.ToArray()) })
$plannedTasks.Add((New-TaskObject `
    -Id $acceptTaskId `
    -RequestId $requestId `
    -Title "Main Acceptance Decision" `
    -Description ("Main AGENT accepts or retries request " + $requestId + " after tester feedback.") `
    -Phase "acceptance" `
    -OwnerRole "main_agent" `
    -PriorityValue $Priority `
    -AgentProfile "main_agent" `
    -ParentTaskId $planTaskId `
    -Preemptible $false `
    -AllowScopeOverlap $false `
    -Dependencies @($testTaskId) `
    -Scope @("logs/", "reports/", "tasks.json") `
    -ContextFiles @("AGENTS.md", "tasks.json", "prompts/tester-handoff.md") `
    -Skills @("review", "acceptance") `
    -AcceptanceCriteria @(
        "ac.decision_made: decision is one of accept, retry, or block",
        "ac.retry_route: retry decision points to optimization tasks",
        "ac.reason_present: retry or block includes a concrete reason"
    ) `
    -MaxRetries $defaultRetries)) | Out-Null

$summaryTaskId = Get-NextTaskId -Workflow ([pscustomobject]@{ tasks = @($workflow.tasks) + @($plannedTasks.ToArray()) })
$plannedTasks.Add((New-TaskObject `
    -Id $summaryTaskId `
    -RequestId $requestId `
    -Title "Summarize Delivery" `
    -Description ("Main AGENT summarizes only accepted work for request " + $requestId + ".") `
    -Phase "summary" `
    -OwnerRole "main_agent" `
    -PriorityValue $Priority `
    -AgentProfile "main_agent" `
    -ParentTaskId $planTaskId `
    -Preemptible $false `
    -AllowScopeOverlap $false `
    -Dependencies @($acceptTaskId) `
    -Scope @("reports/", "docs/", "tasks.json") `
    -ContextFiles @("tasks.json", "reports/") `
    -Skills @("docs") `
    -AcceptanceCriteria @(
        "ac.status_consistent: request status and task states are internally consistent",
        "ac.accepted_only: summary includes only accepted work",
        "ac.evidence_linked: summary references decision evidence paths"
    ) `
    -MaxRetries $defaultRetries)) | Out-Null

$workflow.project.goal = $Request
$workflow.tasks = @($workflow.tasks) + @($plannedTasks.ToArray())

$root = Get-RepoRoot
$reportDir = Join-Path $root "reports"
Ensure-Directory -Path $reportDir
$planReportPath = Join-Path $reportDir ("plan-" + $requestId + "-" + (New-Stamp) + ".md")

$lines = @()
$lines += "# Auto Plan"
$lines += ""
$lines += ("Request ID: {0}" -f $requestId)
$lines += ("Request: {0}" -f $Request)
$lines += ("Priority: {0}" -f $Priority)
$lines += ("Preempt Lower Priority: {0}" -f ([bool]$PreemptLowerPriority))
if ($requestRecord.preemption_applied -eq $true -and $requestRecord.preempted_tasks.Count -gt 0) {
    $lines += ("Preempted Tasks: {0}" -f ($requestRecord.preempted_tasks -join ", "))
}
$lines += ""
$lines += "Areas:"
foreach ($area in $resolvedAreas) {
    $lines += ("- {0}" -f $area)
}
$lines += ""
$lines += "Tasks:"
foreach ($task in $plannedTasks) {
    $depsText = "<none>"
    if ($task.dependencies.Count -gt 0) {
        $depsText = ($task.dependencies -join ",")
    }
    $lines += ("- {0} | {1} | owner={2} | priority={3} | deps={4}" -f $task.id, $task.title, $task.owner_role, $task.priority, $depsText)
}
$lines | Set-Content -LiteralPath $planReportPath -Encoding UTF8

$planTask.evidence = @("cmd=auto_plan|result=pass|log=logs/workflow-$(Get-Date -Format yyyyMMdd).log|artifact=$planReportPath")
Set-TaskUpdatedAt -Task $planTask
Write-Workflow -Workflow $workflow
Write-WorkflowLog -Message ("auto_plan request_id={0} report={1}" -f $requestId, $planReportPath)

Write-Output $planReportPath
