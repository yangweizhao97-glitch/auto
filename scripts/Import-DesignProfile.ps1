param(
    [Parameter(Mandatory = $true)][string]$Profile,
    [string]$OutputRoot = "design/awesome-design-md",
    [switch]$SetProjectDesign,
    [switch]$Force
)

. (Join-Path $PSScriptRoot "Shared.ps1")

function Get-UrlContent {
    param(
        [Parameter(Mandatory = $true)][string]$Url
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 5 -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
            return [string]$response.Content
        }
    } catch {
        # Fallback to curl when PowerShell web cmdlet fails in constrained environments.
    }

    $content = & curl.exe -L -s $Url
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($content)) {
        throw ("Unable to download URL: {0}" -f $Url)
    }

    return [string]$content
}

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content,
        [switch]$Overwrite
    )

    if ((Test-Path -LiteralPath $Path) -and -not $Overwrite) {
        throw ("File already exists (use -Force to overwrite): {0}" -f $Path)
    }

    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        Ensure-Directory -Path $dir
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

$repoRoot = Get-RepoRoot
$normalizedProfile = $Profile.Trim().ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($normalizedProfile)) {
    throw "Profile cannot be empty."
}

$targetDir = Join-Path (Join-Path $repoRoot $OutputRoot) $normalizedProfile
Ensure-Directory -Path $targetDir

$baseDesignUrl = "https://getdesign.md/design-md/{0}" -f $normalizedProfile
$files = @(
    @{ Name = "DESIGN.md"; Url = "{0}/DESIGN.md" -f $baseDesignUrl; Required = $true },
    @{ Name = "preview.html"; Url = "{0}/preview.html" -f $baseDesignUrl; Required = $false },
    @{ Name = "preview-dark.html"; Url = "{0}/preview-dark.html" -f $baseDesignUrl; Required = $false },
    @{ Name = "README.md"; Url = ("https://raw.githubusercontent.com/VoltAgent/awesome-design-md/main/design-md/{0}/README.md" -f $normalizedProfile); Required = $false }
)

$downloaded = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]

foreach ($file in $files) {
    $destination = Join-Path $targetDir $file.Name
    try {
        $content = Get-UrlContent -Url $file.Url
        Write-TextFile -Path $destination -Content $content -Overwrite:$Force
        $downloaded.Add($destination) | Out-Null
    } catch {
        if ($file.Required) {
            throw ("Failed to download required file {0}: {1}" -f $file.Name, $_.Exception.Message)
        }
        $skipped.Add(("{0} ({1})" -f $file.Name, $file.Url)) | Out-Null
    }
}

$projectDesignPath = Join-Path $repoRoot "DESIGN.md"
if ($SetProjectDesign) {
    $sourceDesignPath = Join-Path $targetDir "DESIGN.md"
    if (-not (Test-Path -LiteralPath $sourceDesignPath)) {
        throw ("Downloaded DESIGN.md missing at {0}" -f $sourceDesignPath)
    }
    if ((Test-Path -LiteralPath $projectDesignPath) -and -not $Force) {
        throw ("Project DESIGN.md already exists (use -Force to overwrite): {0}" -f $projectDesignPath)
    }
    Copy-Item -LiteralPath $sourceDesignPath -Destination $projectDesignPath -Force
}

$workflowLogMsg = "design_profile_imported profile={0} output={1} set_project_design={2}" -f $normalizedProfile, $targetDir, [bool]$SetProjectDesign
Write-WorkflowLog -Message $workflowLogMsg

Write-Output ("Profile: {0}" -f $normalizedProfile)
Write-Output ("Output: {0}" -f $targetDir)
Write-Output ("Downloaded: {0}" -f $downloaded.Count)
foreach ($path in $downloaded) {
    Write-Output ("- {0}" -f $path)
}
if ($skipped.Count -gt 0) {
    Write-Output ("Skipped optional files: {0}" -f $skipped.Count)
    foreach ($item in $skipped) {
        Write-Output ("- {0}" -f $item)
    }
}
if ($SetProjectDesign) {
    Write-Output ("Project DESIGN.md: {0}" -f $projectDesignPath)
}

