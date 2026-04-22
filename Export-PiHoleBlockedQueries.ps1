param(
    [string]$PiHoleHost = $(if (-not [string]::IsNullOrWhiteSpace($env:PIHOLE_HOST)) { $env:PIHOLE_HOST } else { '192.168.0.225' }),

    [string]$UserName = $(if (-not [string]::IsNullOrWhiteSpace($env:PIHOLE_USERNAME)) { $env:PIHOLE_USERNAME } else { 'root' }),

    [string]$OutputPath,

    [string]$DatabasePath = '/etc/pihole/pihole-FTL.db',

    [string]$IdentityFile = $env:PIHOLE_IDENTITY_FILE,

    [string]$SshPassword = $env:PIHOLE_SSH_PASSWORD,

    [string]$SudoPassword = $(if (-not [string]::IsNullOrWhiteSpace($env:PIHOLE_SUDO_PASSWORD)) { $env:PIHOLE_SUDO_PASSWORD } else { $env:PIHOLE_SSH_PASSWORD }),

    [int]$SshCommandTimeoutSeconds = 300,

    [int]$DaysBack = 0,

    [string[]]$DomainFilter,

    [string[]]$ClientFilter
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$commonScriptPath = Join-Path (if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }) 'PiHole.Common.ps1'
if (-not (Test-Path -LiteralPath $commonScriptPath -PathType Leaf)) {
    throw "Required script not found: $commonScriptPath"
}

. $commonScriptPath

if ($DaysBack -lt 0) {
    throw 'DaysBack cannot be negative.'
}

$scriptDirectory = Get-PiHoleScriptRoot -ScriptRoot $PSScriptRoot -ScriptPath $PSCommandPath

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptDirectory 'blocked_only_queries.csv'
}

$connection = New-PiHoleSshContext `
    -PiHoleHost $PiHoleHost `
    -UserName $UserName `
    -DatabasePath $DatabasePath `
    -IdentityFile $IdentityFile `
    -SshPassword $SshPassword `
    -SudoPassword $SudoPassword `
    -SshCommandTimeoutSeconds $SshCommandTimeoutSeconds

Invoke-PiHoleQueryExport `
    -Connection $connection `
    -OutputPath $OutputPath `
    -StatusCodes '1, 4, 5, 6, 7, 8, 9, 10, 11, 15, 16, 18' `
    -DaysBack $DaysBack `
    -DomainFilter $DomainFilter `
    -ClientFilter $ClientFilter
