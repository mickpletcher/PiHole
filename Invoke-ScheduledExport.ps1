param(
    [int]$DaysBack = 1
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Path $PSCommandPath -Parent
$exportScript = Join-Path $scriptRoot 'Export-PiHoleQueries.ps1'
$logDir = Join-Path $scriptRoot 'logs'

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
    
    "Export completed successfully in $($duration.TotalSeconds)s at $(Get-Date -Format 'o')" | Add-Content -LiteralPath $logFile
}
catch {
    "Export failed at $(Get-Date -Format 'o'): $_" | Add-Content -LiteralPath $logFile
    throw
}
