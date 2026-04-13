param(
    [string]$Title = '',
    [string]$OutputPath = ''
)

. (Join-Path $PSScriptRoot 'Shared.ps1')

$workflow = Read-Workflow
$root = Get-RepoRoot
$reportDir = Join-Path $root 'reports'
Ensure-Directory -Path $reportDir

$titleText = $Title
if ([string]::IsNullOrWhiteSpace($titleText)) {
    $titleText = $workflow.project.goal
}

$doneTasks = @($workflow.tasks | Where-Object { $_.status -eq 'done' -and $_.id -ne 'task_001' })
$blockedTasks = @($workflow.tasks | Where-Object { $_.status -eq 'blocked' })
$latestGate = Get-ChildItem -LiteralPath $reportDir -Filter 'quality-gate-*.json' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$diffStat = 'No git diff stat available.'
$gitDir = Join-Path $root '.git'
if (Test-Path -LiteralPath $gitDir) {
    $diffOutput = & git -C $root diff --stat 2>$null
    if ($LASTEXITCODE -eq 0 -and $diffOutput) {
        $diffStat = ($diffOutput -join [Environment]::NewLine)
    }
}

$lines = @()
$lines += '# PR Summary'
$lines += ''
$lines += ('Title: {0}' -f $titleText)
$lines += ''
$lines += '## What Changed'
$lines += ''
if ($doneTasks.Count -eq 0) {
    $lines += '- No completed implementation tasks are recorded yet.'
} else {
    foreach ($task in $doneTasks) {
        $lines += ('- {0}: {1}' -f $task.id, $task.description)
    }
}

$lines += ''
$lines += '## Validation'
$lines += ''
if ($latestGate) {
    $lines += ('- Latest quality gate report: {0}' -f $latestGate.FullName)
} else {
    $lines += '- No quality gate report found.'
}

$lines += ''
$lines += '## Risks'
$lines += ''
if ($blockedTasks.Count -eq 0) {
    $lines += '- No blocked tasks recorded.'
} else {
    foreach ($task in $blockedTasks) {
        $reason = 'Blocked without reason.'
        if (-not [string]::IsNullOrWhiteSpace($task.failure_reason)) {
            $reason = $task.failure_reason
        }
        $lines += ('- {0}: {1}' -f $task.id, $reason)
    }
}

$lines += ''
$lines += '## Diff Stat'
$lines += ''
$lines += '```text'
$lines += $diffStat
$lines += '```'

$finalPath = $OutputPath
if ([string]::IsNullOrWhiteSpace($finalPath)) {
    $fileName = 'pr-summary-' + (New-Stamp) + '.md'
    $finalPath = Join-Path $reportDir $fileName
}

$lines | Set-Content -LiteralPath $finalPath -Encoding UTF8
Write-WorkflowLog -Message ('pr_summary path={0}' -f $finalPath)
Write-Output $finalPath
