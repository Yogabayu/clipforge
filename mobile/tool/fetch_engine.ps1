param()
$ErrorActionPreference = 'Stop'
$engineVersion = '2026.10.26'
$expectedHash = 'e51e69e89489f199530f13d32a4342da3ddb2cf34842f364603a066db05afbf3'
$projectRoot = Split-Path $PSScriptRoot
$destination = Join-Path $projectRoot "android\app\src\main\assets\yt-dlp-$engineVersion"
$temporaryFile = "$destination.pending"
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest "https://github.com/yt-dlp/yt-dlp/releases/download/$engineVersion/yt-dlp" -OutFile $temporaryFile
    if ((Get-FileHash -LiteralPath $temporaryFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
        throw 'yt-dlp checksum mismatch; existing bundled engine unchanged.'
    }
    Move-Item -LiteralPath $temporaryFile -Destination $destination -Force
    Write-Output "Verified yt-dlp $engineVersion ($expectedHash)"
} finally {
    if (Test-Path -LiteralPath $temporaryFile) { Remove-Item -LiteralPath $temporaryFile }
}
