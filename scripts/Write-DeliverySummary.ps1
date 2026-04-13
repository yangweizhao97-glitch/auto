param(
    [string]$OutputPath = ""
)

. (Join-Path $PSScriptRoot "Shared.ps1")

$workflow = Read-Workflow
$root = Get-RepoRoot
$reportDir = Join-Path $root "reports"
Ensure-Directory -Path $reportDir

$doneTasks = @($workflow.tasks | Where-Object { $_.status -eq "done" })
$blockedTasks = @($workflow.tasks | Where-Object { $_.status -eq "blocked" })
$todoTasks = @($workflow.tasks | Where-Object { $_.status -eq "todo" -or $_.status -eq "in_progress" })

$lines = @()
$lines += "# Delivery Summary"
$lines += ""
$lines += ("Goal: {0}" -f $workflow.project.goal)
$lines += ""
$lines += "## Completed"
$lines += ""
if ($doneTasks.Count -eq 0) {
    $lines += "- No tasks are complete yet."
} else {
    foreach ($task in $doneTasks) {
        $lines += ("- {0}: {1}" -f $task.id, $task.title)
    }
}
$lines += ""
$lines += "## Remaining"
$lines += ""
if ($todoTasks.Count -eq 0) {
    $lines += "- No remaining tasks."
} else {
    foreach ($task in $todoTasks) {
        $lines += ("- {0}: {1} ({2})" -f $task.id, $task.title, $task.status)
    }
}
$lines += ""
$lines += "## Blocked"
$lines += ""
if ($blockedTasks.Count -eq 0) {
    $lines += "- No blocked tasks."
} else {
    foreach ($task in $blockedTasks) {
        $reason = "No reason recorded."
        if (-not [string]::IsNullOrWhiteSpace($task.failure_reason)) {
            $reason = $task.failure_reason
        }
        $lines += ("- {0}: {1}" -f $task.id, $reason)
    }
}
$lines += ""
$lines += "## Recommended Next Steps"
$lines += ""
if ($blockedTasks.Count -gt 0) {
    $lines += "- Resolve blocked tasks before closing the delivery."
}
if ($todoTasks.Count -gt 0) {
    $lines += "- Continue the workflow from the next ready task."
}
if ($blockedTasks.Count -eq 0 -and $todoTasks.Count -eq 0) {
    $lines += "- Delivery is ready for final review or release."
}

$finalPath = ""
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $finalPath = Join-Path $reportDir ("delivery-summary-" + (New-Stamp) + ".md")
} else {
    $finalPath = $OutputPath
}
$lines | Set-Content -LiteralPath $finalPath -Encoding UTF8
Write-WorkflowLog -Message ("delivery_summary path={0}" -f $finalPath)
Write-Output $finalPath
