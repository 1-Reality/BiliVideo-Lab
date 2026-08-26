$ErrorActionPreference = "Stop"

$PubCacheDir = "$env:LOCALAPPDATA/Pub/Cache"
$GitCacheDir = Join-Path $PubCacheDir "git"
$Patch = Join-Path $env:GITHUB_WORKSPACE "lib/scripts/media_kit_advanced_control.patch"

if (-not (Test-Path $GitCacheDir)) {
    throw "pub git cache not found: $GitCacheDir"
}

$MediaKitDir = Get-ChildItem $GitCacheDir -Directory |
    Where-Object {
        Test-Path (Join-Path $_.FullName "media_kit_video/windows/video_output.cc")
    } |
    Select-Object -Last 1

if (-not $MediaKitDir) {
    throw "media-kit checkout containing media_kit_video/windows/video_output.cc not found"
}

Write-Host "media-kit decoder-lab checkout: $($MediaKitDir.FullName)"
Push-Location $MediaKitDir.FullName
try {
    git apply --check $Patch
    if ($LASTEXITCODE -ne 0) {
        throw "media-kit decoder-lab patch preflight failed"
    }
    git apply $Patch
    if ($LASTEXITCODE -ne 0) {
        throw "media-kit decoder-lab patch failed"
    }
    Write-Host "media-kit advanced-control decoder-lab patch applied"
} finally {
    Pop-Location
}
