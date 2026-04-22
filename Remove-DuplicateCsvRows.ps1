param(
    [string]$InputPath,

    [string]$OutputPath,

    [string[]]$IncludeFilePattern = @('*'),

    [string[]]$ExcludeFilePattern = @('*.deduped.csv'),

    [string]$Delimiter = ',',

    [int[]]$KeyColumns = @(2, 3, 4)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }

function ConvertTo-CsvLine {
    param(
        [string[]]$Fields
    )

    if ($null -eq $Fields) {
        $Fields = @('')
    }

    $escaped = foreach ($field in $Fields) {
        $value = if ($null -eq $field) { '' } else { [string]$field }
        if ($value.Contains('"') -or $value.Contains(',') -or $value.Contains("`r") -or $value.Contains("`n")) {
            '"' + ($value -replace '"', '""') + '"'
        }
        else {
            $value
        }
    }

    return ($escaped -join ',')
}

function New-DedupeKey {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Values
    )

    $parts = foreach ($value in $Values) {
        $v = if ($null -eq $value) { '' } else { $value }
        '{0}:{1}' -f $v.Length, $v
    }

    return ($parts -join '|')
}

if ([string]::IsNullOrEmpty($Delimiter)) {
    throw 'Delimiter cannot be empty.'
}

if ($KeyColumns.Count -eq 0) {
    throw 'KeyColumns must contain at least one 1-based column index.'
}

if ($KeyColumns | Where-Object { $_ -lt 1 }) {
    throw 'KeyColumns must be 1-based positive integers.'
}

if ($null -eq $IncludeFilePattern -or $IncludeFilePattern.Count -eq 0) {
    throw 'IncludeFilePattern must contain at least one wildcard pattern.'
}

if ($IncludeFilePattern | Where-Object { [string]::IsNullOrWhiteSpace($_) }) {
    throw 'IncludeFilePattern cannot contain blank values.'
}

if ($null -ne $ExcludeFilePattern -and ($ExcludeFilePattern | Where-Object { [string]::IsNullOrWhiteSpace($_) })) {
    throw 'ExcludeFilePattern cannot contain blank values.'
}

Add-Type -AssemblyName Microsoft.VisualBasic

function Get-DefaultOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$InputItem
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputItem.Name)
    return (Join-Path $InputItem.DirectoryName ($baseName + '.deduped.csv'))
}

function Invoke-DedupeCsvFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedInputPath,

        [Parameter(Mandatory = $true)]
        [string]$ResolvedOutputPath
    )

    $outputParent = Split-Path -Path $ResolvedOutputPath -Parent
    if ($outputParent -and -not (Test-Path -LiteralPath $outputParent)) {
        New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
    }

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    $rowsRead = 0L
    $rowsWritten = 0L
    $duplicatesSkipped = 0L
    $shortRowsSkipped = 0L

    $parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($ResolvedInputPath)
    $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
    $parser.SetDelimiters($Delimiter)
    $parser.HasFieldsEnclosedInQuotes = $true
    $parser.TrimWhiteSpace = $false

    $writer = [System.IO.StreamWriter]::new($ResolvedOutputPath, $false, $utf8NoBom)

    try {
        if ($parser.EndOfData) {
            throw 'Input CSV is empty.'
        }

        $header = $parser.ReadFields()
        if ($header.Count -lt 4) {
            throw 'Input CSV must have at least 4 columns.'
        }

        $maxKeyColumn = ($KeyColumns | Measure-Object -Maximum).Maximum
        if ($maxKeyColumn -gt $header.Count) {
            throw "KeyColumns contains index $maxKeyColumn but CSV only has $($header.Count) columns."
        }

        $headerWithoutCol1 = if ($header.Count -eq 1) { @() } else { $header[1..($header.Count - 1)] }
        $writer.WriteLine((ConvertTo-CsvLine -Fields $headerWithoutCol1))

        while (-not $parser.EndOfData) {
            $fields = $parser.ReadFields()
            $rowsRead++

            $hasAnyContent = $false
            foreach ($field in $fields) {
                if (-not [string]::IsNullOrWhiteSpace([string]$field)) {
                    $hasAnyContent = $true
                    break
                }
            }

            if (-not $hasAnyContent) {
                $shortRowsSkipped++
                continue
            }

            if ($fields.Count -lt 4) {
                $shortRowsSkipped++
                continue
            }

            if ($fields.Count -lt $maxKeyColumn) {
                $shortRowsSkipped++
                continue
            }

            $keyValues = foreach ($col in $KeyColumns) {
                $fields[$col - 1]
            }

            $key = New-DedupeKey -Values $keyValues
            if ($seen.Add($key)) {
                $outFields = $fields[1..($fields.Count - 1)]
                $writer.WriteLine((ConvertTo-CsvLine -Fields $outFields))
                $rowsWritten++
            }
            else {
                $duplicatesSkipped++
            }

            if (($rowsRead % 100000) -eq 0) {
                Write-Host ("Processed {0:N0} rows in $([System.IO.Path]::GetFileName($ResolvedInputPath))..." -f $rowsRead)
            }
        }
    }
    finally {
        $writer.Dispose()
        $parser.Close()
    }

    Write-Host ("Done: $([System.IO.Path]::GetFileName($ResolvedInputPath))")
    Write-Host ("Rows read: {0:N0}" -f $rowsRead)
    Write-Host ("Rows written: {0:N0}" -f $rowsWritten)
    Write-Host ("Duplicates skipped: {0:N0}" -f $duplicatesSkipped)
    Write-Host ("Short rows skipped (<4 columns): {0:N0}" -f $shortRowsSkipped)
    Write-Host ("Output: $ResolvedOutputPath")
}

$inputFiles = @()

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $allCsvFiles = @(Get-ChildItem -LiteralPath $scriptDirectory -Filter '*.csv' -File)
    $inputFiles = @()

    foreach ($file in $allCsvFiles) {
        $isIncluded = $false
        foreach ($pattern in $IncludeFilePattern) {
            if ($file.Name -like $pattern) {
                $isIncluded = $true
                break
            }
        }

        if (-not $isIncluded) {
            continue
        }

        $isExcluded = $false
        if ($null -ne $ExcludeFilePattern) {
            foreach ($pattern in $ExcludeFilePattern) {
                if ($file.Name -like $pattern) {
                    $isExcluded = $true
                    break
                }
            }
        }

        if (-not $isExcluded) {
            $inputFiles += $file
        }
    }

    $inputFiles = @($inputFiles | Sort-Object Name)

    if ($inputFiles.Count -eq 0) {
        throw "No CSV files matched IncludeFilePattern/ExcludeFilePattern in script directory: $scriptDirectory"
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputPath) -and $inputFiles.Count -gt 1) {
        throw 'When processing multiple input files, do not pass OutputPath. The script writes one .deduped.csv file per input file.'
    }

    Write-Host ("Matched files: {0}" -f ($inputFiles.Name -join ', '))
}
else {
    if (-not (Test-Path -LiteralPath $InputPath)) {
        throw "Input CSV not found: $InputPath"
    }

    $inputFiles = @(Get-Item -LiteralPath $InputPath)
}

foreach ($inputFile in $inputFiles) {
    $resolvedInputPath = (Resolve-Path -LiteralPath $inputFile.FullName).Path
    $resolvedOutputPath = if (-not [string]::IsNullOrWhiteSpace($OutputPath) -and $inputFiles.Count -eq 1) {
        $OutputPath
    }
    else {
        Get-DefaultOutputPath -InputItem $inputFile
    }

    Invoke-DedupeCsvFile -ResolvedInputPath $resolvedInputPath -ResolvedOutputPath $resolvedOutputPath
}