<#
.SYNOPSIS
Imports Pi-hole blocklists from a remote or local text file into the Pi-hole gravity database.

.DESCRIPTION
This script:
- Downloads blocklists.txt from the GitHub repo (or reads a local copy)
- Parses each URL, skipping blank lines and comments
- Inserts each URL into Pi-hole's gravity.db adlist table
- Skips duplicates automatically via INSERT OR IGNORE
- Runs pihole -g to update gravity after all inserts

.PARAMETER BlocklistUrl
URL to the raw blocklists.txt file. Defaults to the GitHub raw URL.

.PARAMETER LocalFile
Path to a local blocklists.txt file. If supplied, skips the download.

.PARAMETER GravityDb
Path to the Pi-hole gravity database. Defaults to /etc/pihole/gravity.db.

.PARAMETER SkipGravityUpdate
If supplied, skips running pihole -g after inserting. Useful for testing.

.EXAMPLE
sudo pwsh ./Import-PiHoleBlocklists.ps1

.EXAMPLE
sudo pwsh ./Import-PiHoleBlocklists.ps1 -LocalFile ./blocklists.txt

.EXAMPLE
sudo pwsh ./Import-PiHoleBlocklists.ps1 -SkipGravityUpdate

.NOTES
Must be run as root or with sudo on the Pi-hole host.
Requires PowerShell 7+ and sqlite3 CLI installed.
#>

[CmdletBinding()]
param(
    [string]$BlocklistUrl = "https://raw.githubusercontent.com/mickpletcher/PiHole/main/blocklists.txt",
    [string]$LocalFile = "",
    [string]$GravityDb = "/etc/pihole/gravity.db",
    [switch]$SkipGravityUpdate
)

# ==========================================================================================
# VALIDATION
# ==========================================================================================

function Test-Prerequisites {
    if ($IsWindows) {
        throw "This script must be run on the Pi-hole host (Linux). It cannot be run on Windows."
    }

    if ((id -u) -ne 0) {
        throw "This script must be run as root. Try: sudo pwsh ./Import-PiHoleBlocklists.ps1"
    }

    if (-not (Test-Path $GravityDb)) {
        throw "Pi-hole gravity database not found at: $GravityDb"
    }

    $sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if (-not $sqlite) {
        throw "sqlite3 CLI not found in PATH. Install with: apt install sqlite3"
    }
}

# ==========================================================================================
# LOAD BLOCKLIST FILE
# ==========================================================================================

function Get-BlocklistUrls {
    $lines = @()

    if (-not [string]::IsNullOrWhiteSpace($LocalFile)) {
        if (-not (Test-Path $LocalFile)) {
            throw "Local file not found: $LocalFile"
        }
        Write-Host "Reading blocklists from local file: $LocalFile"
        $lines = Get-Content -Path $LocalFile -Encoding UTF8
    }
    else {
        Write-Host "Downloading blocklists from: $BlocklistUrl"
        try {
            $response = Invoke-RestMethod -Uri $BlocklistUrl -Method Get
            $lines = $response -split "`n"
        }
        catch {
            throw "Failed to download blocklists.txt: $_"
        }
    }

    $urls = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith('#')) { continue }
        $urls += $trimmed
    }

    return $urls
}

# ==========================================================================================
# DATABASE HELPERS
# ==========================================================================================

function Invoke-SqliteNonQuery {
    param(
        [Parameter(Mandatory)]
        [string]$Sql
    )

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -Path $tmp -Value $Sql -Encoding UTF8
        & sqlite3 $GravityDb ".read $tmp" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "sqlite3 returned a non-zero exit code."
        }
    }
    finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

function Get-ExistingAdlistUrls {
    $result = & sqlite3 $GravityDb "SELECT address FROM adlist;"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to query existing adlists from gravity.db."
    }
    if (-not $result) { return @() }
    return $result
}

function Add-AdlistUrl {
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    $escaped = $Url -replace "'", "''"
    $sql = "INSERT OR IGNORE INTO adlist (address, enabled, date_added, comment) VALUES ('$escaped', 1, strftime('%s','now'), 'Imported by Import-PiHoleBlocklists.ps1');"
    Invoke-SqliteNonQuery -Sql $sql
}

# ==========================================================================================
# MAIN
# ==========================================================================================

try {
    Test-Prerequisites

    $urls = Get-BlocklistUrls
    Write-Host "Found $($urls.Count) URLs to process."

    $existing = Get-ExistingAdlistUrls
    $existingSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($e in $existing) { [void]$existingSet.Add($e.Trim()) }

    $added   = 0
    $skipped = 0

    foreach ($url in $urls) {
        if ($existingSet.Contains($url)) {
            Write-Host "  [skip]  $url"
            $skipped++
        }
        else {
            Write-Host "  [add]   $url"
            Add-AdlistUrl -Url $url
            $added++
        }
    }

    Write-Host ""
    Write-Host "Import complete."
    Write-Host "  Added   : $added"
    Write-Host "  Skipped : $skipped (already existed)"
    Write-Host ""

    if ($SkipGravityUpdate) {
        Write-Host "Skipping gravity update (SkipGravityUpdate flag set)."
        Write-Host "Run 'pihole -g' manually to apply the new lists."
    }
    else {
        Write-Host "Updating Pi-hole gravity. This may take a few minutes..."
        & pihole -g
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "pihole -g exited with code $LASTEXITCODE. Check Pi-hole logs for details."
        }
        else {
            Write-Host "Gravity update complete."
        }
    }
}
catch {
    Write-Error $_
    throw
}
