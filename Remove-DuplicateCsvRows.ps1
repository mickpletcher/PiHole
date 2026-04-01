param(
    [string]$InputPath,

    [string]$OutputPath,

    [string]$Delimiter = ',',

    [int[]]$KeyColumns = @(2, 3, 4)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $csvFiles = @(Get-ChildItem -LiteralPath $scriptDirectory -Filter '*.csv' -File | Sort-Object Name)
    if ($csvFiles.Count -eq 0) {
        throw "No CSV file found in script directory: $scriptDirectory"
    }

    if ($csvFiles.Count -gt 1) {
        $names = ($csvFiles.Name -join ', ')
        throw "Multiple CSV files found in script directory. Specify -InputPath explicitly. Files: $names"
    }

    $InputPath = $csvFiles[0].FullName
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $inputItem = Get-Item -LiteralPath $InputPath
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($inputItem.Name)
    $OutputPath = Join-Path $inputItem.DirectoryName ($baseName + '.deduped.csv')
}

function ConvertTo-CsvLine {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Fields
    )

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

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input CSV not found: $InputPath"
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

Add-Type -AssemblyName Microsoft.VisualBasic

$inputResolved = (Resolve-Path -LiteralPath $InputPath).Path
$outputParent = Split-Path -Path $OutputPath -Parent
if ($outputParent -and -not (Test-Path -LiteralPath $outputParent)) {
    New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

$rowsRead = 0L
$rowsWritten = 0L
$duplicatesSkipped = 0L
$shortRowsSkipped = 0L

$parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($inputResolved)
$parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
$parser.SetDelimiters($Delimiter)
$parser.HasFieldsEnclosedInQuotes = $true
$parser.TrimWhiteSpace = $false

$writer = [System.IO.StreamWriter]::new($OutputPath, $false, $utf8NoBom)

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
            Write-Host ("Processed {0:N0} rows..." -f $rowsRead)
        }
    }
}
finally {
    $writer.Dispose()
    $parser.Close()
}

Write-Host ("Done. Rows read: {0:N0}" -f $rowsRead)
Write-Host ("Rows written: {0:N0}" -f $rowsWritten)
Write-Host ("Duplicates skipped: {0:N0}" -f $duplicatesSkipped)
Write-Host ("Short rows skipped (<4 columns): {0:N0}" -f $shortRowsSkipped)