param(
    [string]$ToolRoot = $env:FUTO_ANDROID_TOOLS,
    [string]$SigningDirectory = (Join-Path $env:LOCALAPPDATA 'FUTOKeyboard\signing')
)
$ErrorActionPreference = 'Stop'
if (-not $ToolRoot) { throw 'Pass -ToolRoot or set FUTO_ANDROID_TOOLS.' }
$repository = Split-Path -Parent $PSScriptRoot
$jdk = Join-Path $ToolRoot 'jdk17'
$gradle = Join-Path $ToolRoot 'gradle\gradle-8.7\bin\gradle.bat'
$sdk = Join-Path $ToolRoot 'android-sdk'
$keytool = Join-Path $jdk 'bin\keytool.exe'
$keystore = Join-Path $SigningDirectory 'futo-autofill.p12'
$passwordFile = Join-Path $SigningDirectory 'futo-autofill.password'
if (-not (Test-Path -LiteralPath $keytool) -or -not (Test-Path -LiteralPath $gradle)) {
    throw 'Android build tools are missing.'
}
if ((Test-Path -LiteralPath $keystore) -xor (Test-Path -LiteralPath $passwordFile)) {
    throw 'Restore both signing files from backup before rebuilding.'
}
function Protect-SigningFile([string]$Path, [bool]$Directory) {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $access = if ($Directory) { ':(OI)(CI)F' } else { ':F' }
    & icacls.exe $Path /grant:r "*${sid}${access}" "*S-1-5-18${access}" "*S-1-5-32-544${access}" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not protect Android signing files.' }
    & icacls.exe $Path /inheritance:r | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not protect Android signing files.' }
}
New-Item -ItemType Directory -Path $SigningDirectory -Force | Out-Null
Protect-SigningFile $SigningDirectory $true
if (-not (Test-Path -LiteralPath $keystore)) {
    $bytes = New-Object byte[] 48
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $password = [Convert]::ToBase64String($bytes)
    [Array]::Clear($bytes, 0, $bytes.Length)
    [IO.File]::WriteAllText($passwordFile, $password, [Text.Encoding]::ASCII)
    Protect-SigningFile $passwordFile $false
    $env:FUTO_ANDROID_RELEASE_PASSWORD = $password
    try {
        & $keytool -genkeypair -noprompt -storetype PKCS12 -keystore $keystore -alias futo-autofill-release -keyalg RSA -keysize 4096 -validity 10000 -dname 'CN=FUTO Autofill, O=HtheB' -storepass:env FUTO_ANDROID_RELEASE_PASSWORD -keypass:env FUTO_ANDROID_RELEASE_PASSWORD
        if ($LASTEXITCODE -ne 0) { throw 'Could not create Android signing key.' }
    } finally { Remove-Item Env:FUTO_ANDROID_RELEASE_PASSWORD -ErrorAction SilentlyContinue }
} else { $password = [IO.File]::ReadAllText($passwordFile).Trim() }
Protect-SigningFile $keystore $false
Protect-SigningFile $passwordFile $false
$env:JAVA_HOME = $jdk
$env:ANDROID_HOME = $sdk
$env:FUTO_ANDROID_RELEASE_KEYSTORE = $keystore
$env:FUTO_ANDROID_RELEASE_PASSWORD = $password
try {
    Push-Location (Join-Path $repository 'android-companion')
    try {
        & $gradle :app:assembleRelease --offline --no-daemon
        if ($LASTEXITCODE -ne 0) { throw 'Android companion build failed.' }
    } finally { Pop-Location }
    $apk = Join-Path $repository 'android-companion\app\build\outputs\apk\release\app-release.apk'
    $output = Join-Path $repository 'build\android'
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    Copy-Item -LiteralPath $apk -Destination (Join-Path $output 'FutoAutofill.apk')
    Write-Output 'Signed FutoAutofill.apk is ready in build/android.'
} finally {
    Remove-Item Env:FUTO_ANDROID_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:FUTO_ANDROID_RELEASE_KEYSTORE -ErrorAction SilentlyContinue
    $password = $null
}
