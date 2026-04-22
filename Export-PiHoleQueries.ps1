param(
    [string]$PiHoleHost,

    [string]$UserName,

    [string]$AllowedOutputPath,

    [string]$BlockedOutputPath,

    [string]$DatabasePath = '/etc/pihole/pihole-FTL.db',

    [string]$IdentityFile,

    [string]$SshPassword,

    [string]$SudoPassword,

    [string]$SudoPasswordFilePath,

    [int]$SshCommandTimeoutSeconds = 300,

    [int]$DaysBack = 0,

    [string[]]$DomainFilter,

    [string[]]$ClientFilter
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }

$allowedScriptPath = Join-Path $scriptDirectory 'Export-PiHoleAllowedQueries.ps1'
$blockedScriptPath = Join-Path $scriptDirectory 'Export-PiHoleBlockedQueries.ps1'
$setEnvScriptPath = Join-Path $scriptDirectory 'Set-PiHoleSecretEnv.local.ps1'
$clearEnvScriptPath = Join-Path $scriptDirectory 'Clear-PiHoleSecretEnv.local.ps1'
$dedupeScriptPath = Join-Path $scriptDirectory 'Remove-DuplicateCsvRows.ps1'

if (-not (Test-Path -LiteralPath $allowedScriptPath -PathType Leaf)) {
    throw "Required script not found: $allowedScriptPath"
}

if (-not (Test-Path -LiteralPath $blockedScriptPath -PathType Leaf)) {
    throw "Required script not found: $blockedScriptPath"
}

if (-not (Test-Path -LiteralPath $setEnvScriptPath -PathType Leaf)) {
    throw "Required script not found: $setEnvScriptPath"
}

if (-not (Test-Path -LiteralPath $clearEnvScriptPath -PathType Leaf)) {
    throw "Required script not found: $clearEnvScriptPath"
}

if (-not (Test-Path -LiteralPath $dedupeScriptPath -PathType Leaf)) {
    throw "Required script not found: $dedupeScriptPath"
}

function Ensure-PoshSshModule {
    if (Get-Module -ListAvailable -Name 'Posh-SSH' | Select-Object -First 1) {
        return
    }

    Write-Host 'Password based SSH configured. Installing Posh-SSH module...'

    try {
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
        }

        $psGallery = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
        if ($null -ne $psGallery -and $psGallery.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }

        Install-Module -Name 'Posh-SSH' -Scope CurrentUser -AllowClobber -Force -ErrorAction Stop
    }
    catch {
        throw "Could not install Posh-SSH automatically. Run this once and retry: Install-Module Posh-SSH -Scope CurrentUser -AllowClobber -Force`nDetails: $($_.Exception.Message)"
    }
}

$resolvedAllowedOutputPath = if (-not [string]::IsNullOrWhiteSpace($AllowedOutputPath)) { $AllowedOutputPath } else { Join-Path $scriptDirectory 'allowed_only_queries.csv' }
$resolvedBlockedOutputPath = if (-not [string]::IsNullOrWhiteSpace($BlockedOutputPath)) { $BlockedOutputPath } else { Join-Path $scriptDirectory 'blocked_only_queries.csv' }
$resolvedSudoPasswordFilePath = if (-not [string]::IsNullOrWhiteSpace($SudoPasswordFilePath)) { $SudoPasswordFilePath } else { Join-Path $scriptDirectory 'PiHoleSudoPassword.local.txt' }

if (-not [System.IO.Path]::IsPathRooted($resolvedSudoPasswordFilePath)) {
    $resolvedSudoPasswordFilePath = Join-Path $scriptDirectory $resolvedSudoPasswordFilePath
}

try {
    Write-Host 'Loading local Pi-hole environment variables...'
    & $setEnvScriptPath

    if ([string]::IsNullOrWhiteSpace($PiHoleHost)) {
        $PiHoleHost = if (-not [string]::IsNullOrWhiteSpace($env:PIHOLE_HOST)) { $env:PIHOLE_HOST } else { '192.168.0.225' }
    }

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        $UserName = if (-not [string]::IsNullOrWhiteSpace($env:PIHOLE_USERNAME)) { $env:PIHOLE_USERNAME } else { 'root' }
    }

    if ([string]::IsNullOrWhiteSpace($IdentityFile) -and -not [string]::IsNullOrWhiteSpace($env:PIHOLE_IDENTITY_FILE)) {
        $IdentityFile = $env:PIHOLE_IDENTITY_FILE
    }

    if ([string]::IsNullOrWhiteSpace($SshPassword) -and -not [string]::IsNullOrWhiteSpace($env:PIHOLE_SSH_PASSWORD)) {
        $SshPassword = $env:PIHOLE_SSH_PASSWORD
    }

    if ([string]::IsNullOrWhiteSpace($SudoPassword)) {
        if (-not [string]::IsNullOrWhiteSpace($env:PIHOLE_SUDO_PASSWORD)) {
            $SudoPassword = $env:PIHOLE_SUDO_PASSWORD
        }
        elseif (Test-Path -LiteralPath $resolvedSudoPasswordFilePath -PathType Leaf) {
            $fileSudoPassword = (Get-Content -LiteralPath $resolvedSudoPasswordFilePath -Raw).Trim()
            if (-not [string]::IsNullOrWhiteSpace($fileSudoPassword)) {
                $SudoPassword = $fileSudoPassword
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($SshPassword)) {
            $SudoPassword = $SshPassword
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($SshPassword)) {
        Ensure-PoshSshModule
    }

    $commonParameters = @{
        PiHoleHost   = $PiHoleHost
        UserName     = $UserName
        DatabasePath = $DatabasePath
        SshCommandTimeoutSeconds = $SshCommandTimeoutSeconds
        DaysBack     = $DaysBack
    }

    if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
        $commonParameters.IdentityFile = $IdentityFile
    }

    if (-not [string]::IsNullOrWhiteSpace($SshPassword)) {
        $commonParameters.SshPassword = $SshPassword
    }

    if (-not [string]::IsNullOrWhiteSpace($SudoPassword)) {
        $commonParameters.SudoPassword = $SudoPassword
    }

    if ($null -ne $DomainFilter -and $DomainFilter.Count -gt 0) {
        $commonParameters.DomainFilter = $DomainFilter
    }

    if ($null -ne $ClientFilter -and $ClientFilter.Count -gt 0) {
        $commonParameters.ClientFilter = $ClientFilter
    }

    $allowedParameters = @{} + $commonParameters
    $blockedParameters = @{} + $commonParameters
    $allowedParameters.OutputPath = $resolvedAllowedOutputPath
    $blockedParameters.OutputPath = $resolvedBlockedOutputPath

    Write-Host 'Exporting allowed queries...'
    & $allowedScriptPath @allowedParameters

    Write-Host 'Exporting blocked queries...'
    & $blockedScriptPath @blockedParameters

    Write-Host 'Removing duplicate rows from allowed export...'
    & $dedupeScriptPath -InputPath $resolvedAllowedOutputPath

    Write-Host 'Removing duplicate rows from blocked export...'
    & $dedupeScriptPath -InputPath $resolvedBlockedOutputPath

    Write-Host 'Both exports and dedupe steps completed.'
}
finally {
    Write-Host 'Clearing local Pi-hole environment variables...'
    & $clearEnvScriptPath
}