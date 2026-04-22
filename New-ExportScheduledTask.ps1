$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Path $PSCommandPath -Parent
$invokeScript = Join-Path $scriptRoot 'Invoke-ScheduledExport.ps1'

$taskName = 'PiHole-ExportQueries'
$taskPath = '\PiHole\'

Import-Module ScheduledTasks -ErrorAction Stop

try {
    Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop | Remove-ScheduledTask -Confirm:$false
    Write-Host "Removed existing task"
}
catch {
    Write-Host "No existing task found"
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$invokeScript`" -DaysBack 1"

$trigger = New-ScheduledTaskTrigger `
    -Daily `
    -At 01:00AM

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -RunOnlyIfIdle

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -TaskPath $taskPath `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Force | Out-Null

$task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath
Write-Host "Task created: $($task.TaskPath)$($task.TaskName)"
Write-Host "Trigger: Daily at 01:00 AM"
Write-Host "Status: $($task.State)"
