param(
    [Parameter(Mandatory = $true)]
    [string]$StagePath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationPath
)

$stage = (Resolve-Path -LiteralPath $StagePath).Path
$destination = (Resolve-Path -LiteralPath $DestinationPath).Path
$stageFiles = Get-ChildItem -LiteralPath $stage -Recurse -File
$stageRelative = @{}
$differences = [Collections.Generic.List[object]]::new()

foreach ($file in $stageFiles) {
    $relative = $file.FullName.Substring($stage.Length + 1)
    $stageRelative[$relative.ToLowerInvariant()] = $true
    $target = Join-Path $destination $relative

    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        $differences.Add([pscustomobject]@{ State = 'NEW'; Path = $relative })
        continue
    }

    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        $differences.Add([pscustomobject]@{ State = 'CHANGED'; Path = $relative })
    }
}

$destinationFiles = Get-ChildItem -LiteralPath $destination -Recurse -File | Where-Object {
    $_.FullName -notlike (Join-Path $destination '.obsidian*')
}

foreach ($file in $destinationFiles) {
    $relative = $file.FullName.Substring($destination.Length + 1)
    if (-not $stageRelative.ContainsKey($relative.ToLowerInvariant())) {
        $differences.Add([pscustomobject]@{ State = 'EXTRA'; Path = $relative })
    }
}

foreach ($item in ($differences | Sort-Object State, Path)) {
    "$($item.State)=$($item.Path)"
}

"DIFFERENCE_COUNT=$($differences.Count)"
"STAGE_FILE_COUNT=$($stageFiles.Count)"
"DESTINATION_CONTENT_FILE_COUNT=$($destinationFiles.Count)"

