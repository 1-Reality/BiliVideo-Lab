$ErrorActionPreference = "Stop"

$PubCacheDir = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { Join-Path $HOME ".pub-cache" }
$GitCacheDir = Join-Path $PubCacheDir "git"
$RelativePath = "media_kit_video/lib/src/video_controller/android_video_controller/real.dart"

if (-not (Test-Path $GitCacheDir)) {
    throw "pub git cache not found: $GitCacheDir"
}

# 缓存里可能还留着 native 分支的旧 checkout，只认 SurfaceProducer 版
$MediaKitDir = Get-ChildItem $GitCacheDir -Directory |
    Where-Object {
        $file = Join-Path $_.FullName $RelativePath
        (Test-Path $file) -and (Select-String -Path $file -SimpleMatch 'TextureUpdateCallback' -Quiet)
    } |
    Select-Object -Last 1

if (-not $MediaKitDir) {
    throw "media-kit checkout containing $RelativePath not found"
}

git -C $MediaKitDir.FullName reset --hard HEAD
if ($LASTEXITCODE -ne 0) {
    throw "failed to reset media-kit checkout"
}

$Target = Join-Path $MediaKitDir.FullName $RelativePath
$Text = [IO.File]::ReadAllText($Target)

# media-kit upstream 分支的 AndroidVideoController（SurfaceProducer 版）补两处：
# 1. 解码器实验室能临时换 vo：vo 先看 mpv 的 user-data，没设才用配置里的。
# 2. 切后台时 Flutter 回收表面，切回来是新的空表面；暂停中的 mpv 不会主动画一帧，
#    于是黑屏（PiliPlus#2994）。拿到新表面时若在暂停，原地精确跳转一次逼它重画。

$VoCount = ([regex]::Matches($Text, [regex]::Escape('configuration.vo'))).Count
if ($VoCount -ne 3) {
    throw "expected 3 configuration.vo in AndroidVideoController, found $VoCount"
}
$Text = $Text.Replace('configuration.vo', '_vo')

$OldField = @'
  late final VideoOutput videoOutput;
'@
$NewField = @'
  late final VideoOutput videoOutput;

  String? get _vo {
    final lab = player.getProperty('user-data/pilibro-decoder-lab-vo');
    return lab.isEmpty ? configuration.vo : lab;
  }
'@
$FieldCount = ([regex]::Matches($Text, [regex]::Escape($OldField))).Count
if ($FieldCount -ne 1) {
    throw "expected exactly one videoOutput field, found $FieldCount"
}
$Text = $Text.Replace($OldField, $NewField)

$OldSurface = @'
      _surface?.release();
      _surface = surface;
'@
$NewSurface = @'
      _surface?.release();
      _surface = surface;
      if (!player.state.playing) {
        player.command(['seek', '0', 'relative+exact']);
      }
'@
$SurfaceCount = ([regex]::Matches($Text, [regex]::Escape($OldSurface))).Count
if ($SurfaceCount -ne 1) {
    throw "expected exactly one surface assignment, found $SurfaceCount"
}
$Text = $Text.Replace($OldSurface, $NewSurface)

[IO.File]::WriteAllText($Target, $Text, [Text.UTF8Encoding]::new($false))
Write-Host "media-kit Android controller patched: $Target"

# libmpv 换成 1-Reality/libmpv-android-video-build 的 20261107：与上游同一份源码，
# 只多了 FFmpeg 的 MediaCodec 解码器支持 skip_frame=nonref（丢非参考帧补丁）
$Gradle = Join-Path $MediaKitDir.FullName 'libs/android/media_kit_libs_android_video/android/build.gradle'
$GradleText = [IO.File]::ReadAllText($Gradle)
$Jars = @(
    @{ Abi = 'arm64-v8a';   Old = 'f6e11847ae1b7f3c55706881067d34cd119b3ab96f320688dbafc896f14968b1'; New = '919c591cb8c523afcfec3fafe48b636e0b5e503e5ea3aa520d348e7d3523a0fb' },
    @{ Abi = 'armeabi-v7a'; Old = '5a4d42552aaf32967ec1e5dbfdd3ca335ef42bb6dcc631ca99f6827f528f22ab'; New = '30381cfd8ef0d38477271a0798038ce7d94a3593774bf0f56f897a9cb676bfc4' },
    @{ Abi = 'x86_64';      Old = '83a178be7505152d0627137c9f03a632d217b3eb63b0eef07e4f1b49931cfa83'; New = 'e91f369670ba609a4b0fc4ddcb91c3aea8920e89ef11082733aaf007a7803b5b' }
)
foreach ($j in $Jars) {
    $OldLine = "[`"url`": `"https://github.com/My-Responsitories/libmpv-android-video-build/releases/download/20260930/default-$($j.Abi).jar`", `"sha256`": `"$($j.Old)`", `"destination`": file(`"`$buildDir/20260930/default-$($j.Abi).jar`")]"
    $NewLine = "[`"url`": `"https://github.com/1-Reality/libmpv-android-video-build/releases/download/20261107/default-$($j.Abi).jar`", `"sha256`": `"$($j.New)`", `"destination`": file(`"`$buildDir/20261107/default-$($j.Abi).jar`")]"
    $n = ([regex]::Matches($GradleText, [regex]::Escape($OldLine))).Count
    if ($n -ne 1) { throw "expected exactly one libmpv jar line for $($j.Abi), found $n" }
    $GradleText = $GradleText.Replace($OldLine, $NewLine)
}
[IO.File]::WriteAllText($Gradle, $GradleText, [Text.UTF8Encoding]::new($false))
Write-Host "libmpv jars -> 1-Reality 20261107: $Gradle"