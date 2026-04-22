function Get-PiHoleScriptRoot {
    param(
        [string]$ScriptRoot,
        [string]$ScriptPath
    )

    if (-not [string]::IsNullOrWhiteSpace($ScriptRoot)) {
        return $ScriptRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($ScriptPath)) {
        return (Split-Path -Path $ScriptPath -Parent)
    }

    return (Get-Location).Path
}

function Write-PiHoleLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $formattedMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'WARN' {
            Write-Warning $formattedMessage
        }
        'ERROR' {
            Write-Host $formattedMessage -ForegroundColor Red
        }
        default {
            Write-Host $formattedMessage
        }
    }
}

function Write-PiHoleFileLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'o'
    Add-Content -LiteralPath $Path -Value "[$timestamp] [$Level] $Message"
}

function Ensure-PiHoleParentDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Ensure-PoshSshModule {
    param(
        [switch]$InstallIfMissing
    )

    if (Get-Module -ListAvailable -Name 'Posh-SSH' | Select-Object -First 1) {
        return $true
    }

    if (-not $InstallIfMissing) {
        return $false
    }

    Write-PiHoleLog -Level INFO -Message 'Password-based SSH configured. Installing Posh-SSH module...'

    try {
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
        }

        $psGallery = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
        if ($null -ne $psGallery -and $psGallery.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        }

        Install-Module -Name 'Posh-SSH' -Scope CurrentUser -AllowClobber -Force -ErrorAction Stop
        return $true
    }
    catch {
        throw "Could not install Posh-SSH automatically. Run this once and retry: Install-Module Posh-SSH -Scope CurrentUser -AllowClobber -Force`nDetails: $($_.Exception.Message)"
    }
}

function Resolve-PiHoleConnectionValues {
    param(
        [string]$PiHoleHost,
        [string]$UserName,
        [string]$IdentityFile,
        [string]$SshPassword,
        [string]$SudoPassword,
        [string]$SudoPasswordFilePath
    )

    $resolvedHost = if (-not [string]::IsNullOrWhiteSpace($PiHoleHost)) {
        $PiHoleHost
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:PIHOLE_HOST)) {
        $env:PIHOLE_HOST
    }
    else {
        '192.168.0.225'
    }

    $resolvedUserName = if (-not [string]::IsNullOrWhiteSpace($UserName)) {
        $UserName
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:PIHOLE_USERNAME)) {
        $env:PIHOLE_USERNAME
    }
    else {
        'root'
    }

    $resolvedIdentityFile = if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
        $IdentityFile
    }
    else {
        $env:PIHOLE_IDENTITY_FILE
    }

    $resolvedSshPassword = if (-not [string]::IsNullOrWhiteSpace($SshPassword)) {
        $SshPassword
    }
    else {
        $env:PIHOLE_SSH_PASSWORD
    }

    $resolvedSudoPassword = $SudoPassword

    if ([string]::IsNullOrWhiteSpace($resolvedSudoPassword) -and -not [string]::IsNullOrWhiteSpace($env:PIHOLE_SUDO_PASSWORD)) {
        $resolvedSudoPassword = $env:PIHOLE_SUDO_PASSWORD
    }

    if ([string]::IsNullOrWhiteSpace($resolvedSudoPassword) -and -not [string]::IsNullOrWhiteSpace($SudoPasswordFilePath) -and (Test-Path -LiteralPath $SudoPasswordFilePath -PathType Leaf)) {
        $fileSudoPassword = (Get-Content -LiteralPath $SudoPasswordFilePath -Raw).Trim()
        if (-not [string]::IsNullOrWhiteSpace($fileSudoPassword)) {
            $resolvedSudoPassword = $fileSudoPassword
        }
    }

    if ([string]::IsNullOrWhiteSpace($resolvedSudoPassword) -and -not [string]::IsNullOrWhiteSpace($resolvedSshPassword)) {
        $resolvedSudoPassword = $resolvedSshPassword
    }

    return [pscustomobject]@{
        PiHoleHost   = $resolvedHost
        UserName     = $resolvedUserName
        IdentityFile = $resolvedIdentityFile
        SshPassword  = $resolvedSshPassword
        SudoPassword = $resolvedSudoPassword
    }
}

function ConvertTo-PiHoleSqlTextLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return "'" + $Value.Replace("'", "''") + "'"
}

function ConvertTo-PiHoleSqlLikeLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $escapedValue = $Value.Replace('\', '\\').Replace('%', '\%').Replace('_', '\_').Replace('*', '%').Replace('?', '_')
    return "'" + $escapedValue.Replace("'", "''") + "'"
}

function New-PiHoleSqlFilterClause {
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
            "$ColumnName LIKE $(ConvertTo-PiHoleSqlLikeLiteral -Value $value) ESCAPE '\\'"
        }
        else {
            "$ColumnName = $(ConvertTo-PiHoleSqlTextLiteral -Value $value)"
        }
    }

    $conditions = @($conditions | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($conditions.Count -eq 0) {
        return ''
    }

    return ' AND (' + ($conditions -join ' OR ') + ')'
}

function ConvertTo-PiHoleShSingleQuoted {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return "'" + $Value.Replace("'", "'`"'`"'") + "'"
}

function New-PiHoleSshContext {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PiHoleHost,

        [Parameter(Mandatory = $true)]
        [string]$UserName,

        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,

        [string]$IdentityFile,

        [string]$SshPassword,

        [string]$SudoPassword,

        [int]$SshCommandTimeoutSeconds = 300
    )

    if ($SshCommandTimeoutSeconds -le 0) {
        throw 'SshCommandTimeoutSeconds must be greater than zero.'
    }

    $usePasswordAuth = $false
    $sshExecutable = $null

    if (-not [string]::IsNullOrWhiteSpace($SshPassword)) {
        if (Ensure-PoshSshModule) {
            $usePasswordAuth = $true
        }
        else {
            Write-PiHoleLog -Level WARN -Message 'PIHOLE_SSH_PASSWORD is set but Posh-SSH is not installed. Falling back to ssh.exe interactive SSH login.'
        }
    }

    if (-not $usePasswordAuth) {
        $sshCommand = Get-Command -Name 'ssh.exe', 'ssh' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $sshCommand) {
            throw 'OpenSSH client not found. Install the Windows OpenSSH Client feature and try again.'
        }

        $sshExecutable = $sshCommand.Source
    }

    return [pscustomobject]@{
        PiHoleHost                = $PiHoleHost
        UserName                  = $UserName
        DatabasePath              = $DatabasePath
        IdentityFile              = $IdentityFile
        SshPassword               = $SshPassword
        SudoPassword              = $SudoPassword
        SshCommandTimeoutSeconds  = $SshCommandTimeoutSeconds
        UsePasswordAuth           = $usePasswordAuth
        SshExecutable             = $sshExecutable
        SudoPasswordBase64        = if (-not [string]::IsNullOrWhiteSpace($SudoPassword)) { [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($SudoPassword)) } else { '' }
    }
}

function New-PiHoleRemoteCommand {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$SqliteCommand,

        [Parameter(Mandatory = $true)]
        [string]$BatchBase64
    )

    $databasePathArgument = ConvertTo-PiHoleShSingleQuoted -Value $Connection.DatabasePath

    if ($SqliteCommand.StartsWith('sudo ')) {
        $sudoTarget = $SqliteCommand.Substring(5)

        if (-not [string]::IsNullOrWhiteSpace($Connection.SudoPasswordBase64)) {
            return [string]::Format(
                'batch=$(printf ''%s'' ''{0}'' | base64 -d); sudo_pw=$(printf ''%s'' ''{1}'' | base64 -d); printf ''%s\n'' "$sudo_pw" | sudo -S -p '''' sh -c ''printf "%s" "$1" | {2} {3}'' _ "$batch"',
                $BatchBase64,
                $Connection.SudoPasswordBase64,
                $sudoTarget,
                $databasePathArgument
            )
        }

        $sudoPrefix = if ($Connection.UsePasswordAuth) { 'sudo -n' } else { 'sudo' }
        return [string]::Format(
            'batch=$(printf ''%s'' ''{0}'' | base64 -d); {1} sh -c ''printf "%s" "$1" | {2} {3}'' _ "$batch"',
            $BatchBase64,
            $sudoPrefix,
            $sudoTarget,
            $databasePathArgument
        )
    }

    return [string]::Format(
        'batch=$(printf ''%s'' ''{0}'' | base64 -d); printf "%s" "$batch" | {1} {2}',
        $BatchBase64,
        $SqliteCommand,
        $databasePathArgument
    )
}

function Invoke-PiHoleRemoteSqlQuery {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$SqliteCommand,

        [Parameter(Mandatory = $true)]
        [string]$BatchBase64,

        [int]$TimeoutOverride = 0
    )

    $effectiveTimeout = if ($TimeoutOverride -gt 0) { $TimeoutOverride } else { $Connection.SshCommandTimeoutSeconds }
    $remoteCommand = New-PiHoleRemoteCommand -Connection $Connection -SqliteCommand $SqliteCommand -BatchBase64 $BatchBase64

    if ($Connection.UsePasswordAuth) {
        Import-Module Posh-SSH -ErrorAction Stop | Out-Null

        $securePassword = ConvertTo-SecureString -String $Connection.SshPassword -AsPlainText -Force
        $credential = [System.Management.Automation.PSCredential]::new($Connection.UserName, $securePassword)

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
        } -ArgumentList $Connection.PiHoleHost, $credential, $remoteCommand, $effectiveTimeout

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

    if (-not [string]::IsNullOrWhiteSpace($Connection.IdentityFile)) {
        $sshArgs.Add('-i')
        $sshArgs.Add($Connection.IdentityFile)
    }

    $sshArgs.Add("$($Connection.UserName)@$($Connection.PiHoleHost)")

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
    } -ArgumentList $Connection.SshExecutable, @($sshArgs), $remoteCommand

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

function Find-PiHoleWorkingSqliteCommand {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$ProbeBatchBase64,

        [int]$ProbeTimeoutSeconds = 15
    )

    $sqliteCommands = @(
        'sqlite3',
        'sudo sqlite3',
        'pihole-FTL sqlite3',
        'sudo pihole-FTL sqlite3'
    )

    $attemptErrors = [System.Collections.Generic.List[string]]::new()

    foreach ($sqliteCommand in $sqliteCommands) {
        Write-PiHoleLog -Level INFO -Message "Probing remote command: $sqliteCommand"
        $probeResult = Invoke-PiHoleRemoteSqlQuery -Connection $Connection -SqliteCommand $sqliteCommand -BatchBase64 $ProbeBatchBase64 -TimeoutOverride $ProbeTimeoutSeconds

        if ($probeResult.ExitCode -eq 0) {
            return $sqliteCommand
        }

        $attemptOutput = ($probeResult.Output -join [Environment]::NewLine).Trim()
        if ([string]::IsNullOrWhiteSpace($attemptOutput)) {
            $attemptErrors.Add("$sqliteCommand is not available (exit code $($probeResult.ExitCode)).")
        }
        else {
            $attemptErrors.Add("$sqliteCommand is not available (exit code $($probeResult.ExitCode)): $attemptOutput")
        }
    }

    throw "No working SQLite command found on the remote host.`n$($attemptErrors -join [Environment]::NewLine)"
}

function ConvertTo-PiHoleCsvField {
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

function ConvertFrom-PiHolePipeDelimitedRow {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line
    )

    $parts = $Line.Split('|', 4)
    if ($parts.Count -lt 4) {
        return $null
    }

    return (
        (ConvertTo-PiHoleCsvField -Value $parts[0].Trim()),
        (ConvertTo-PiHoleCsvField -Value $parts[1].Trim()),
        (ConvertTo-PiHoleCsvField -Value $parts[2].Trim()),
        (ConvertTo-PiHoleCsvField -Value $parts[3].Trim())
    ) -join ','
}

function Invoke-PiHoleQueryExport {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$StatusCodes,

        [int]$DaysBack = 0,

        [string[]]$DomainFilter,

        [string[]]$ClientFilter
    )

    if ($DaysBack -lt 0) {
        throw 'DaysBack cannot be negative.'
    }

    Ensure-PiHoleParentDirectory -Path $OutputPath

    $timeFilter = if ($DaysBack -gt 0) { " AND timestamp >= strftime('%s', 'now', '-$DaysBack days')" } else { '' }
    $domainWhereClause = New-PiHoleSqlFilterClause -ColumnName 'domain' -Values $DomainFilter
    $clientWhereClause = New-PiHoleSqlFilterClause -ColumnName 'client' -Values $ClientFilter

    $sql = @"
SELECT
    datetime(timestamp, 'unixepoch', 'localtime') AS time,
    domain,
    client,
    status
FROM queries
WHERE status IN ($StatusCodes)$timeFilter$domainWhereClause$clientWhereClause
ORDER BY timestamp;
"@.Trim()

    $sqliteBatch = ".headers on`n.mode csv`n$sql"
    $sqliteBatchBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($sqliteBatch))
    $probeBatch = ".headers off`n.mode csv`nSELECT 1;"
    $probeSqliteBatchBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($probeBatch))

    Write-PiHoleLog -Level INFO -Message "Connecting to $($Connection.UserName)@$($Connection.PiHoleHost)..."
    $workingCommand = Find-PiHoleWorkingSqliteCommand -Connection $Connection -ProbeBatchBase64 $probeSqliteBatchBase64
    Write-PiHoleLog -Level INFO -Message "Running export with: $workingCommand"
    $queryResult = Invoke-PiHoleRemoteSqlQuery -Connection $Connection -SqliteCommand $workingCommand -BatchBase64 $sqliteBatchBase64

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
                $convertedLine = ConvertFrom-PiHolePipeDelimitedRow -Line $line
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
                $convertedLine = ConvertFrom-PiHolePipeDelimitedRow -Line $line
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
    Write-PiHoleLog -Level INFO -Message "Export complete. Rows written: $rowsExported"
    Write-PiHoleLog -Level INFO -Message "Saved to: $OutputPath"
}
