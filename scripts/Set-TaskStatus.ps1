param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)][ValidateSet("todo", "in_progress", "done", "blocked")][string]$Status,
    [string]$FailureReason = "",
    [string[]]$Evidence = @(),
    [switch]$IncrementRetry,
    [switch]$AllowScopeOverlap
)

. (Join-Path $PSScriptRoot "Shared.ps1")

function Test-ScopeOverlap {
    param(
        [string[]]$LeftScope,
        [string[]]$RightScope
    )

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

    # Backward compatibility: allow plain file paths while encouraging structured format.
    if ($Line -notmatch "\|") {
        return $true
    }

    return ($Line -match "^cmd=.+\|result=(pass|fail|skipped)\|log=.+(\|artifact=.+)?$")
}

function Get-ArtifactPathFromEvidence {
    param(
        [string]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return ""
    }

    if ($Line -match "\|artifact=([^|]+)$") {
        return $Matches[1].Trim()
    }

    if ($Line -notmatch "\|") {
        return $Line.Trim()
    }

    return ""
}

function Resolve-ArtifactPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$PathValue
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return (Join-Path $RepoRoot $PathValue)
}

function Test-IsReportsResultMarkdown {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$ArtifactPath
    )

    if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
        return $false
    }

    $resolved = Resolve-ArtifactPath -RepoRoot $RepoRoot -PathValue $ArtifactPath
    $resolvedFull = [System.IO.Path]::GetFullPath($resolved)
    $resultsRoot = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot "reports/results"))

    $resolvedNorm = $resolvedFull.ToLowerInvariant().Replace("/", "\")
    $resultsNorm = $resultsRoot.ToLowerInvariant().Replace("/", "\")

    if (-not $resolvedNorm.EndsWith(".md")) {
        return $false
    }

    return ($resolvedNorm.StartsWith($resultsNorm + "\"))
}

function Test-HasMarkdownArtifactEvidence {
    param(
        [string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    foreach ($line in $Lines) {
        $artifact = Get-ArtifactPathFromEvidence -Line $line
        if ([string]::IsNullOrWhiteSpace($artifact)) {
            continue
        }

        if (-not (Test-IsReportsResultMarkdown -RepoRoot $RepoRoot -ArtifactPath $artifact)) {
            continue
        }

        $resolved = Resolve-ArtifactPath -RepoRoot $RepoRoot -PathValue $artifact
        if (Test-Path -LiteralPath $resolved) {
            return $true
        }
    }

    return $false
}

$workflow = Read-Workflow
$task = Get-Task -Workflow $workflow -TaskId $TaskId

if ($IncrementRetry) {
    $task.retries = [int]$task.retries + 1
}

if ($Status -eq "in_progress") {
    foreach ($dependencyId in $task.dependencies) {
        $dependencyTask = Get-Task -Workflow $workflow -TaskId $dependencyId
        if ($dependencyTask.status -ne "done") {
            throw ("Cannot start {0}; dependency {1} is {2}, expected done." -f $task.id, $dependencyId, $dependencyTask.status)
        }
    }

    if (-not $AllowScopeOverlap) {
        $activeTasks = @($workflow.tasks | Where-Object { $_.status -eq "in_progress" -and $_.id -ne $task.id })
        foreach ($active in $activeTasks) {
            $taskAllow = $false
            if ($task.PSObject.Properties.Name -contains "allow_scope_overlap") {
                $taskAllow = [bool]$task.allow_scope_overlap
            }
            $activeAllow = $false
            if ($active.PSObject.Properties.Name -contains "allow_scope_overlap") {
                $activeAllow = [bool]$active.allow_scope_overlap
            }
            if ($taskAllow -or $activeAllow) {
                continue
            }
            if (Test-ScopeOverlap -LeftScope @($task.scope) -RightScope @($active.scope)) {
                throw ("Scope conflict: {0} overlaps with in-progress task {1}. Use -AllowScopeOverlap only when intentional." -f $task.id, $active.id)
            }
        }
    }
}

if ($Status -eq "blocked" -and [string]::IsNullOrWhiteSpace($FailureReason)) {
    throw "Blocked tasks require FailureReason."
}

foreach ($entry in $Evidence) {
    if (-not (Test-EvidenceFormat -Line $entry)) {
        throw ("Invalid evidence format: {0}" -f $entry)
    }
}

if ($Status -eq "done") {
    $repoRoot = Get-RepoRoot
    $requiresMarkdownEvidence = $false
    if ($task.owner_role -eq "child_agent" -or $task.owner_role -eq "tester_agent") {
        $requiresMarkdownEvidence = $true
    } elseif ($task.phase -eq "implementation" -or $task.phase -eq "testing") {
        $requiresMarkdownEvidence = $true
    }

    if ($requiresMarkdownEvidence) {
        $combinedEvidence = @($task.evidence) + @($Evidence)
        if (-not (Test-HasMarkdownArtifactEvidence -Lines $combinedEvidence -RepoRoot $repoRoot)) {
            throw ("Completing {0} requires an existing markdown artifact under reports/results/*.md via evidence artifact." -f $task.id)
        }
    }
}

$maxRetries = 1
if ($task.PSObject.Properties.Name -contains "max_retries" -and [int]$task.max_retries -gt 0) {
    $maxRetries = [int]$task.max_retries
}
if ([int]$task.retries -ge $maxRetries -and $Status -ne "done") {
    $Status = "blocked"
    if ([string]::IsNullOrWhiteSpace($FailureReason)) {
        $FailureReason = ("Retry budget exhausted (retries={0}, max_retries={1})" -f $task.retries, $maxRetries)
    }
}

$task.status = $Status
$task.failure_reason = $FailureReason
Add-TaskEvidence -Task $task -Evidence $Evidence
Set-TaskUpdatedAt -Task $task

Write-Workflow -Workflow $workflow
Write-WorkflowLog -Message ("task={0} status={1} retries={2}" -f $task.id, $task.status, $task.retries)

Write-Output ("Updated {0} -> {1}" -f $TaskId, $Status)
