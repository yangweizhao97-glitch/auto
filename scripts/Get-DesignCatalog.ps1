param(
    [switch]$AsJson
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

$readmeUrl = "https://raw.githubusercontent.com/VoltAgent/awesome-design-md/main/README.md"
$content = Get-UrlContent -Url $readmeUrl
$matches = [regex]::Matches($content, "https://getdesign\.md/([a-zA-Z0-9._-]+)/design-md")
$profiles = New-Object System.Collections.Generic.List[string]

foreach ($match in $matches) {
    $slug = $match.Groups[1].Value.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($slug)) {
        continue
    }
    if (-not $profiles.Contains($slug)) {
        $profiles.Add($slug)
    }
}

$sortedProfiles = @($profiles | Sort-Object)
$result = [pscustomobject]@{
    source = $readmeUrl
    count = $sortedProfiles.Count
    profiles = $sortedProfiles
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 20
    exit 0
}

Write-Output ("Source: {0}" -f $result.source)
Write-Output ("Count: {0}" -f $result.count)
Write-Output "Profiles:"
foreach ($profile in $sortedProfiles) {
    Write-Output ("- {0}" -f $profile)
}

