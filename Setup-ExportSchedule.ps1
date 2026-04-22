$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Path $PSCommandPath -Parent
$invokeScript = Join-Path $scriptRoot 'Invoke-ScheduledExport.ps1'

$taskName = 'PiHole-ExportQueries'

$command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$invokeScript`" -DaysBack 1"

schtasks.exe /delete /tn $taskName /f 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Removed existing task"
}

schtasks.exe /create /tn $taskName /tr "$command" /sc daily /st 01:00 /f

if ($LASTEXITCODE -eq 0) {
    Write-Host "Task created successfully"
    Write-Host "Task name: $taskName"
    Write-Host "Trigger: Daily at 01:00 AM"
    
    schtasks.exe /query /tn $taskName /fo list
}
else {
    throw "Failed to create scheduled task. Exit code: $LASTEXITCODE"
}
