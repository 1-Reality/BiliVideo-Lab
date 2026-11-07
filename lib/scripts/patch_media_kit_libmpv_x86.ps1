# 32 位 media-kit 的 libmpv 替换。只在 x86 工作流里执行；改的是 pub 缓存里 upstream 分支的 CMake。
# 新 CMake 非 ARM 一律下载 Lab 20260911 x86_64-v3，这里换成同一期的 i686（同一 release，下载地址由文件名拼出）。
# 这一期 FFmpeg 的 HTTPS 走 schannel，不链接 OpenSSL：之前 2026 年 i686 包一启动就报 OpenSSL lock != NULL，
# 只好退回 bggRGjQaUbCoE 20250930 的老包，这次看能不能摆脱。
$ErrorActionPreference = 'Stop'

$libmpvName = 'mpv-dev-i686-20260911-git-41f6a64.7z'
$libmpvSha256 = '4297a936b2678fc3a42854a7eddc419ac466090915c24f6b1f171fa435729b18'

$pubGit = Join-Path $env:LOCALAPPDATA 'Pub\Cache\git'
$rel = 'libs\windows\media_kit_libs_windows_video\windows\CMakeLists.txt'
# 缓存里可能还留着 native 分支的旧 checkout，只认带 Lab x86_64-v3 内核的那份
$dir = Get-ChildItem $pubGit -Directory | Where-Object {
    $file = Join-Path $_.FullName $rel
    (Test-Path $file) -and (Select-String -Path $file -SimpleMatch '367d978571cdfcdcf9f4beac658782f09e42f3eacd31bcd050be3e1bb472d90f' -Quiet)
} | Select-Object -Last 1
if (-not $dir) { throw "media_kit_libs_windows_video CMakeLists not found under $pubGit" }
$target = Join-Path $dir.FullName $rel

# 每个替换必须且只能命中一次
$text = [IO.File]::ReadAllText($target)
$replacements = @(
    @{ Pattern = 'set\(LIBMPV "mpv-dev-x86_64-v3-[^"]+"\)'; Replace = "set(LIBMPV `"$libmpvName`")" },
    @{ Pattern = 'set\(LIBMPV_SHA256 "367d978571cdfcdcf9f4beac658782f09e42f3eacd31bcd050be3e1bb472d90f"\)'; Replace = "set(LIBMPV_SHA256 `"$libmpvSha256`")" }
)
foreach ($r in $replacements) {
    $n = ([regex]::Matches($text, $r.Pattern)).Count
    if ($n -ne 1) { throw "expected exactly one match for $($r.Pattern), found $n in $target" }
    $text = [regex]::Replace($text, $r.Pattern, $r.Replace)
}
[IO.File]::WriteAllText($target, $text, [Text.UTF8Encoding]::new($false))
Write-Host "media-kit libmpv pinned to $libmpvName in $target"