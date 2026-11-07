$ErrorActionPreference = 'Stop'
# Windows 改用 My-Responsitories/media-kit upstream 分支的原生 D3D11 渲染器（mpv 的 DXGI 渲染接口，不走 ANGLE）。
# 只把这两个 windows 目录盖到 pub 缓存的 media-kit 上，其他平台仍是 pubspec 里的 native 分支。
# 与 native 分支的 Dart 层通信一致（Create / SetSize / Dispose，VideoOutput.Resize 回传）；
# 渲染器自带 ADVANCED_CONTROL 与按新帧渲染，原来的解码实验补丁不再需要。
# libmpv 由新 CMake 下载 Lab 20260911 x86_64-v3（带 DXGI 渲染接口的补丁版），便携版和 32 位在各自脚本里换。
$Commit = '1ea01b6fc5f4a4762bd99a018e858a7d155d6fca'
$Dirs = 'media_kit_video/windows', 'libs/windows/media_kit_libs_windows_video/windows'

$GitCacheDir = Join-Path $env:LOCALAPPDATA 'Pub/Cache/git'
$Targets = Get-ChildItem $GitCacheDir -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'media_kit_video/windows/video_output.cc') }
if (-not $Targets) { throw "media-kit checkout not found under $GitCacheDir" }

$Src = Join-Path $env:RUNNER_TEMP 'media-kit-d3d11'
git init -q $Src
git -C $Src fetch -q --depth 1 https://github.com/My-Responsitories/media-kit.git $Commit
if ($LASTEXITCODE -ne 0) { throw "fetch media-kit $Commit failed" }
git -C $Src checkout -q FETCH_HEAD

foreach ($t in $Targets) {
    foreach ($d in $Dirs) {
        $dst = Join-Path $t.FullName $d
        Remove-Item $dst -Recurse -Force
        Copy-Item (Join-Path $Src $d) $dst -Recurse
    }
    Write-Host "media-kit Windows D3D11 renderer ($Commit) -> $($t.FullName)"
}