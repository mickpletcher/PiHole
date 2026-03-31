<#
.SYNOPSIS
Pulls Pi-hole v6 configuration and summary data to a local JSON file.

.DESCRIPTION
Authenticates to the Pi-hole API, collects a defined set of endpoints, and writes
the results to a JSON file on the current user's desktop.

Before the file is written, the script redacts sensitive values that should not be
shared for external review. This includes common secret fields and common host
identifiers such as IP addresses, MAC addresses, URLs, and domain names.

.PARAMETER PiHoleIP
The IP address of the Pi-hole instance to query.

.PARAMETER ApiPassword
The Pi-hole API password used to create the API session.

.PARAMETER OutputPath
The full path for the exported JSON file. If not specified, the script uses the
current user's desktop when available and falls back to the current directory.

.OUTPUTS
Creates a sanitized JSON export at the path specified by OutputPath.

.EXAMPLE
.\Get-PiHoleConfig.ps1 -PiHoleIP 192.168.0.101 -ApiPassword 'your_api_password'

.EXAMPLE
.\Get-PiHoleConfig.ps1 -PiHoleIP 192.168.0.101 -ApiPassword 'your_api_password' -OutputPath 'C:\Temp\pihole-config.json'

.NOTES
The exported JSON is intended for review and troubleshooting. Review the output
before sharing it to confirm the redaction level meets your needs.
#>

# Pi-hole v6 Settings Puller
param (
    [Parameter(Mandatory = $true)]
    [string]$PiHoleIP,

    [Parameter(Mandatory = $true)]
    [string]$ApiPassword,

    [string]$OutputPath
)

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $DesktopPath = [Environment]::GetFolderPath('Desktop')

    if ([string]::IsNullOrWhiteSpace($DesktopPath) -or -not (Test-Path -Path $DesktopPath -PathType Container)) {
        $DesktopPath = (Get-Location).Path
    }

    $OutputPath = Join-Path -Path $DesktopPath -ChildPath 'pihole-config.json'
}

$OutputDirectory = Split-Path -Path $OutputPath -Parent

if ($OutputDirectory -and -not (Test-Path -Path $OutputDirectory -PathType Container)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
}

$SensitiveFieldNamePattern = '(?i)(password|secret|token|session|sid|api[_-]?key|credential|private|hash|ip|address|mac|client|hostname|domain|url)'
$SensitiveValuePatterns = @(
    '^(?:\d{1,3}\.){3}\d{1,3}$',
    '^(?:(?:[0-9A-Fa-f]{1,4}:){2,7}[0-9A-Fa-f]{1,4})$',
    '^(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$',
    '^[a-zA-Z][a-zA-Z0-9+.-]*://',
    '^(?=.{1,253}$)(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$'
)

function Test-SensitiveValue {
    param (
        [string]$PropertyName,
        [object]$Value
    )

    if ($PropertyName -and $PropertyName -match $SensitiveFieldNamePattern) {
        return $true
    }

    if ($Value -isnot [string]) {
        return $false
    }

    foreach ($Pattern in $SensitiveValuePatterns) {
        if ($Value -match $Pattern) {
            return $true
        }
    }

    return $false
}

function ConvertTo-SanitizedObject {
    param (
        [object]$InputObject,
        [string]$PropertyName = ''
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if (Test-SensitiveValue -PropertyName $PropertyName -Value $InputObject) {
        return '[REDACTED]'
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $SanitizedDictionary = [ordered]@{}

        foreach ($Key in $InputObject.Keys) {
            $SanitizedDictionary[$Key] = ConvertTo-SanitizedObject -InputObject $InputObject[$Key] -PropertyName ([string]$Key)
        }

        return $SanitizedDictionary
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $SanitizedCollection = foreach ($Item in $InputObject) {
            ConvertTo-SanitizedObject -InputObject $Item -PropertyName $PropertyName
        }

        return @($SanitizedCollection)
    }

    if ($InputObject -is [pscustomobject] -or $InputObject.PSObject.Properties.Count -gt 0) {
        $SanitizedObject = [ordered]@{}

        foreach ($Property in $InputObject.PSObject.Properties) {
            if ($Property.MemberType -notin 'NoteProperty', 'Property', 'AliasProperty', 'ScriptProperty') {
                continue
            }

            $SanitizedObject[$Property.Name] = ConvertTo-SanitizedObject -InputObject $Property.Value -PropertyName $Property.Name
        }

        return $SanitizedObject
    }

    return $InputObject
}

# Get API password from pihole.toml first
# Run this once manually on the Pi-hole to get your API key:
# cat /etc/pihole/pihole.toml | grep -A5 "\[webserver.api\]"

$Headers = $null

try {
    # Authenticate and get session token
    $AuthBody = @{ password = $ApiPassword } | ConvertTo-Json
    $AuthResponse = Invoke-RestMethod -Uri "http://$PiHoleIP/api/auth" `
        -Method POST `
        -ContentType "application/json" `
        -Body $AuthBody

    $SessionID = $AuthResponse.session.sid

    $Headers = @{ "X-FTL-SID" = $SessionID }

    # Pull all config endpoints
    $Endpoints = @(
        "config",
        "stats/summary",
        "groups",
        "lists",
        "clients",
        "domains",
        "dns/blocking"
    )

    $Results = @{}

    foreach ($Endpoint in $Endpoints) {
        try {
            $Response = Invoke-RestMethod -Uri "http://$PiHoleIP/api/$Endpoint" `
                -Headers $Headers `
                -Method GET
            $Results[$Endpoint] = $Response
            Write-Host "Pulled: $Endpoint" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed: $Endpoint - $_" -ForegroundColor Red
        }
    }

    # Export to JSON
    $SanitizedResults = ConvertTo-SanitizedObject -InputObject $Results
    $SanitizedResults | ConvertTo-Json -Depth 10 | Out-File $OutputPath -Encoding UTF8

    Write-Host "`nSaved to $OutputPath" -ForegroundColor Cyan
}
finally {
    if ($Headers) {
        try {
            Invoke-RestMethod -Uri "http://$PiHoleIP/api/auth" `
                -Headers $Headers `
                -Method DELETE | Out-Null

            Write-Host "Session closed" -ForegroundColor Gray
        }
        catch {
            Write-Warning "Failed to close session: $_"
        }
    }
}