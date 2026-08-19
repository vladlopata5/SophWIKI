param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [TimeSpan]$Start,

    [Parameter(Mandatory = $true)]
    [TimeSpan]$End
)

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path

if ($End -lt $Start) {
    throw 'End must be greater than or equal to Start.'
}

function Convert-SrtTimestamp {
    param([string]$Value)
    return [TimeSpan]::Parse($Value.Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture)
}

$raw = Get-Content -Raw -LiteralPath $resolvedPath
$blocks = [regex]::Split($raw.Trim(), '(?:\r?\n){2,}')
$matches = 0

foreach ($block in $blocks) {
    $timeMatch = [regex]::Match(
        $block,
        '(?m)^(?<start>\d{2}:\d{2}:\d{2},\d{3})\s+-->\s+(?<end>\d{2}:\d{2}:\d{2},\d{3})'
    )

    if (-not $timeMatch.Success) {
        continue
    }

    $cueStart = Convert-SrtTimestamp $timeMatch.Groups['start'].Value
    $cueEnd = Convert-SrtTimestamp $timeMatch.Groups['end'].Value

    if ($cueEnd -ge $Start -and $cueStart -le $End) {
        $block
        ''
        $matches++
    }
}

if ($matches -eq 0) {
    Write-Warning 'No subtitle blocks overlap the requested range.'
}

