param(
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$CacheRoot = (Join-Path $env:TEMP "futo-keyboard-emoji17-sources")
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$CacheRoot = [System.IO.Path]::GetFullPath($CacheRoot)

New-Item -ItemType Directory -Force -Path $CacheRoot | Out-Null

function Get-SparseRepository($Name, $Repository, $Tag, $SparsePaths) {
    $target = Join-Path $CacheRoot $Name
    if (-not (Test-Path -LiteralPath (Join-Path $target ".git"))) {
        git clone --depth 1 --filter=blob:none --sparse --branch $Tag $Repository $target
        if ($LASTEXITCODE -ne 0) { throw "Could not clone $Repository" }
    }
    git -C $target sparse-checkout set @SparsePaths
    if ($LASTEXITCODE -ne 0) { throw "Could not populate $Name" }
    return $target
}

$twemoji = Get-SparseRepository "twemoji" "https://github.com/jdecked/twemoji.git" `
    "v17.0.3" @("assets/svg")
$openmoji = Get-SparseRepository "openmoji" "https://github.com/hfg-gmuend/openmoji.git" `
    "17.0.0" @("color/svg", "data")
$noto = Get-SparseRepository "noto-emoji" "https://github.com/googlefonts/noto-emoji.git" `
    "v2.051" @("png/128")
$cldrLocales = @("en", "en-GB", "nl", "tr", "de", "fr", "es", "it", "pt", "pt-PT", `
    "sv", "no", "da", "fi", "pl", "cs", "ro", "sl", "hr", "lv", "lt")
$cldrPaths = @()
foreach ($locale in $cldrLocales) {
    $cldrPaths += "cldr-json/cldr-annotations-full/annotations/$locale"
    $cldrPaths += "cldr-json/cldr-annotations-derived-full/annotationsDerived/$locale"
}
$cldr = Get-SparseRepository "cldr-json" "https://github.com/unicode-org/cldr-json.git" `
    "48.2.0" $cldrPaths

$emojiTest = Join-Path $CacheRoot "emoji-test-17.0.txt"
Invoke-WebRequest -UseBasicParsing `
    -Uri "https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt" `
    -OutFile $emojiTest

$systemNode = Get-Command node -ErrorAction SilentlyContinue
if ($systemNode) {
    $node = $systemNode.Source
} else {
    throw "Node.js is required to generate the Emoji 17 dataset"
}
& $node (Join-Path $ProjectRoot "scripts/generate-full-emoji-set.js") `
    --emoji-test $emojiTest `
    --twemoji (Join-Path $twemoji "assets/svg") `
    --openmoji (Join-Path $openmoji "color/svg") `
    --openmoji-data (Join-Path $openmoji "data/openmoji.json") `
    --noto (Join-Path $noto "png/128") `
    --cldr-annotations (Join-Path $cldr "cldr-json/cldr-annotations-full/annotations") `
    --cldr-derived (Join-Path $cldr "cldr-json/cldr-annotations-derived-full/annotationsDerived")
if ($LASTEXITCODE -ne 0) { throw "Emoji generation failed" }
