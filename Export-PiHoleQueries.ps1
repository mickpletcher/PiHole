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

$commonScriptPath = Join-Path (if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }) 'PiHole.Common.ps1'
if (-not (Test-Path -LiteralPath $commonScriptPath -PathType Leaf)) {
    throw "Required script not found: $commonScriptPath"
}

. $commonScriptPath

$scriptDirectory = Get-PiHoleScriptRoot -ScriptRoot $PSScriptRoot -ScriptPath $PSCommandPath

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

$resolvedAllowedOutputPath = if (-not [string]::IsNullOrWhiteSpace($AllowedOutputPath)) { $AllowedOutputPath } else { Join-Path $scriptDirectory 'allowed_only_queries.csv' }
$resolvedBlockedOutputPath = if (-not [string]::IsNullOrWhiteSpace($BlockedOutputPath)) { $BlockedOutputPath } else { Join-Path $scriptDirectory 'blocked_only_queries.csv' }
$resolvedSudoPasswordFilePath = if (-not [string]::IsNullOrWhiteSpace($SudoPasswordFilePath)) { $SudoPasswordFilePath } else { Join-Path $scriptDirectory 'PiHoleSudoPassword.local.txt' }

if (-not [System.IO.Path]::IsPathRooted($resolvedSudoPasswordFilePath)) {
    $resolvedSudoPasswordFilePath = Join-Path $scriptDirectory $resolvedSudoPasswordFilePath
}

try {
    Write-PiHoleLog -Level INFO -Message 'Loading local Pi-hole environment variables...'
    & $setEnvScriptPath

    $resolvedConnection = Resolve-PiHoleConnectionValues `
        -PiHoleHost $PiHoleHost `
        -UserName $UserName `
        -IdentityFile $IdentityFile `
        -SshPassword $SshPassword `
        -SudoPassword $SudoPassword `
        -SudoPasswordFilePath $resolvedSudoPasswordFilePath

    if (-not [string]::IsNullOrWhiteSpace($resolvedConnection.SshPassword)) {
        Ensure-PoshSshModule -InstallIfMissing | Out-Null
    }

    $commonParameters = @{
        PiHoleHost   = $resolvedConnection.PiHoleHost
        UserName     = $resolvedConnection.UserName
        DatabasePath = $DatabasePath
        SshCommandTimeoutSeconds = $SshCommandTimeoutSeconds
        DaysBack     = $DaysBack
    }

    if (-not [string]::IsNullOrWhiteSpace($resolvedConnection.IdentityFile)) {
        $commonParameters.IdentityFile = $resolvedConnection.IdentityFile
    }

    if (-not [string]::IsNullOrWhiteSpace($resolvedConnection.SshPassword)) {
        $commonParameters.SshPassword = $resolvedConnection.SshPassword
    }

    if (-not [string]::IsNullOrWhiteSpace($resolvedConnection.SudoPassword)) {
        $commonParameters.SudoPassword = $resolvedConnection.SudoPassword
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

    Write-PiHoleLog -Level INFO -Message 'Exporting allowed queries...'
    & $allowedScriptPath @allowedParameters

    Write-PiHoleLog -Level INFO -Message 'Exporting blocked queries...'
    & $blockedScriptPath @blockedParameters

    Write-PiHoleLog -Level INFO -Message 'Removing duplicate rows from allowed export...'
    & $dedupeScriptPath -InputPath $resolvedAllowedOutputPath

    Write-PiHoleLog -Level INFO -Message 'Removing duplicate rows from blocked export...'
    & $dedupeScriptPath -InputPath $resolvedBlockedOutputPath

    Write-PiHoleLog -Level INFO -Message 'Both exports and dedupe steps completed.'
}
finally {
    Write-PiHoleLog -Level INFO -Message 'Clearing local Pi-hole environment variables...'
    & $clearEnvScriptPath
}
