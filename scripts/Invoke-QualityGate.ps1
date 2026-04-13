param(
    [string]$OutputName = ""
)

. (Join-Path $PSScriptRoot "Shared.ps1")

function Get-PackageJsonScripts {
    param([string]$PackageJsonPath)

    $package = Get-Content -Raw -LiteralPath $PackageJsonPath | ConvertFrom-Json
    return $package.scripts
}

function Resolve-CommandSpec {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)]$Workflow,
        [Parameter(Mandatory = $true)]$Spec
    )

    if (-not [string]::IsNullOrWhiteSpace($Spec.command)) {
        return $Spec.command
    }

    $packageJson = Join-Path $Root "package.json"
    if (Test-Path -LiteralPath $packageJson) {
        $scripts = Get-PackageJsonScripts -PackageJsonPath $packageJson
        switch ($Spec.id) {
            "build" { if ($scripts.build) { return "npm run build" } }
            "typecheck" {
                if ($scripts.typecheck) { return "npm run typecheck" }
                if ($scripts.check) { return "npm run check" }
            }
            "lint" { if ($scripts.lint) { return "npm run lint" } }
            "test" {
                if ($scripts.test) { return "npm run test -- --runInBand" }
                if ($scripts.PSObject.Properties["test:ci"]) { return "npm run test:ci" }
            }
        }
    }

    $pyproject = Join-Path $Root "pyproject.toml"
    if (Test-Path -LiteralPath $pyproject) {
        switch ($Spec.id) {
            "test" { return "python -m pytest" }
            "lint" { return "python -m ruff check ." }
            "typecheck" { return "python -m mypy ." }
        }
    }

    if ($Spec.id -eq "security") {
        $gitDir = Join-Path $Root ".git"
        if (Test-Path -LiteralPath $gitDir) {
            return "git diff --stat"
        }
    }

    return $null
}

$workflow = Read-Workflow
$root = Get-RepoRoot
$reportDir = Join-Path $root "reports"
$logDir = Join-Path $root "logs"
Ensure-Directory -Path $reportDir
Ensure-Directory -Path $logDir

$stamp = if ([string]::IsNullOrWhiteSpace($OutputName)) { New-Stamp } else { $OutputName }
$reportPath = Join-Path $reportDir ("quality-gate-{0}.json" -f $stamp)
$results = @()
$overallPass = $true

foreach ($spec in $workflow.quality_gate.commands) {
    $command = Resolve-CommandSpec -Root $root -Workflow $workflow -Spec $spec
    $logPath = Join-Path $logDir ("quality-{0}-{1}.log" -f $spec.id, $stamp)

    if ([string]::IsNullOrWhiteSpace($command)) {
        $results += [pscustomobject]@{
            id = $spec.id
            status = "skipped"
            command = ""
            log = $logPath
            reason = "No configured or detected command."
        }
        continue
    }

    $output = & powershell -NoProfile -Command $command 2>&1
    $output | Set-Content -LiteralPath $logPath -Encoding UTF8
    $exitCode = $LASTEXITCODE

    $status = if ($exitCode -eq 0) { "pass" } else { "fail" }
    if ($status -eq "fail" -and -not $spec.optional) {
        $overallPass = $false
    }
    if ($status -eq "fail" -and $spec.id -ne "security") {
        $overallPass = $false
    }

    $results += [pscustomobject]@{
        id = $spec.id
        status = $status
        command = $command
        log = $logPath
        reason = ""
    }
}

$report = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    overall = if ($overallPass) { "pass" } else { "fail" }
    checks = $results
}

$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-WorkflowLog -Message ("quality_gate overall={0} report={1}" -f $report.overall, $reportPath)

Write-Output $reportPath
