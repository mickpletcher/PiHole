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

if ($DaysBack -lt 0) {
    throw 'DaysBack cannot be negative.'
}

if ($SshCommandTimeoutSeconds -le 0) {
    throw 'SshCommandTimeoutSeconds must be greater than zero.'
}

function ConvertTo-SqlTextLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return "'" + $Value.Replace("'", "''") + "'"
}

function ConvertTo-SqlLikeLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $escapedValue = $Value.Replace('\', '\\').Replace('%', '\%').Replace('_', '\_').Replace('*', '%').Replace('?', '_')
    return "'" + $escapedValue.Replace("'", "''") + "'"
}

function New-SqlFilterClause {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ColumnName,

        [string[]]$Values
    )

    if ($null -eq $Values -or $Values.Count -eq 0) {
        return ''
    }

    $conditions = foreach ($value in $Values) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        if ($value.Contains('*') -or $value.Contains('?')) {
            "$ColumnName LIKE $(ConvertTo-SqlLikeLiteral -Value $value) ESCAPE '\\'"
        }
        else {
            "$ColumnName = $(ConvertTo-SqlTextLiteral -Value $value)"
        }
    }

    $conditions = @($conditions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($conditions.Count -eq 0) {
        return ''
    }

    return ' AND (' + ($conditions -join ' OR ') + ')'
}

$scriptDirectory = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptDirectory 'blocked_only_queries.csv'
}

$outputDirectory = Split-Path -Path $OutputPath -Parent
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$usePasswordAuth = $false

if (-not [string]::IsNullOrWhiteSpace($SshPassword)) {
    $poshSshModule = Get-Module -ListAvailable -Name 'Posh-SSH' | Select-Object -First 1
    if ($poshSshModule) {
        $usePasswordAuth = $true
    }
    else {
        Write-Warning 'PIHOLE_SSH_PASSWORD is set but Posh-SSH is not installed. Falling back to ssh.exe interactive SSH login.'
    }
}

if (-not $usePasswordAuth) {
    $sshCommand = Get-Command -Name 'ssh.exe', 'ssh' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sshCommand) {
        throw 'OpenSSH client not found. Install the Windows OpenSSH Client feature and try again.'
    }
}

$blockedStatusCodes = '1, 4, 5, 6, 7, 8, 9, 10, 11, 15, 16, 18'
$timeFilter = if ($DaysBack -gt 0) { " AND timestamp >= strftime('%s', 'now', '-$DaysBack days')" } else { '' }
$domainWhereClause = New-SqlFilterClause -ColumnName 'domain' -Values $DomainFilter
$clientWhereClause = New-SqlFilterClause -ColumnName 'client' -Values $ClientFilter

$sql = @"
SELECT
    datetime(timestamp, 'unixepoch', 'localtime') AS time,
    domain,
    client,
    status
FROM queries
WHERE status IN ($blockedStatusCodes)$timeFilter$domainWhereClause$clientWhereClause
ORDER BY timestamp;
"@.Trim()

$sqliteBatch = ".headers on`n.mode csv`n$sql"
$sqliteBatchBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($sqliteBatch))
$probeBatch = ".headers off`n.mode csv`nSELECT 1;"
$probeSqliteBatchBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($probeBatch))
$sudoPasswordBase64 = if (-not [string]::IsNullOrWhiteSpace($SudoPassword)) { [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($SudoPassword)) } else { '' }

function ConvertTo-ShSingleQuoted {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return "'" + $Value.Replace("'", "'`"'`"'") + "'"
}

function New-RemoteCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqliteCommand,

        [string]$BatchBase64Override
    )

    $activeBatch = if ([string]::IsNullOrWhiteSpace($BatchBase64Override)) { $sqliteBatchBase64 } else { $BatchBase64Override }
    $databasePathArgument = ConvertTo-ShSingleQuoted -Value $DatabasePath

    if ($SqliteCommand.StartsWith('sudo ')) {
        $sudoTarget = $SqliteCommand.Substring(5)

        if (-not [string]::IsNullOrWhiteSpace($sudoPasswordBase64)) {
            return [string]::Format(
                'batch=$(printf ''%s'' ''{0}'' | base64 -d); sudo_pw=$(printf ''%s'' ''{1}'' | base64 -d); printf ''%s\n'' "$sudo_pw" | sudo -S -p '''' sh -c ''printf "%s" "$1" | {2} {3}'' _ "$batch"',
                $activeBatch,
                $sudoPasswordBase64,
                $sudoTarget,
                $databasePathArgument
            )
        }

        $sudoPrefix = if ($usePasswordAuth) { 'sudo -n' } else { 'sudo' }
        return [string]::Format(
            'batch=$(printf ''%s'' ''{0}'' | base64 -d); {1} sh -c ''printf "%s" "$1" | {2} {3}'' _ "$batch"',
            $activeBatch,
            $sudoPrefix,
            $sudoTarget,
            $databasePathArgument
        )
    }

    return [string]::Format(
        'batch=$(printf ''%s'' ''{0}'' | base64 -d); printf "%s" "$batch" | {1} {2}',
        $activeBatch,
        $SqliteCommand,
        $databasePathArgument
    )
}

function Invoke-RemoteSqlQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqliteCommand,

        [string]$BatchBase64Override,

        [int]$TimeoutOverride = 0
    )

    $effectiveTimeout = if ($TimeoutOverride -gt 0) { $TimeoutOverride } else { $SshCommandTimeoutSeconds }

    if ($usePasswordAuth) {
        Import-Module Posh-SSH -ErrorAction Stop | Out-Null

        $securePassword = ConvertTo-SecureString -String $SshPassword -AsPlainText -Force
        $credential = [System.Management.Automation.PSCredential]::new($UserName, $securePassword)
        $remoteCommand = New-RemoteCommand -SqliteCommand $SqliteCommand -BatchBase64Override $BatchBase64Override

        $job = Start-Job -ScriptBlock {
            param(
                [string]$HostName,
                [System.Management.Automation.PSCredential]$Credential,
                [string]$CommandText,
                [int]$CommandTimeoutSeconds
            )

            Import-Module Posh-SSH -ErrorAction Stop | Out-Null
            $session = $null

            try {
                $session = New-SSHSession -ComputerName $HostName -Credential $Credential -AcceptKey -ConnectionTimeout 10 -ErrorAction Stop
                $commandResult = Invoke-SSHCommand -SessionId $session.SessionId -Command $CommandText -TimeOut $CommandTimeoutSeconds -ErrorAction Stop
                $exitCode = if ($null -ne $commandResult.ExitStatus) { [int]$commandResult.ExitStatus } else { 0 }
                $output = @($commandResult.Output | ForEach-Object { [string]$_ })
                $errorOutput = @($commandResult.Error | ForEach-Object { [string]$_ })

                return [pscustomobject]@{
                    ExitCode = $exitCode
                    Output   = @($output + $errorOutput)
                }
            }
            catch {
                return [pscustomobject]@{
                    ExitCode = 124
                    Output   = @([string]$_.Exception.Message)
                }
            }
            finally {
                if ($null -ne $session) {
                    Remove-SSHSession -SessionId $session.SessionId | Out-Null
                }
            }
        } -ArgumentList $PiHoleHost, $credential, $remoteCommand, $effectiveTimeout

        try {
            if (-not (Wait-Job -Job $job -Timeout $effectiveTimeout)) {
                Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
                return [pscustomobject]@{
                    ExitCode = 124
                    Output   = @("$SqliteCommand timed out after $effectiveTimeout seconds.")
                }
            }

            $result = Receive-Job -Job $job
            return [pscustomobject]@{
                ExitCode = [int]$result.ExitCode
                Output   = @($result.Output | ForEach-Object { [string]$_ })
            }
        }
        finally {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

    $sshArgs = [System.Collections.Generic.List[string]]::new()
    $sshArgs.Add('-o')
    $sshArgs.Add('StrictHostKeyChecking=accept-new')
    $sshArgs.Add('-o')
    $sshArgs.Add('LogLevel=ERROR')
    $sshArgs.Add('-o')
    $sshArgs.Add('BatchMode=yes')
    $sshArgs.Add('-o')
    $sshArgs.Add('ConnectTimeout=10')

    if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
        $sshArgs.Add('-i')
        $sshArgs.Add($IdentityFile)
    }

    $sshArgs.Add("$UserName@$PiHoleHost")

    $remoteCommand = New-RemoteCommand -SqliteCommand $SqliteCommand -BatchBase64Override $BatchBase64Override

    $job = Start-Job -ScriptBlock {
        param(
            [string]$SshExecutable,
            [string[]]$ArgumentList,
            [string]$CommandText
        )

        $output = & $SshExecutable @ArgumentList 'sh' '-c' $CommandText 2>&1
        $exitCode = $LASTEXITCODE

        return [pscustomobject]@{
            ExitCode = $exitCode
            Output   = @($output | ForEach-Object { [string]$_ })
        }
    } -ArgumentList $sshCommand.Source, @($sshArgs), $remoteCommand

    try {
        if (-not (Wait-Job -Job $job -Timeout $effectiveTimeout)) {
            Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
            return [pscustomobject]@{
                ExitCode = 124
                Output   = @("$SqliteCommand timed out after $effectiveTimeout seconds.")
            }
        }

        $result = Receive-Job -Job $job -ErrorAction Stop
        return [pscustomobject]@{
            ExitCode = [int]$result.ExitCode
            Output   = @($result.Output | ForEach-Object { [string]$_ })
        }
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Host "Connecting to $UserName@$PiHoleHost..."

$sqliteCommands = @(
    'sqlite3',
    'sudo sqlite3',
    'pihole-FTL sqlite3',
    'sudo pihole-FTL sqlite3'
)

$workingCommand = $null
$attemptErrors = [System.Collections.Generic.List[string]]::new()

foreach ($sqliteCommand in $sqliteCommands) {
    Write-Host "Probing remote command: $sqliteCommand"
    $probeResult = Invoke-RemoteSqlQuery -SqliteCommand $sqliteCommand -BatchBase64Override $probeSqliteBatchBase64 -TimeoutOverride 15
    if ($probeResult.ExitCode -eq 0) {
        $workingCommand = $sqliteCommand
        break
    }

    $attemptOutput = ($probeResult.Output -join [Environment]::NewLine).Trim()
    if ([string]::IsNullOrWhiteSpace($attemptOutput)) {
        $attemptErrors.Add("$sqliteCommand is not available (exit code $($probeResult.ExitCode)).")
    }
    else {
        $attemptErrors.Add("$sqliteCommand is not available (exit code $($probeResult.ExitCode)): $attemptOutput")
    }
}

if ($null -eq $workingCommand) {
    throw "No working SQLite command found on the remote host.`n$($attemptErrors -join [Environment]::NewLine)"
}

Write-Host "Running export with: $workingCommand"
$queryResult = Invoke-RemoteSqlQuery -SqliteCommand $workingCommand

function ConvertTo-CsvField {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    $escapedValue = $Value.Replace('"', '""')
    if ($escapedValue.Contains(',') -or $escapedValue.Contains('"') -or $escapedValue.Contains("`n") -or $escapedValue.Contains("`r")) {
        return '"' + $escapedValue + '"'
    }

    return $escapedValue
}

function Convert-PipeLineToCsvLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $parts = $Line.Split('|', 4)
    if ($parts.Count -lt 4) {
        return $null
    }

    return (
        (ConvertTo-CsvField -Value $parts[0].Trim()),
        (ConvertTo-CsvField -Value $parts[1].Trim()),
        (ConvertTo-CsvField -Value $parts[2].Trim()),
        (ConvertTo-CsvField -Value $parts[3].Trim())
    ) -join ','
}

$expectedCsvHeader = 'time,domain,client,status'
$pipeHeader = 'time|domain|client|status'
$rawLines = @($queryResult.Output | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) })

if ($rawLines.Count -eq 0) {
    throw 'The Pi-hole query export returned no data.'
}

$headerIndex = -1
for ($index = 0; $index -lt $rawLines.Count; $index++) {
    $currentLine = $rawLines[$index].Trim()
    if ($currentLine -eq $expectedCsvHeader -or $currentLine -eq $pipeHeader) {
        $headerIndex = $index
        break
    }
}

$csvLines = @()

if ($headerIndex -ge 0) {
    $firstHeader = $rawLines[$headerIndex].Trim()
    if ($firstHeader -eq $expectedCsvHeader) {
        $csvLines = @($rawLines[$headerIndex..($rawLines.Count - 1)])
    }
    else {
        $convertedData = @()
        foreach ($line in $rawLines[($headerIndex + 1)..($rawLines.Count - 1)]) {
            $convertedLine = Convert-PipeLineToCsvLine -Line $line
            if (-not [string]::IsNullOrWhiteSpace($convertedLine)) {
                $convertedData += $convertedLine
            }
        }

        $csvLines = @($expectedCsvHeader) + $convertedData
    }
}
else {
    $firstDataLine = $rawLines[0].Trim()

    if ($firstDataLine.Contains('|')) {
        $convertedData = @()
        foreach ($line in $rawLines) {
            $convertedLine = Convert-PipeLineToCsvLine -Line $line
            if (-not [string]::IsNullOrWhiteSpace($convertedLine)) {
                $convertedData += $convertedLine
            }
        }

        $csvLines = @($expectedCsvHeader) + $convertedData
    }
    elseif ($firstDataLine.Contains(',')) {
        $csvLines = @($expectedCsvHeader) + $rawLines
    }
    else {
        throw "Unexpected query output format from Pi-hole. First line: $firstDataLine"
    }
}

if ($csvLines.Count -le 1) {
    throw 'The Pi-hole query export returned no data rows.'
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines($OutputPath, $csvLines, $utf8NoBom)

$rowsExported = [Math]::Max(0, $csvLines.Count - 1)
Write-Host "Export complete. Rows written: $rowsExported"
Write-Host "Saved to: $OutputPath"