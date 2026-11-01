param(
    [Parameter(Mandatory = $true)][string]$VideoUrl,
    [string]$DeviceId,
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk"
)
$ErrorActionPreference = 'Stop'
$adbPath = Join-Path $AndroidSdk 'platform-tools\adb.exe'
$projectRoot = Split-Path $PSScriptRoot
if (-not $DeviceId) {
    $devices = @(& $adbPath devices | Select-String '^\S+\s+device$' | ForEach-Object { ($_.Line -split '\s+')[0] })
    if ($devices.Count -ne 1) { throw 'Connect exactly one authorized USB device, or pass -DeviceId.' }
    $DeviceId = $devices[0]
}
& $adbPath -s $DeviceId shell getprop ro.product.model
& $adbPath -s $DeviceId shell getprop ro.build.version.release
$abiList = & $adbPath -s $DeviceId shell getprop ro.product.cpu.abilist
if ($abiList -notmatch 'arm64-v8a') { throw 'This APK requires ARM64 Android.' }
Push-Location $projectRoot
try {
    & flutter test integration_test/downloader_test.dart --no-uninstall -d $DeviceId "--dart-define=TEST_YOUTUBE_URL=$VideoUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Physical-device smoke test failed; inspect app diagnostics and test output.' }
} finally { Pop-Location }
