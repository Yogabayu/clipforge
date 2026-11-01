param([switch]$DebugApk)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$mode = if ($DebugApk) { 'debug' } else { 'release' }
Push-Location $projectRoot
try {
    # Always replace integration-test entrypoints before delivering an APK.
    & flutter build apk "--$mode" --target lib/main.dart --target-platform android-arm64
    if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }
    $apk = Join-Path $projectRoot "build/app/outputs/flutter-apk/app-$mode.apk"
    & python (Join-Path $PSScriptRoot 'verify_apk.py') $apk
    if ($LASTEXITCODE -ne 0) { throw 'APK delivery verification failed.' }
    $versionMatch = Select-String -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Pattern '^version:\s*([0-9.]+)\+'
    if (-not $versionMatch) { throw 'APK version missing from pubspec.yaml.' }
    $version = $versionMatch.Matches[0].Groups[1].Value
    $downloadSetting = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
    $downloadDirectory = if ($downloadSetting) { [Environment]::ExpandEnvironmentVariables($downloadSetting) } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads' }
    New-Item -ItemType Directory -Force -Path $downloadDirectory | Out-Null
    $suffix = if ($DebugApk) { '-debug' } else { '' }
    $downloadApk = Join-Path $downloadDirectory "ClipForge-$version-arm64$suffix.apk"
    Copy-Item -LiteralPath $apk -Destination $downloadApk -Force
    if ((Get-FileHash -LiteralPath $apk).Hash -ne (Get-FileHash -LiteralPath $downloadApk).Hash) { throw 'Downloads APK checksum mismatch.' }
    Write-Output "Standalone APK: $apk"
    Write-Output "Downloads copy: $downloadApk"
} finally {
    Pop-Location
}
