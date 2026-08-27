param(
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = "Stop"

$emojiCodes = @(
    "1f44d", "1f44e", "1f44f", "1f64f", "1f4aa",
    "1f44b", "1f91d", "1f44c", "270c", "1f91e"
)
$toneCodes = @("1f3fb", "1f3fc", "1f3fd", "1f3fe", "1f3ff")

$sources = @{
    twemoji = {
        param($code, $tone)
        "https://raw.githubusercontent.com/jdecked/twemoji/50c7abfe6813680455781862f7b34305cd1eb9f5/assets/svg/$code-$tone.svg"
    }
    openmoji = {
        param($code, $tone)
        $name = ("$code-$tone").ToUpperInvariant()
        "https://raw.githubusercontent.com/hfg-gmuend/openmoji/f9fc506a3f913be9897ab0181d611d4c910a4104/color/svg/$name.svg"
    }
    noto = {
        param($code, $tone)
        $name = ("${code}_${tone}").ToLowerInvariant()
        "https://raw.githubusercontent.com/googlefonts/noto-emoji/8998f5dd683424a73e2314a8c1f1e359c19e8742/svg/emoji_u$name.svg"
    }
}

foreach ($style in $sources.Keys | Sort-Object) {
    $styleDirectory = Join-Path $ProjectRoot "emoji/$style"
    New-Item -ItemType Directory -Force -Path $styleDirectory | Out-Null
    foreach ($code in $emojiCodes) {
        foreach ($tone in $toneCodes) {
            $target = Join-Path $styleDirectory "$code-$tone.svg"
            $uri = & $sources[$style] $code $tone
            Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $target
            if ((Get-Item -LiteralPath $target).Length -eq 0) {
                throw "Downloaded an empty emoji asset: $uri"
            }
        }
    }
}

Write-Host "Fetched 150 pinned skin-tone SVG assets."
