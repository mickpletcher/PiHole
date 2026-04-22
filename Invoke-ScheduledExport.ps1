param(
    [int]$DaysBack = 1
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Path $PSCommandPath -Parent
$commonScriptPath = Join-Path $scriptRoot 'PiHole.Common.ps1'
$exportScript = Join-Path $scriptRoot 'Export-PiHoleQueries.ps1'
$logDir = Join-Path $scriptRoot 'logs'

if (-not (Test-Path -LiteralPath $commonScriptPath -PathType Leaf)) {
    throw "Required script not found: $commonScriptPath"
}

. $commonScriptPath

if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = Join-Path $logDir "export_$timestamp.log"

$startTime = Get-Date

try {
    & $exportScript -DaysBack $DaysBack *>&1 | Tee-Object -FilePath $logFile
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-PiHoleFileLog -Path $logFile -Level INFO -Message "Export completed successfully in $($duration.TotalSeconds)s seconds."
}
catch {
    Write-PiHoleFileLog -Path $logFile -Level ERROR -Message "Export failed: $($_.Exception.Message)"
    throw
}
