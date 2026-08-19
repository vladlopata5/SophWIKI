param(
    [Parameter(Mandatory = $true)]
    [string]$VaultPath,

    [int]$ThroughScene = 0
)

$root = (Resolve-Path -LiteralPath $VaultPath).Path
$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File
$markdownFiles = $allFiles | Where-Object Extension -eq '.md'

$targets = @{}
foreach ($file in $allFiles) {
    $targets[$file.BaseName.ToLowerInvariant()] = $true
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    $withoutExtension = [IO.Path]::ChangeExtension($relative, $null).TrimEnd('.')
    $targets[$withoutExtension.ToLowerInvariant()] = $true
}

$broken = [Collections.Generic.List[object]]::new()
foreach ($file in $markdownFiles) {
    $text = Get-Content -Raw -LiteralPath $file.FullName
    foreach ($match in [regex]::Matches($text, '\[\[([^\]]+)\]\]')) {
        $rawTarget = $match.Groups[1].Value
        $target = (($rawTarget -split '\|')[0] -split '#')[0].Trim()
        if (-not $target) {
            continue
        }

        $key = $target.Replace('\', '/').ToLowerInvariant()
        $base = [IO.Path]::GetFileNameWithoutExtension($target).ToLowerInvariant()
        if (-not $targets.ContainsKey($key) -and -not $targets.ContainsKey($base)) {
            $broken.Add([pscustomobject]@{
                File = $file.FullName.Substring($root.Length + 1)
                Target = $target
            })
        }
    }
}

$sceneFiles = Get-ChildItem -LiteralPath (Join-Path $root '01 Хронология\Сцены') -File -Filter '*.md'
$sceneRecords = foreach ($file in $sceneFiles) {
    if ($file.BaseName -match '^(\d{3})') {
        [pscustomobject]@{ Number = [int]$matches[1]; Name = $file.Name }
    }
}

$duplicates = $sceneRecords | Group-Object Number | Where-Object Count -gt 1
$maximumScene = if ($ThroughScene -gt 0) {
    $ThroughScene
} elseif ($sceneRecords) {
    ($sceneRecords.Number | Measure-Object -Maximum).Maximum
} else {
    0
}

$present = @{}
foreach ($record in $sceneRecords) {
    $present[$record.Number] = $true
}

$missing = if ($maximumScene -gt 0) {
    1..$maximumScene | Where-Object { -not $present.ContainsKey($_) }
} else {
    @()
}

"FILES=$($allFiles.Count)"
"MARKDOWN=$($markdownFiles.Count)"
"SCENES=$($sceneRecords.Count)"
"CHECKED_THROUGH=$maximumScene"
"MISSING_COUNT=$(@($missing).Count)"
"DUPLICATE_COUNT=$(@($duplicates).Count)"
"BROKEN_LINK_COUNT=$($broken.Count)"

foreach ($number in $missing) {
    "MISSING_SCENE=$number"
}

foreach ($duplicate in $duplicates) {
    "DUPLICATE_SCENE=$($duplicate.Name): $($duplicate.Group.Name -join ' | ')"
}

foreach ($item in ($broken | Sort-Object Target, File -Unique)) {
    "BROKEN_LINK=$($item.File) -> $($item.Target)"
}

