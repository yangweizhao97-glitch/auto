param(
    [switch]$AsJson
)

. (Join-Path $PSScriptRoot "Shared.ps1")

$workflow = Read-Workflow
$ready = Get-ReadyTasks -Workflow $workflow
$inProgress = @($workflow.tasks | Where-Object { $_.status -eq "in_progress" })
$done = @($workflow.tasks | Where-Object { $_.status -eq "done" })
$blocked = @($workflow.tasks | Where-Object { $_.status -eq "blocked" })
$todo = @($workflow.tasks | Where-Object { $_.status -eq "todo" })

$requestStates = @()
if ($workflow.PSObject.Properties.Name -contains "requests") {
    foreach ($request in $workflow.requests) {
        $requestTasks = Get-TasksByRequest -Workflow $workflow -RequestId $request.id
        $requestReady = @($requestTasks | Where-Object { Test-TaskReady -Workflow $workflow -Task $_ })
        $requestStates += [pscustomobject]@{
            request_id = $request.id
            goal = $request.goal
            priority = $(if ($request.PSObject.Properties.Name -contains "priority") { $request.priority } else { "P2" })
            status = $request.status
            ready = @($requestReady | ForEach-Object { $_.id })
            counts = [pscustomobject]@{
                todo = @($requestTasks | Where-Object { $_.status -eq "todo" }).Count
                in_progress = @($requestTasks | Where-Object { $_.status -eq "in_progress" }).Count
                done = @($requestTasks | Where-Object { $_.status -eq "done" }).Count
                blocked = @($requestTasks | Where-Object { $_.status -eq "blocked" }).Count
            }
        }
    }
}

$state = [pscustomobject]@{
    project = $workflow.project.name
    updated_at = $workflow.project.updated_at
    ready = @($ready | ForEach-Object { $_.id })
    counts = [pscustomobject]@{
        todo = $todo.Count
        in_progress = $inProgress.Count
        done = $done.Count
        blocked = $blocked.Count
    }
    requests = $requestStates
}

if ($AsJson) {
    $state | ConvertTo-Json -Depth 10
    exit 0
}

Write-Output ("Project: {0}" -f $state.project)
Write-Output ("Updated: {0}" -f $state.updated_at)
$readyText = "<none>"
if ($state.ready.Count -gt 0) {
    $readyText = ($state.ready -join ", ")
}
Write-Output ("Ready Tasks: {0}" -f $readyText)
Write-Output ("Counts: todo={0}, in_progress={1}, done={2}, blocked={3}" -f $state.counts.todo, $state.counts.in_progress, $state.counts.done, $state.counts.blocked)

if ($state.requests.Count -gt 0) {
    Write-Output ""
    Write-Output "Requests:"
    foreach ($request in $state.requests) {
        $requestReadyText = "<none>"
        if ($request.ready.Count -gt 0) {
            $requestReadyText = ($request.ready -join ", ")
        }
        Write-Output ("- {0} | {1}" -f $request.request_id, $request.goal)
        Write-Output ("  priority={0} status={1} ready={2}" -f $request.priority, $request.status, $requestReadyText)
        Write-Output ("  counts: todo={0}, in_progress={1}, done={2}, blocked={3}" -f $request.counts.todo, $request.counts.in_progress, $request.counts.done, $request.counts.blocked)
    }
}
