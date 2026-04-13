param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)][ValidateSet("PASS", "FAIL")][string]$Result,
    [string]$FailureReason = "",
    [string[]]$Evidence = @(),
    [string[]]$RetryTaskIds = @()
)

. (Join-Path $PSScriptRoot "Shared.ps1")

$workflow = Read-Workflow
$testerTask = Get-Task -Workflow $workflow -TaskId $TaskId

if ($testerTask.owner_role -ne "tester_agent") {
    throw "Task $TaskId is not owned by tester_agent."
}

$requestId = $testerTask.request_id
if ([string]::IsNullOrWhiteSpace($requestId)) {
    throw "Tester task $TaskId does not have a request_id."
}

$acceptanceTask = $workflow.tasks | Where-Object {
    $_.request_id -eq $requestId -and $_.phase -eq "acceptance"
} | Select-Object -First 1

if ($Result -eq "PASS") {
    $testerTask.status = "done"
    $testerTask.failure_reason = ""
    Add-TaskEvidence -Task $testerTask -Evidence $Evidence
    Set-TaskUpdatedAt -Task $testerTask
    Set-RequestStatus -Workflow $workflow -RequestId $requestId -Status "tested"

    if ($null -ne $acceptanceTask -and $acceptanceTask.status -eq "blocked") {
        $acceptanceTask.status = "todo"
        $acceptanceTask.failure_reason = ""
        Set-TaskUpdatedAt -Task $acceptanceTask
    }

    Write-Workflow -Workflow $workflow
    Write-WorkflowLog -Message ("tester_feedback pass task={0} request={1}" -f $TaskId, $requestId)
    Write-Output ("Tester result accepted for {0}" -f $TaskId)
    exit 0
}

if ([string]::IsNullOrWhiteSpace($FailureReason)) {
    throw "FailureReason is required when Result is FAIL."
}

$testerTask.retries = [int]$testerTask.retries + 1
$testerTask.failure_reason = $FailureReason
Add-TaskEvidence -Task $testerTask -Evidence $Evidence

$retryTargets = @()
if ($RetryTaskIds.Count -gt 0) {
    foreach ($retryTaskId in $RetryTaskIds) {
        $retryTargets += Get-Task -Workflow $workflow -TaskId $retryTaskId
    }
} else {
    $retryTargets = Get-ImplementationTasksByRequest -Workflow $workflow -RequestId $requestId
}

$optimizationPrompts = @()

foreach ($task in $retryTargets) {
    $task.status = "todo"
    $task.failure_reason = $FailureReason
    $task.retries = [int]$task.retries + 1
    Add-TaskEvidence -Task $task -Evidence $Evidence
    Set-TaskUpdatedAt -Task $task
}

if ([int]$testerTask.retries -ge [int]$testerTask.max_retries) {
    $testerTask.status = "blocked"
    Set-RequestStatus -Workflow $workflow -RequestId $requestId -Status "blocked"
    if ($null -ne $acceptanceTask) {
        $acceptanceTask.status = "blocked"
        $acceptanceTask.failure_reason = "Tester retries exhausted for request " + $requestId
        Set-TaskUpdatedAt -Task $acceptanceTask
    }
} else {
    $testerTask.status = "todo"
    Set-RequestStatus -Workflow $workflow -RequestId $requestId -Status "retrying"
}

Set-TaskUpdatedAt -Task $testerTask
Write-Workflow -Workflow $workflow

foreach ($task in $retryTargets) {
    $optimizationPrompts += & (Join-Path $PSScriptRoot "New-OptimizationPrompt.ps1") -TaskId $task.id
}

Write-WorkflowLog -Message ("tester_feedback fail task={0} request={1} retries={2}" -f $TaskId, $requestId, $testerTask.retries)
Write-Output ("Tester result failed for {0}; child tasks were returned for optimization." -f $TaskId)
if ($optimizationPrompts.Count -gt 0) {
    Write-Output "Optimization Prompts:"
    foreach ($prompt in $optimizationPrompts) {
        Write-Output $prompt
    }
}
