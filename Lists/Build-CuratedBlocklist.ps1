<#
.SYNOPSIS
Builds a curated Pi hole domain blocklist from source list URLs.

.DESCRIPTION
Reads source list URLs from a local file path or URL, downloads each source,
extracts domains from common list formats, sorts and de duplicates the final
domain set, then writes the result to CuratedBlackList.txt.

Whitelist source URLs are processed into a separate CuratedWhitelist.txt file.

By default the script generates output files locally and does NOT push to GitHub.
Pass -EnableGitPush to stage, commit, and push the generated output files.

.PARAMETER SourcesFile
Local path or URL containing source list URLs, one URL per line.
Default is the local PiHoleListSources.txt file in the same folder as this script.

.PARAMETER OutputFile
Destination path for the curated output file.
Default is CuratedBlackList.txt in the same folder as this script.

.PARAMETER WhitelistOutputFile
Destination path for the curated whitelist output file.
Default is CuratedWhitelist.txt in the same folder as this script.

.PARAMETER TimeoutSec
HTTP timeout in seconds for source URL and list downloads.

.PARAMETER RetryCount
Number of download attempts per URL before marking that source as failed.

.PARAMETER RetryDelaySec
Delay in seconds between retry attempts.

.PARAMETER FailOnSourceError
When set, stop the script immediately if any source URL fails.

.PARAMETER FailedSourcesLogFile
Path to a text file used to log source URLs that failed to download or parse.
This file is always generated each run and can be empty.

.PARAMETER EnableGitPush
When set, stage, commit, and push the generated output files to GitHub.
By default, no push is performed.

.PARAMETER DisableGitPush
Deprecated. No-push is the default behavior now. This switch is kept for
backwards compatibility and has no effect unless -EnableGitPush is also set.

.PARAMETER GitRemote
Git remote name used when EnableGitPush is set. Default is origin.

.PARAMETER GitBranch
Git branch name used when EnableGitPush is set. Default is main.

.PARAMETER CommitMessage
Commit message used when EnableGitPush is set and changes are detected.

.EXAMPLE
.\Build-CuratedBlocklist.ps1

Builds the curated blocklist and whitelist locally. No files are pushed to GitHub.

.EXAMPLE
.\Build-CuratedBlocklist.ps1 -SourcesFile .\PiHoleListSources.txt -OutputFile .\CuratedBlackList.txt

.EXAMPLE
.\Build-CuratedBlocklist.ps1 -OutputFile .\CuratedBlackList.txt -WhitelistOutputFile .\CuratedWhitelist.txt

.EXAMPLE
.\Build-CuratedBlocklist.ps1 -EnableGitPush

Builds the curated blocklist and pushes the output files to GitHub.

.EXAMPLE
.\Build-CuratedBlocklist.ps1 -EnableGitPush -GitRemote origin -GitBranch main -CommitMessage "Refresh curated blocklist"

.NOTES
Requires internet access for URL based sources.
Git push flow requires git to be installed and the script to run inside a git repository.
Use -WhatIf to preview write and push actions without making changes.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourcesFile = (Join-Path $PSScriptRoot 'PiHoleListSources.txt'),
    [string]$OutputFile = (Join-Path $PSScriptRoot 'CuratedBlackList.txt'),
    [string]$WhitelistOutputFile = (Join-Path $PSScriptRoot 'CuratedWhitelist.txt'),
    [int]$TimeoutSec = 60,
    [int]$RetryCount = 3,
    [int]$RetryDelaySec = 2,
    [bool]$FailOnSourceError = $false,
    [string]$FailedSourcesLogFile = (Join-Path $PSScriptRoot 'FailedSources.txt'),
    [switch]$EnableGitPush,
    [switch]$DisableGitPush,
    [string]$GitRemote = 'origin',
    [string]$GitBranch = 'main',
    [string]$CommitMessage = ("Update CuratedBlackList.txt " + (Get-Date -Format 'yyyy-MM-dd'))
)

$ErrorActionPreference = 'Stop'

if ($DisableGitPush) {
    Write-Warning "-DisableGitPush is deprecated. No-push is the default behavior. The switch has no effect and can be removed."
}

# Resolve effective push flag: push only when -EnableGitPush is explicitly provided.
$gitPushEnabled = $EnableGitPush.IsPresent

function Get-DomainFromLine {
    param(
        [AllowEmptyString()]
        [string]$Line
    )

    $working = $Line.Trim()
    if ([string]::IsNullOrWhiteSpace($working)) { return $null }

    if ($working.Contains('#')) {
        $working = ($working -split '#', 2)[0].Trim()
    }

    if ([string]::IsNullOrWhiteSpace($working)) { return $null }

    if ($working -match '^\|\|([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\^?') {
        return $Matches[1].ToLowerInvariant()
    }

    $tokens = $working -split '\s+'

    if ($tokens.Count -ge 2 -and $tokens[0] -match '^(?:0\.0\.0\.0|127\.0\.0\.1|::1|::)$') {
        $candidate = $tokens[1].Trim().ToLowerInvariant().Trim('.')
        if ($candidate -match '^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$') {
            return $candidate
        }
    }

    $single = $tokens[0].Trim().ToLowerInvariant()

    if ($single -match '^[a-z][a-z0-9+.-]*://') {
        try {
            $uri = [uri]$single
            if ($uri.Host -and $uri.Host -match '^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$') {
                return $uri.Host.ToLowerInvariant().Trim('.')
            }
        }
        catch {
        }
    }

    $single = $single.Trim('.')
    if ($single -match '^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$') {
        return $single
    }

    return $null
}

function Resolve-GitHubRawUrl {
    param(
        [Parameter(Mandatory)]
        [string]$Location
    )

    if ($Location -match '^https?://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.*)$') {
        return "https://raw.githubusercontent.com/$($Matches[1])/$($Matches[2])/$($Matches[3])/$($Matches[4])"
    }

    return $Location
}

function Get-SourceUrlList {
    param(
        [Parameter(Mandatory)]
        [string]$SourceLocation,
        [Parameter(Mandatory)]
        [int]$RequestTimeoutSec
    )

    if ($SourceLocation -match '^https?://') {
        $resolvedLocation = Resolve-GitHubRawUrl -Location $SourceLocation
        Write-Host "Downloading source URL list from: $resolvedLocation"
        $content = (Invoke-WebRequestWithRetry -Uri $resolvedLocation -RequestTimeoutSec $RequestTimeoutSec -Attempts $RetryCount -DelaySec $RetryDelaySec).Content
        return $content -split "`n"
    }

    if (-not (Test-Path -Path $SourceLocation -PathType Leaf)) {
        throw "Sources file not found: $SourceLocation"
    }

    Write-Host "Reading source URL list from local file: $SourceLocation"
    return Get-Content -Path $SourceLocation -Encoding UTF8
}

function Invoke-WebRequestWithRetry {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [int]$RequestTimeoutSec,
        [Parameter(Mandatory)]
        [int]$Attempts,
        [Parameter(Mandatory)]
        [int]$DelaySec
    )

    $attempt = 0
    while ($attempt -lt $Attempts) {
        $attempt++
        try {
            return Invoke-WebRequest -Uri $Uri -Method Get -TimeoutSec $RequestTimeoutSec
        }
        catch {
            if ($attempt -ge $Attempts) {
                throw
            }

            Write-Warning "Attempt $attempt failed for $Uri. Retrying in $DelaySec seconds."
            Start-Sleep -Seconds $DelaySec
        }
    }
}

function Push-FilesToGitHub {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string[]]$FilePaths,
        [Parameter(Mandatory)]
        [string]$Remote,
        [Parameter(Mandatory)]
        [string]$Branch,
        [Parameter(Mandatory)]
        [string]$Message
    )

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
        throw 'Git is not installed or not available in PATH.'
    }

    $repoRoot = (& git -C $PSScriptRoot rev-parse --show-toplevel 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
        throw 'Unable to locate a Git repository from the script path.'
    }

    $repoRoot = (Resolve-Path -Path $repoRoot).Path

    $relativePaths = [System.Collections.Generic.List[string]]::new()

    foreach ($filePath in $FilePaths) {
        if (-not (Test-Path -Path $filePath -PathType Leaf)) {
            continue
        }

        $resolvedFilePath = (Resolve-Path -Path $filePath).Path

        if (-not $resolvedFilePath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Output file is not inside the repository: $resolvedFilePath"
        }

        $relativePath = $resolvedFilePath.Substring($repoRoot.Length).TrimStart([char[]]@('\', '/'))
        [void]$relativePaths.Add($relativePath)
    }

    if ($relativePaths.Count -eq 0) {
        Write-Host 'No files available to push.'
        return
    }

    $targetFiles = ($relativePaths -join ', ')

    if (-not $PSCmdlet.ShouldProcess($targetFiles, "Stage, commit, and push to $Remote/$Branch")) {
        return
    }

    & git -C $repoRoot add -- @($relativePaths)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to stage files: $targetFiles"
    }

    & git -C $repoRoot diff --cached --quiet -- @($relativePaths)
    if ($LASTEXITCODE -eq 0) {
        Write-Host "No Git changes detected for $targetFiles"
        return
    }

    & git -C $repoRoot commit -m $Message -- @($relativePaths)
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to create commit.'
    }

    & git -C $repoRoot push $Remote $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push to $Remote/$Branch"
    }

    Write-Host "Pushed $targetFiles to $Remote/$Branch"
}

if (Test-Path -Path $OutputFile -PathType Leaf) {
    Write-Host "Existing output file found, will be overwritten: $OutputFile"
}
else {
    Write-Host "No existing output file found: $OutputFile"
}

if ($WhitelistOutputFile) {
    if (Test-Path -Path $WhitelistOutputFile -PathType Leaf) {
        Write-Host "Existing whitelist output file found, will be overwritten: $WhitelistOutputFile"
    }
    else {
        Write-Host "No existing whitelist output file found: $WhitelistOutputFile"
    }
}

if ($FailedSourcesLogFile) {
    if (Test-Path -Path $FailedSourcesLogFile -PathType Leaf) {
        Write-Host "Existing failed source log found, will be overwritten: $FailedSourcesLogFile"
    }
    else {
        Write-Host "No existing failed source log found: $FailedSourcesLogFile"
    }
}

$sourceUrls = Get-SourceUrlList -SourceLocation $SourcesFile -RequestTimeoutSec $TimeoutSec |
    ForEach-Object { $_.Trim() } |
    Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and
        -not $_.StartsWith('#')
    }

$whitelistSourceUrls = $sourceUrls | Where-Object { $_ -match '(?i)whitelist' }
$sourceUrls = $sourceUrls | Where-Object { $_ -notmatch '(?i)whitelist' }

if (-not $sourceUrls -or $sourceUrls.Count -eq 0) {
    throw "No source URLs found in $SourcesFile"
}

$totalSources = $sourceUrls.Count
$domains = [System.Collections.Generic.List[string]]::new()
$whitelistDomains = [System.Collections.Generic.List[string]]::new()
$failedSources = [System.Collections.Generic.List[string]]::new()
$processedSourceCount = 0
$processedWhitelistSourceCount = 0

foreach ($url in $sourceUrls) {
    $processedSourceCount++
    Write-Host "Downloading [$processedSourceCount of $totalSources]: $url"

    try {
        $response = Invoke-WebRequestWithRetry -Uri $url -RequestTimeoutSec $TimeoutSec -Attempts $RetryCount -DelaySec $RetryDelaySec
        $lines = $response.Content -split "`n"

        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            $domain = Get-DomainFromLine -Line $line
            if ($domain) {
                $domains.Add($domain)
            }
        }
    }
    catch {
        Write-Warning "Failed to process source: $url"
        Write-Warning $_
        $failedSources.Add($url)

        if ($FailOnSourceError) {
            throw "Stopping because FailOnSourceError is set. Source failed: $url"
        }
    }
}

$totalWhitelistSources = $whitelistSourceUrls.Count

foreach ($url in $whitelistSourceUrls) {
    $processedWhitelistSourceCount++
    Write-Host "Downloading whitelist [$processedWhitelistSourceCount of $totalWhitelistSources]: $url"

    try {
        $response = Invoke-WebRequestWithRetry -Uri $url -RequestTimeoutSec $TimeoutSec -Attempts $RetryCount -DelaySec $RetryDelaySec
        $lines = $response.Content -split "`n"

        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            $domain = Get-DomainFromLine -Line $line
            if ($domain) {
                $whitelistDomains.Add($domain)
            }
        }
    }
    catch {
        Write-Warning "Failed to process whitelist source: $url"
        Write-Warning $_
        $failedSources.Add($url)

        if ($FailOnSourceError) {
            throw "Stopping because FailOnSourceError is set. Whitelist source failed: $url"
        }
    }
}

$curated = $domains |
    Sort-Object -Unique

$curatedWhitelist = $whitelistDomains |
    Sort-Object -Unique

$destinationFolder = Split-Path -Path $OutputFile -Parent
if ([string]::IsNullOrWhiteSpace($destinationFolder)) {
    $destinationFolder = (Get-Location).Path
}
if ($destinationFolder -and -not (Test-Path -Path $destinationFolder -PathType Container)) {
    New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
}

$tempFile = Join-Path -Path $destinationFolder -ChildPath ("curated-temp-" + [guid]::NewGuid().ToString() + ".txt")
try {
    if ($PSCmdlet.ShouldProcess($OutputFile, 'Write curated blocklist output')) {
        $curated | Set-Content -Path $tempFile -Encoding UTF8
        Move-Item -Path $tempFile -Destination $OutputFile -Force
    }
}
finally {
    if (Test-Path -Path $tempFile -PathType Leaf) {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
}

$whitelistDestinationFolder = Split-Path -Path $WhitelistOutputFile -Parent
if ([string]::IsNullOrWhiteSpace($whitelistDestinationFolder)) {
    $whitelistDestinationFolder = (Get-Location).Path
}
if ($whitelistDestinationFolder -and -not (Test-Path -Path $whitelistDestinationFolder -PathType Container)) {
    New-Item -Path $whitelistDestinationFolder -ItemType Directory -Force | Out-Null
}

$tempWhitelistFile = Join-Path -Path $whitelistDestinationFolder -ChildPath ("curated-whitelist-temp-" + [guid]::NewGuid().ToString() + ".txt")
try {
    if ($PSCmdlet.ShouldProcess($WhitelistOutputFile, 'Write curated whitelist output')) {
        $curatedWhitelist | Set-Content -Path $tempWhitelistFile -Encoding UTF8
        Move-Item -Path $tempWhitelistFile -Destination $WhitelistOutputFile -Force
    }
}
finally {
    if (Test-Path -Path $tempWhitelistFile -PathType Leaf) {
        Remove-Item -Path $tempWhitelistFile -Force -ErrorAction SilentlyContinue
    }
}

if ($FailedSourcesLogFile) {
    $failedLogFolder = Split-Path -Path $FailedSourcesLogFile -Parent
    if ($failedLogFolder -and -not (Test-Path -Path $failedLogFolder -PathType Container)) {
        New-Item -Path $failedLogFolder -ItemType Directory -Force | Out-Null
    }

    if ($PSCmdlet.ShouldProcess($FailedSourcesLogFile, 'Write failed sources log')) {
        $failedSources | Set-Content -Path $FailedSourcesLogFile -Encoding UTF8
    }
}

if ($gitPushEnabled) {
    $filesToPush = [System.Collections.Generic.List[string]]::new()
    [void]$filesToPush.Add($OutputFile)
    [void]$filesToPush.Add($WhitelistOutputFile)

    if ($FailedSourcesLogFile) {
        [void]$filesToPush.Add($FailedSourcesLogFile)
    }

    Push-FilesToGitHub -FilePaths $filesToPush.ToArray() -Remote $GitRemote -Branch $GitBranch -Message $CommitMessage
}

Write-Host ""
Write-Host "Complete"
Write-Host "  Sources read : $($sourceUrls.Count)"
Write-Host "  Whitelist skipped: $($whitelistSourceUrls.Count)"
Write-Host "  Sources failed: $($failedSources.Count)"
Write-Host "  Domains output: $($curated.Count)"
Write-Host "  Whitelist domains: $($curatedWhitelist.Count)"
Write-Host "  Output file   : $OutputFile"
Write-Host "  Whitelist file: $WhitelistOutputFile"
if ($FailedSourcesLogFile) {
    Write-Host "  Failed log    : $FailedSourcesLogFile"
}

if ($failedSources.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed sources:"
    $failedSources | ForEach-Object { Write-Host "  $_" }
}
