param(
    [Parameter(Mandatory = $true)][ValidateSet("Status", "Next", "Baseline", "Summary", "PrSummary", "DeliverySummary", "Queue", "Validate")][string]$Action
)

. (Join-Path $PSScriptRoot "Shared.ps1")

$workflow = Read-Workflow

function Get-PriorityWeight {
    param([string]$PriorityValue)

    switch ($PriorityValue) {
        "P0" { return 0 }
        "P1" { return 1 }
        "P2" { return 2 }
        "P3" { return 3 }
        default { return 2 }
    }
}

function Get-RequestPriority {
    param(
        [Parameter(Mandatory = $true)]$Workflow,
        [Parameter(Mandatory = $true)]$Task
    )

    if ($Task.PSObject.Properties.Name -contains "priority" -and -not [string]::IsNullOrWhiteSpace($Task.priority)) {
        return $Task.priority
    }

    if (-not [string]::IsNullOrWhiteSpace($Task.request_id)) {
        $request = Get-RequestRecord -Workflow $Workflow -RequestId $Task.request_id
        if ($null -ne $request -and $request.PSObject.Properties.Name -contains "priority" -and -not [string]::IsNullOrWhiteSpace($request.priority)) {
            return $request.priority
        }
    }

    return "P2"
}

function Test-ScopeOverlap {
    param(
        [string[]]$LeftScope,
        [string[]]$RightScope
    )

    if ($LeftScope.Count -eq 0 -or $RightScope.Count -eq 0) {
        return $false
    }

    foreach ($left in $LeftScope) {
        foreach ($right in $RightScope) {
            $leftNorm = $left.ToLowerInvariant().Trim()
            $rightNorm = $right.ToLowerInvariant().Trim()
            if ([string]::IsNullOrWhiteSpace($leftNorm) -or [string]::IsNullOrWhiteSpace($rightNorm)) {
                continue
            }
            if ($leftNorm -eq $rightNorm -or $leftNorm.StartsWith($rightNorm) -or $rightNorm.StartsWith($leftNorm)) {
                return $true
            }
        }
    }
    return $false
}

function Test-TaskConflict {
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [object[]]$InProgressTasks = @()
    )

    $candidateAllowOverlap = $false
    if ($Candidate.PSObject.Properties.Name -contains "allow_scope_overlap") {
        $candidateAllowOverlap = [bool]$Candidate.allow_scope_overlap
    }
    if ($candidateAllowOverlap) {
        return $false
    }

    if (@($InProgressTasks).Count -eq 0) {
        return $false
    }

    foreach ($active in $InProgressTasks) {
        $activeAllowOverlap = $false
        if ($active.PSObject.Properties.Name -contains "allow_scope_overlap") {
            $activeAllowOverlap = [bool]$active.allow_scope_overlap
        }
        if ($activeAllowOverlap) {
            continue
        }
        if (Test-ScopeOverlap -LeftScope @($Candidate.scope) -RightScope @($active.scope)) {
            return $true
        }
    }
    return $false
}

switch ($Action) {
    "Status" {
        & (Join-Path $PSScriptRoot "Get-WorkflowState.ps1")
        exit 0
    }
    "Baseline" {
        $reportPath = & (Join-Path $PSScriptRoot "Invoke-QualityGate.ps1") -OutputName "baseline"
        $baselineTask = Get-Task -Workflow $workflow -TaskId "task_001"
        $baselineEvidence = "cmd=workflow_baseline|result=pass|log=logs/workflow-{0}.log|artifact={1}" -f (Get-Date).ToString("yyyyMMdd"), $reportPath
        Add-TaskEvidence -Task $baselineTask -Evidence @($baselineEvidence)
        $baselineTask.status = "done"
        Set-TaskUpdatedAt -Task $baselineTask
        Write-Workflow -Workflow $workflow
        Write-WorkflowLog -Message ("baseline_complete report={0}" -f $reportPath)
        Write-Output ("Baseline recorded: {0}" -f $reportPath)
        exit 0
    }
    "Next" {
        $readyCandidates = @(Get-ReadyTasks -Workflow $workflow | Sort-Object `
            @{ Expression = { Get-PriorityWeight -PriorityValue (Get-RequestPriority -Workflow $workflow -Task $_) } ; Ascending = $true }, `
            @{ Expression = { $_.id } ; Ascending = $true })

        $inProgress = @($workflow.tasks | Where-Object { $_.status -eq "in_progress" })
        $ready = $null
        foreach ($candidate in $readyCandidates) {
            if (-not (Test-TaskConflict -Candidate $candidate -InProgressTasks $inProgress)) {
                $ready = $candidate
                break
            }
        }

        if ($null -eq $ready) {
            if ($readyCandidates.Count -gt 0) {
                Write-Output "No conflict-free ready tasks. Resolve scope conflicts or allow overlap explicitly."
            } else {
                Write-Output "No ready tasks."
            }
            exit 0
        }

        $ready.status = "in_progress"
        Set-TaskUpdatedAt -Task $ready
        Write-Workflow -Workflow $workflow
        Write-WorkflowLog -Message ("task_started task={0}" -f $ready.id)

        $taskRole = $ready.owner_role
        if ([string]::IsNullOrWhiteSpace($taskRole) -and $ready.PSObject.Properties.Name -contains "executor") {
            $taskRole = $ready.executor
        }
        if ([string]::IsNullOrWhiteSpace($taskRole)) {
            $taskRole = "child_agent"
        }
        $role = if ($workflow.roles.PSObject.Properties.Name -contains $taskRole) { $taskRole } else { "child_agent" }
        $promptPath = & (Join-Path $PSScriptRoot "New-HandoffPrompt.ps1") -TaskId $ready.id -Role $role
        $priorityText = Get-RequestPriority -Workflow $workflow -Task $ready

        Write-Output ("Next task: {0} ({1})" -f $ready.id, $ready.title)
        Write-Output ("Priority: {0}" -f $priorityText)
        Write-Output ("Role: {0}" -f $role)
        Write-Output ("Prompt: {0}" -f $promptPath)
        exit 0
    }
    "Summary" {
        & (Join-Path $PSScriptRoot "Write-WorkflowSummary.ps1")
        exit 0
    }
    "PrSummary" {
        & (Join-Path $PSScriptRoot "Write-PrSummary.ps1")
        exit 0
    }
    "DeliverySummary" {
        & (Join-Path $PSScriptRoot "Write-DeliverySummary.ps1")
        exit 0
    }
    "Queue" {
        & (Join-Path $PSScriptRoot "Get-WorkflowState.ps1")
        exit 0
    }
    "Validate" {
        & (Join-Path $PSScriptRoot "Validate-WorkflowContract.ps1")
        exit $LASTEXITCODE
    }
}
