. (Join-Path $PSScriptRoot "Shared.ps1")

$workflow = Read-Workflow
$root = Get-RepoRoot
$reportDir = Join-Path $root "reports"
Ensure-Directory -Path $reportDir

$done = @($workflow.tasks | Where-Object { $_.status -eq "done" })
$blocked = @($workflow.tasks | Where-Object { $_.status -eq "blocked" })
$inProgress = @($workflow.tasks | Where-Object { $_.status -eq "in_progress" })
$todo = @($workflow.tasks | Where-Object { $_.status -eq "todo" })

$lines = @()
$lines += "# Workflow Summary"
$lines += ""
$lines += ("Generated: {0}" -f (Get-Date).ToString("o"))
$lines += ""
$lines += "## Counts"
$lines += ""
$lines += ("- done: {0}" -f $done.Count)
$lines += ("- blocked: {0}" -f $blocked.Count)
$lines += ("- in_progress: {0}" -f $inProgress.Count)
$lines += ("- todo: {0}" -f $todo.Count)
$lines += ""
$lines += "## Tasks"
$lines += ""

foreach ($task in $workflow.tasks) {
    $lines += ("### {0} - {1}" -f $task.id, $task.title)
    $lines += ("- status: {0}" -f $task.status)
    $lines += ("- retries: {0}" -f $task.retries)
    $lines += ("- updated_at: {0}" -f $task.updated_at)
    $lines += ("- failure_reason: {0}" -f ($(if ([string]::IsNullOrWhiteSpace($task.failure_reason)) { "<none>" } else { $task.failure_reason })))
    $evidence = if ($task.evidence.Count -gt 0) { $task.evidence -join ", " } else { "<none>" }
    $lines += ("- evidence: {0}" -f $evidence)
    $lines += ""
}

$summaryPath = Join-Path $reportDir ("workflow-summary-{0}.md" -f (New-Stamp))
$lines | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-WorkflowLog -Message ("summary_written path={0}" -f $summaryPath)

Write-Output $summaryPath

