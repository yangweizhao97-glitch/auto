param(
    [Parameter(Mandatory = $true)][string]$Request,
    [ValidateSet("P0", "P1", "P2", "P3")][string]$Priority = "P2",
    [string[]]$Areas = @(),
    [switch]$PreemptLowerPriority
)

. (Join-Path $PSScriptRoot "Shared.ps1")

function Invoke-CheckedScript {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [hashtable]$Arguments = @{}
    )

    $output = & $ScriptPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $message = "Script failed: {0} (exit={1})" -f $ScriptPath, $exitCode
        if ($output.Count -gt 0) {
            $message += "`n" + ($output -join [Environment]::NewLine)
        }
        throw $message
    }
    return @($output)
}

$statusScript = Join-Path $PSScriptRoot "Invoke-Workflow.ps1"
$validateScript = Join-Path $PSScriptRoot "Validate-WorkflowContract.ps1"
$autoPlanScript = Join-Path $PSScriptRoot "Auto-PlanTasks.ps1"

# 1) Status snapshot
$statusBefore = Invoke-CheckedScript -ScriptPath $statusScript -Arguments @{ Action = "Status" }

# 2) Contract validation
$validateBefore = Invoke-CheckedScript -ScriptPath $validateScript

# 3) Baseline on first run
$workflow = Read-Workflow
$baselineReport = ""
$baselineTask = $workflow.tasks | Where-Object { $_.id -eq "task_001" } | Select-Object -First 1
if ($null -ne $baselineTask -and $baselineTask.status -ne "done") {
    $baselineOutput = Invoke-CheckedScript -ScriptPath $statusScript -Arguments @{ Action = "Baseline" }
    if (@($baselineOutput).Count -gt 0) {
        $baselineReport = (@($baselineOutput))[-1]
    }
}

# 4) Auto plan the incoming requirement
$planArgs = @{
    Request = $Request
    Priority = $Priority
}
if ($Areas.Count -gt 0) {
    $planArgs["Areas"] = $Areas
}
if ($PreemptLowerPriority) {
    $planArgs["PreemptLowerPriority"] = $true
}
$planOutput = Invoke-CheckedScript -ScriptPath $autoPlanScript -Arguments $planArgs
$planReport = if (@($planOutput).Count -gt 0) { (@($planOutput))[-1] } else { "" }

# 5) Dispatch next task
$nextOutput = Invoke-CheckedScript -ScriptPath $statusScript -Arguments @{ Action = "Next" }

# 6) Final status snapshot
$statusAfter = Invoke-CheckedScript -ScriptPath $statusScript -Arguments @{ Action = "Status" }

Write-Output "Request intake completed."
Write-Output ("Request: {0}" -f $Request)
Write-Output ("Priority: {0}" -f $Priority)
if (-not [string]::IsNullOrWhiteSpace($baselineReport)) {
    Write-Output ("Baseline: {0}" -f $baselineReport)
}
if (-not [string]::IsNullOrWhiteSpace($planReport)) {
    Write-Output ("PlanReport: {0}" -f $planReport)
}
Write-Output ""
Write-Output "Next Task Dispatch:"
foreach ($line in $nextOutput) {
    Write-Output $line
}
Write-Output ""
Write-Output "Workflow Status:"
foreach ($line in $statusAfter) {
    Write-Output $line
}
