param(
    [Parameter(Mandatory = $true)][string]$TaskId
)

. (Join-Path $PSScriptRoot "Shared.ps1")

$workflow = Read-Workflow
$task = Get-Task -Workflow $workflow -TaskId $TaskId
$task.agent_profile = "optimization_child"
Set-TaskUpdatedAt -Task $task
Write-Workflow -Workflow $workflow

$promptPath = & (Join-Path $PSScriptRoot "New-HandoffPrompt.ps1") -TaskId $TaskId -Role "child_agent"
Write-WorkflowLog -Message ("optimization_prompt task={0} path={1}" -f $TaskId, $promptPath)
Write-Output $promptPath

