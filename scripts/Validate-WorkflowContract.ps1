param(
    [switch]$AsJson
)

. (Join-Path $PSScriptRoot "Shared.ps1")

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

function Test-EvidenceFormat {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }

    if ($Line -notmatch "\|") {
        return $true
    }

    return ($Line -match "^cmd=.+\|result=(pass|fail|skipped)\|log=.+(\|artifact=.+)?$")
}

$workflow = Read-Workflow
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$allowedPriorities = @("P0", "P1", "P2", "P3")
$allowedStatuses = @("todo", "in_progress", "done", "blocked")

if ([int]$workflow.workflow.default_max_retries -lt 1) {
    $errors.Add("workflow.default_max_retries must be >= 1") | Out-Null
}

if ($null -eq $workflow.workflow.dispatch_policy) {
    $errors.Add("workflow.dispatch_policy is missing") | Out-Null
}

$taskMap = Get-TaskMap -Workflow $workflow

foreach ($request in $workflow.requests) {
    if (-not ($allowedPriorities -contains $request.priority)) {
        $errors.Add(("request {0} has invalid priority {1}" -f $request.id, $request.priority)) | Out-Null
    }
}

foreach ($task in $workflow.tasks) {
    if (-not ($allowedStatuses -contains $task.status)) {
        $errors.Add(("task {0} has invalid status {1}" -f $task.id, $task.status)) | Out-Null
    }

    if ($task.PSObject.Properties.Name -contains "priority") {
        if (-not ($allowedPriorities -contains $task.priority)) {
            $errors.Add(("task {0} has invalid priority {1}" -f $task.id, $task.priority)) | Out-Null
        }
    } else {
        $warnings.Add(("task {0} missing priority, defaulting to P2" -f $task.id)) | Out-Null
    }

    $maxRetries = [int]$task.max_retries
    if ($maxRetries -lt 1) {
        $errors.Add(("task {0} has invalid max_retries {1}" -f $task.id, $task.max_retries)) | Out-Null
    }
    if ([int]$task.retries -gt $maxRetries) {
        $errors.Add(("task {0} retries ({1}) exceed max_retries ({2})" -f $task.id, $task.retries, $maxRetries)) | Out-Null
    }

    foreach ($depId in $task.dependencies) {
        if (-not $taskMap.ContainsKey($depId)) {
            $errors.Add(("task {0} has missing dependency {1}" -f $task.id, $depId)) | Out-Null
        }
    }

    if ($task.status -eq "in_progress") {
        foreach ($depId in $task.dependencies) {
            if ($taskMap.ContainsKey($depId) -and $taskMap[$depId].status -ne "done") {
                $errors.Add(("task {0} is in_progress but dependency {1} is {2}" -f $task.id, $depId, $taskMap[$depId].status)) | Out-Null
            }
        }
    }

    if ($task.acceptance_criteria.Count -eq 0) {
        $errors.Add(("task {0} has empty acceptance_criteria" -f $task.id)) | Out-Null
    } else {
        foreach ($ac in $task.acceptance_criteria) {
            if ($ac -notmatch "^ac\.[a-z0-9_.-]+: .+") {
                $warnings.Add(("task {0} has non-standard acceptance criterion: {1}" -f $task.id, $ac)) | Out-Null
            }
        }
    }

    foreach ($evidence in $task.evidence) {
        if (-not (Test-EvidenceFormat -Line $evidence)) {
            $errors.Add(("task {0} has invalid evidence line: {1}" -f $task.id, $evidence)) | Out-Null
        }
        if ($evidence -notmatch "\|") {
            $warnings.Add(("task {0} uses legacy evidence path format: {1}" -f $task.id, $evidence)) | Out-Null
        }
    }
}

$inProgress = @($workflow.tasks | Where-Object { $_.status -eq "in_progress" })
for ($i = 0; $i -lt $inProgress.Count; $i++) {
    for ($j = $i + 1; $j -lt $inProgress.Count; $j++) {
        $left = $inProgress[$i]
        $right = $inProgress[$j]
        $leftAllow = $false
        $rightAllow = $false
        if ($left.PSObject.Properties.Name -contains "allow_scope_overlap") {
            $leftAllow = [bool]$left.allow_scope_overlap
        }
        if ($right.PSObject.Properties.Name -contains "allow_scope_overlap") {
            $rightAllow = [bool]$right.allow_scope_overlap
        }
        if ($leftAllow -or $rightAllow) {
            continue
        }
        if (Test-ScopeOverlap -LeftScope @($left.scope) -RightScope @($right.scope)) {
            $errors.Add(("in_progress scope conflict between {0} and {1}" -f $left.id, $right.id)) | Out-Null
        }
    }
}

$result = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    status = $(if ($errors.Count -eq 0) { "pass" } else { "fail" })
    error_count = $errors.Count
    warning_count = $warnings.Count
    errors = @($errors)
    warnings = @($warnings)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 20
} else {
    Write-Output ("Contract Status: {0}" -f $result.status)
    Write-Output ("Errors: {0}" -f $result.error_count)
    Write-Output ("Warnings: {0}" -f $result.warning_count)
    if ($result.errors.Count -gt 0) {
        Write-Output ""
        Write-Output "Error Details:"
        foreach ($item in $result.errors) {
            Write-Output ("- {0}" -f $item)
        }
    }
    if ($result.warnings.Count -gt 0) {
        Write-Output ""
        Write-Output "Warning Details:"
        foreach ($item in $result.warnings) {
            Write-Output ("- {0}" -f $item)
        }
    }
}

if ($errors.Count -gt 0) {
    exit 1
}

exit 0
