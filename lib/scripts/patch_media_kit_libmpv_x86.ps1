# 32 位 media-kit 的 Windows 库替换。只在 x86 工作流里执行；改的是 pub 缓存里的 CMake 与 CMake 构建目录。
# 1) libmpv：用 bggRGjQaUbCoE 的 20250930 i686 包（匿名直链可下，MD5 校验）。2026 年的 i686 包（含 shinchiro 官方）一启动就报
#    OpenSSL lock != NULL，本地文件和断网也一样；0930 在 Win10 和虚拟机里都能正常播放。
# 2) ANGLE：用本仓库 angle-win-x86-<版本> 的包（gh 下载，匿名直链不可用）；MD5 在这里现算写入 CMake。
# 3) 捆绑清单只保留 libEGL.dll、libGLESv2.dll（d3dcompiler_47 用系统自带的 SysWOW64 版本，其余为可选依赖，我们包里没有）。
# 4) 把两个压缩包预先放进 CMake 构建目录：download_and_verify 发现本地已有且 MD5 一致就跳过下载。
$ErrorActionPreference = 'Stop'

$root = (Get-Location).Path
$ver = (Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^\s*flutter:\s*([0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1).Matches.Groups[1].Value
$angleTag = "angle-win-x86-$ver"
$angleAsset = "angle-win-x86-$ver.7z"
$angleUrl = "https://github.com/$env:GITHUB_REPOSITORY/releases/download/$angleTag/$angleAsset"

$libmpvName = 'mpv-dev-i686-20250930-git-05656cd.7z'
$libmpvUrl = "https://github.com/bggRGjQaUbCoE/mpv-winbuild-cmake/releases/download/20250930/$libmpvName"
$libmpvMd5 = '909dc64c76b3f5c160774bb0b96bae30'

# --- 找 pub 缓存里的 media_kit_libs_windows_video CMakeLists（与 patch_media_kit_libmpv.ps1 同一套方法）
$pubGit = Join-Path $env:LOCALAPPDATA 'Pub\Cache\git'
$rel = 'libs\windows\media_kit_libs_windows_video\windows\CMakeLists.txt'
$dir = Get-ChildItem $pubGit -Directory | Where-Object { Test-Path (Join-Path $_.FullName $rel) } | Select-Object -Last 1
if (-not $dir) { throw "media_kit_libs_windows_video CMakeLists not found under $pubGit" }
$target = Join-Path $dir.FullName $rel

# --- 预放压缩包到 CMake 构建目录（插件子项目的 binary dir 是 build32\plugins\<插件名>）
$buildDir = Join-Path $root 'build32\plugins\media_kit_libs_windows_video'
New-Item -ItemType Directory -Force $buildDir | Out-Null
Invoke-WebRequest -Uri $libmpvUrl -OutFile (Join-Path $buildDir $libmpvName)
$mpvActual = (Get-FileHash (Join-Path $buildDir $libmpvName) -Algorithm MD5).Hash.ToLower()
if ($mpvActual -ne $libmpvMd5) { throw "libmpv md5 mismatch: $mpvActual" }

gh release download $angleTag -R $env:GITHUB_REPOSITORY -p $angleAsset -D $buildDir
if ($LASTEXITCODE -ne 0) { throw "could not download $angleAsset from $angleTag" }
Move-Item (Join-Path $buildDir $angleAsset) (Join-Path $buildDir 'ANGLE.7z') -Force
$angleMd5 = (Get-FileHash (Join-Path $buildDir 'ANGLE.7z') -Algorithm MD5).Hash.ToLower()
Write-Host "libmpv md5=$mpvActual ANGLE md5=$angleMd5"

# --- 改 CMakeLists（每个替换必须且只能命中一次）
$text = [IO.File]::ReadAllText($target)
$replacements = @(
    @{ Pattern = 'set\(LIBMPV "[^"]+"\)'; Replace = "set(LIBMPV `"$libmpvName`")" },
    @{ Pattern = 'set\(LIBMPV_URL "[^"]+"\)'; Replace = "set(LIBMPV_URL `"$libmpvUrl`")" },
    @{ Pattern = 'set\(LIBMPV_MD5 "[^"]+"\)'; Replace = "set(LIBMPV_MD5 `"$libmpvMd5`")" },
    @{ Pattern = 'set\(ANGLE_URL "[^"]+"\)'; Replace = "set(ANGLE_URL `"$angleUrl`")" },
    @{ Pattern = 'set\(ANGLE_MD5 "[^"]+"\)'; Replace = "set(ANGLE_MD5 `"$angleMd5`")" }
)
foreach ($r in $replacements) {
    $n = ([regex]::Matches($text, $r.Pattern)).Count
    if ($n -ne 1) { throw "expected exactly one match for $($r.Pattern), found $n in $target" }
    $text = [regex]::Replace($text, $r.Pattern, $r.Replace)
}
# 捆绑清单：去掉 d3dcompiler_47、vk_swiftshader、vulkan-1、zlib 三类行（系统自带或包里没有）
$before = $text
$text = [regex]::Replace($text, '(?m)^\s*"\$\{ANGLE_SRC\}/(d3dcompiler_47|vk_swiftshader|vulkan-1|zlib)\.dll"\r?\n', '')
if ($text -eq $before) { throw "bundled ANGLE list did not change in $target" }

[IO.File]::WriteAllText($target, $text, [Text.UTF8Encoding]::new($false))
Write-Host "media-kit libs pinned for x86 in $target"
