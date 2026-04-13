param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)][ValidateSet("accept", "retry", "block")][string]$Decision,
    [string]$Reason = "",
    [string[]]$Evidence = @()
)

. (Join-Path $PSScriptRoot "Shared.ps1")

$workflow = Read-Workflow
$task = Get-Task -Workflow $workflow -TaskId $TaskId

if ($task.phase -ne "acceptance") {
    throw "Task $TaskId is not an acceptance task."
}

$requestId = $task.request_id
$summaryTask = $workflow.tasks | Where-Object {
    $_.request_id -eq $requestId -and $_.phase -eq "summary"
} | Select-Object -First 1

if ($Decision -eq "accept") {
    $task.status = "done"
    $task.failure_reason = ""
    Add-TaskEvidence -Task $task -Evidence $Evidence
    Set-TaskUpdatedAt -Task $task
    Set-RequestStatus -Workflow $workflow -RequestId $requestId -Status "accepted"
    if ($null -ne $summaryTask -and $summaryTask.status -eq "blocked") {
        $summaryTask.status = "todo"
        $summaryTask.failure_reason = ""
        Set-TaskUpdatedAt -Task $summaryTask
    }
    Write-Workflow -Workflow $workflow
    Write-WorkflowLog -Message ("acceptance_decision accept task={0} request={1}" -f $TaskId, $requestId)
    Write-Output ("Accepted request {0}" -f $requestId)
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Reason)) {
    throw "Reason is required for retry or block."
}

$task.retries = [int]$task.retries + 1
$task.failure_reason = $Reason
Add-TaskEvidence -Task $task -Evidence $Evidence
Set-TaskUpdatedAt -Task $task

if ($Decision -eq "block") {
    $task.status = "blocked"
    Set-RequestStatus -Workflow $workflow -RequestId $requestId -Status "blocked"
    if ($null -ne $summaryTask) {
        $summaryTask.status = "blocked"
        $summaryTask.failure_reason = "Acceptance blocked for request " + $requestId
        Set-TaskUpdatedAt -Task $summaryTask
    }
    Write-Workflow -Workflow $workflow
    Write-WorkflowLog -Message ("acceptance_decision block task={0} request={1}" -f $TaskId, $requestId)
    Write-Output ("Blocked request {0}" -f $requestId)
    exit 0
}

$task.status = "todo"
Set-RequestStatus -Workflow $workflow -RequestId $requestId -Status "retrying"
Write-Workflow -Workflow $workflow
Write-WorkflowLog -Message ("acceptance_decision retry task={0} request={1}" -f $TaskId, $requestId)
Write-Output ("Request {0} returned for another optimization cycle." -f $requestId)
