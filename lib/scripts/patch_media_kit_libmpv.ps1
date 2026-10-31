$ErrorActionPreference = "Stop"

# Pin the Windows libmpv to shinchiro/mpv-winbuild-cmake's x86_64-v3 build.
#
# The previous package (bggRGjQaUbCoE 20260819) is built with --disable-filters,
# so the loudnorm and dynaudnorm audio filters used by volume normalization are
# missing and filter setup fails. The shinchiro build is the full build and has
# both filters.
#
# It also contains mpv 1d1568614 ("hwdec_d3d11egl: fix EGL_EXT_device_query
# availability check"), verified as an ancestor of e471496c56. media_kit renders
# through libmpv's OpenGL API on ANGLE; without that fix the d3d11va interop is
# silently disabled and every frame goes GPU -> RAM -> GPU (hwdec-current shows
# d3d11va-copy). This build is also the test for issue #42 (green blocks with
# d3d11va on Intel N100); whether it fixes that is still to be verified.
#
# v3 requires AVX2. CPUs without AVX2 will crash when libmpv is loaded. This is
# intentional.
$OldName = "mpv-dev-x86_64-20260607-git-43b14a4.7z"
$NewName = "mpv-dev-x86_64-v3-20261021-git-e471496c56.7z"
$OldTag = "20260607"
$NewTag = "20261021"
$OldMd5 = "b84900bbc6fcb995ca6a24f62bee671f"
$NewMd5 = "ba0553957a3fd7de5a3c75dc60fafa06"

$PubCacheDir = "$env:LOCALAPPDATA/Pub/Cache"
$GitCacheDir = Join-Path $PubCacheDir "git"
$RelativePath = "libs/windows/media_kit_libs_windows_video/windows/CMakeLists.txt"

if (-not (Test-Path $GitCacheDir)) {
    throw "pub git cache not found: $GitCacheDir"
}

$MediaKitDir = Get-ChildItem $GitCacheDir -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName $RelativePath) } |
    Select-Object -Last 1

if (-not $MediaKitDir) {
    throw "media-kit checkout containing $RelativePath not found"
}

$Target = Join-Path $MediaKitDir.FullName $RelativePath
$Text = [IO.File]::ReadAllText($Target)

if ($Text.Contains($NewName)) {
    Write-Host "libmpv already pinned to ${NewName}: $Target"
    return
}

$Replacements = @(
    @{ Old = "set(LIBMPV `"$OldName`")"; New = "set(LIBMPV `"$NewName`")" },
    @{
        Old = "github.com/bggRGjQaUbCoE/mpv-winbuild-cmake/"
        New = "github.com/shinchiro/mpv-winbuild-cmake/"
    },
    @{
        Old = "releases/download/$OldTag/"
        New = "releases/download/$NewTag/"
    },
    @{ Old = "set(LIBMPV_MD5 `"$OldMd5`")"; New = "set(LIBMPV_MD5 `"$NewMd5`")" }
)

foreach ($r in $Replacements) {
    $count = ([regex]::Matches($Text, [regex]::Escape($r.Old))).Count
    if ($count -ne 1) {
        throw "expected exactly one '$($r.Old)' in $Target, found $count"
    }
    $Text = $Text.Replace($r.Old, $r.New)
}

[IO.File]::WriteAllText($Target, $Text, [Text.UTF8Encoding]::new($false))
Write-Host "media-kit Windows libmpv pinned to ${NewName}: $Target"
