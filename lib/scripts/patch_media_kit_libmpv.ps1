$ErrorActionPreference = "Stop"

# Pin the Windows libmpv build that contains mpv 1d1568614
# ("hwdec_d3d11egl: fix EGL_EXT_device_query availability check").
#
# media_kit renders through libmpv's OpenGL API on ANGLE. Without that fix the
# d3d11va interop is silently disabled and every frame goes GPU -> RAM -> GPU
# (hwdec-current shows d3d11va-copy). Releases 2.2.9 shipped this build; 2.3.0
# reverted to the older one and the copy came back.
$OldName = "mpv-dev-x86_64-20260607-git-43b14a4.7z"
$NewName = "mpv-dev-x86_64-20260819-git-e7191f2a65.7z"
$OldTag = "20260607"
$NewTag = "20260819"
$OldMd5 = "b84900bbc6fcb995ca6a24f62bee671f"
$NewMd5 = "84f1034c7a1d8cdcd520d359fe99d228"

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
    Write-Host "libmpv already pinned to $NewName: $Target"
    return
}

$Replacements = @(
    @{ Old = "set(LIBMPV `"$OldName`")"; New = "set(LIBMPV `"$NewName`")" },
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
Write-Host "media-kit Windows libmpv pinned to $NewName: $Target"
