# Reuse the keyboard glyph used for FUTO in SaneFish, with a readable icon tile.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$directory = Join-Path $root 'assets\icons'
$symbol = [Drawing.Image]::FromFile((Join-Path $directory 'keyboard-symbol.png'))
$bitmap = New-Object Drawing.Bitmap 128,128
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([Drawing.Color]::FromArgb(255,0,121,133))
$graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.DrawImage($symbol,16,16,96,96)
$graphics.Dispose()
$symbol.Dispose()
$bitmap.Save((Join-Path $directory 'futo-keyboard-sailfish.png'), [Drawing.Imaging.ImageFormat]::Png)
# RPM's embedded package-icon metadata uses XPM. Quantize this same tile to
# a small fixed palette; paths and image-editor metadata are not included.
$lines = [Collections.Generic.List[string]]::new()
$lines.Add('/* XPM */')
$lines.Add('static const char *keyboard_icon[] = {')
$lines.Add('"128 128 16 1",')
$palette = '0123456789abcdef'
for ($index=0; $index -lt 16; $index++) {
    $red = [int][Math]::Round(255*$index/15)
    $green = [int][Math]::Round(121+(255-121)*$index/15)
    $blue = [int][Math]::Round(133+(255-133)*$index/15)
    $lines.Add(('"{0} c #{1:x2}{2:x2}{3:x2}",' -f $palette[$index],$red,$green,$blue))
}
for ($y=0; $y -lt 128; $y++) {
    $row = [Text.StringBuilder]::new(128)
    for ($x=0; $x -lt 128; $x++) {
        $index = [Math]::Min(15,[int][Math]::Round($bitmap.GetPixel($x,$y).R*15/255))
        [void]$row.Append($palette[$index])
    }
    $lines.Add(('"{0}"{1}' -f $row.ToString(),$(if ($y -lt 127) { ',' } else { '' })))
}
$lines.Add('};')
[IO.File]::WriteAllLines((Join-Path $directory 'futo-keyboard-sailfish.xpm'),$lines,[Text.UTF8Encoding]::new($false))
$bitmap.Dispose()
