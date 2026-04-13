Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-WorkflowFile {
    param(
        [string]$Path = "tasks.json"
    )

    $root = Get-RepoRoot
    return Join-Path $root $Path
}

function Read-Workflow {
    param(
        [string]$Path = "tasks.json"
    )

    $workflowPath = Get-WorkflowFile -Path $Path
    if (-not (Test-Path -LiteralPath $workflowPath)) {
        throw "Workflow file not found: $workflowPath"
    }

    return (Get-Content -Raw -LiteralPath $workflowPath | ConvertFrom-Json)
}

function Write-Workflow {
    param(
        [Parameter(Mandatory = $true)]$Workflow,
        [string]$Path = "tasks.json"
    )

    $workflowPath = Get-WorkflowFile -Path $Path
    $Workflow.project.updated_at = (Get-Date).ToString("o")
    $json = $Workflow | ConvertTo-Json -Depth 100
    $tempPath = $workflowPath + ".tmp"
    Set-Content -LiteralPath $tempPath -Value $json -Encoding UTF8
    Move-Item -LiteralPath $tempPath -Destination $workflowPath -Force
}

function Get-Task {
    param(
        [Parameter(Mandatory = $true)]$Workflow,
        [Parameter(Mandatory = $true)][string]$TaskId
    )

    $task = $Workflow.tasks | Where-Object { $_.id -eq $TaskId } | Select-Object -First 1
    if ($null -eq $task) {
        throw "Task not found: $TaskId"
    }

    return $task
}

function Get-TaskMap {
    param(
        [Parameter(Mandatory = $true)]$Workflow
    )

    $map = @{}
    foreach ($task in $Workflow.tasks) {
        $map[$task.id] = $task
    }
    return $map
}

function Get-RequestRecord {
    param(
        [Parameter(Mandatory = $true)]$Workflow,
        [Parameter(Mandatory = $true)][string]$RequestId
    )

    if ($null -eq $Workflow.requests) {
        return $null
    }

    return ($Workflow.requests | Where-Object { $_.id -eq $RequestId } | Select-Object -First 1)
}

function Get-TasksByRequest {
    param(
        [Parameter(Mandatory = $true)]$Workflow,
        [Parameter(Mandatory = $true)][string]$RequestId
    )

    return @($Workflow.tasks | Where-Object { $_.request_id -eq $RequestId })
}

function Get-ImplementationTasksByRequest {
    param(
        [Parameter(Mandatory = $true)]$Workflow,
        [Parameter(Mandatory = $true)][string]$RequestId
    )

    return @($Workflow.tasks | Where-Object {
        $_.request_id -eq $RequestId -and $_.phase -eq "implementation"
    })
}

function Set-RequestStatus {
    param(
        [Parameter(Mandatory = $true)]$Workflow,
        [Parameter(Mandatory = $true)][string]$RequestId,
        [Parameter(Mandatory = $true)][string]$Status
    )

    $request = Get-RequestRecord -Workflow $Workflow -RequestId $RequestId
    if ($null -ne $request) {
        $request.status = $Status
    }
}

function Test-TaskReady {
    param(
        [Parameter(Mandatory = $true)]$Workflow,
        [Parameter(Mandatory = $true)]$Task
    )

    if ($Task.status -ne "todo") {
        return $false
    }

    $taskMap = Get-TaskMap -Workflow $Workflow
    foreach ($dependency in $Task.dependencies) {
        if (-not $taskMap.ContainsKey($dependency)) {
            throw "Task $($Task.id) has unknown dependency: $dependency"
        }

        if ($taskMap[$dependency].status -ne "done") {
            return $false
        }
    }

    return $true
}

function Get-ReadyTasks {
    param(
        [Parameter(Mandatory = $true)]$Workflow
    )

    return @($Workflow.tasks | Where-Object { Test-TaskReady -Workflow $Workflow -Task $_ })
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function New-Stamp {
    return (Get-Date).ToString("yyyyMMdd-HHmmss")
}

function Add-TaskEvidence {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [string[]]$Evidence
    )

    if ($null -eq $Task.evidence) {
        $Task | Add-Member -NotePropertyName evidence -NotePropertyValue @()
    }

    foreach ($item in $Evidence) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $Task.evidence += $item
        }
    }
}

function Set-TaskUpdatedAt {
    param(
        [Parameter(Mandatory = $true)]$Task
    )

    $Task.updated_at = (Get-Date).ToString("o")
}

function Write-WorkflowLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message
    )

    $root = Get-RepoRoot
    $logDir = Join-Path $root "logs"
    Ensure-Directory -Path $logDir
    $logFile = Join-Path $logDir ("workflow-" + (Get-Date).ToString("yyyyMMdd") + ".log")
    $line = "[{0}] {1}" -f (Get-Date).ToString("o"), $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}
