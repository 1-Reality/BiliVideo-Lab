$ErrorActionPreference = "Stop"

$PubCacheDir = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { Join-Path $HOME ".pub-cache" }
$GitCacheDir = Join-Path $PubCacheDir "git"
$RelativePath = "media_kit_video/lib/src/video_controller/android_video_controller/real.dart"

if (-not (Test-Path $GitCacheDir)) {
    throw "pub git cache not found: $GitCacheDir"
}

$MediaKitDir = Get-ChildItem $GitCacheDir -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName $RelativePath) } |
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

$OldGetter = @'
  /// --vo
  String get vo => configuration.vo ?? 'gpu';
'@
$NewGetter = @'
  String? _decoderLabProperty(String property) {
    final name = property.toNativeUtf8();
    final value = NativePlayer.mpv.mpv_get_property_string(player.ctx, name);
    calloc.free(name.cast());
    if (value.address == 0) return null;
    final result = value.toDartString();
    NativePlayer.mpv.mpv_free(value.cast());
    return result.isEmpty ? null : result;
  }

  /// --vo
  String get vo =>
      _decoderLabProperty('user-data/pilibro-decoder-lab-vo') ??
      configuration.vo ??
      'gpu';

  String? get _decoderLabHwdec =>
      _decoderLabProperty('user-data/pilibro-decoder-lab-hwdec');

  String? get _decoderLabHwdecFallback =>
      _decoderLabProperty('user-data/pilibro-decoder-lab-hwdec-fallback');
'@

$GetterCount = ([regex]::Matches($Text, [regex]::Escape($OldGetter))).Count
if ($GetterCount -ne 1) {
    throw "expected exactly one AndroidVideoController --vo getter, found $GetterCount"
}
$Text = $Text.Replace($OldGetter, $NewGetter)

$OldLoad = @'
        try {
          // ----------------------------------------------
          if (!androidAttachSurfaceAfterVideoParameters) {
            player.setOption('wid', _wid.toString());
            player.setOption('vo', vo);
          }
          // ----------------------------------------------
        } catch (exception, stacktrace) {
'@
$NewLoad = @'
        try {
          // Decoder-lab hwdec must be visible during on_load, before decoder
          // probing starts. Applying only VO here can make mediacodec_embed
          // initialize correctly while hwdec has already fallen back to SW.
          final labHwdec = _decoderLabHwdec;
          final labFallback = _decoderLabHwdecFallback;
          if (labHwdec != null) {
            player.setOption('hwdec', labHwdec);
          }
          if (labFallback != null) {
            player.setOption('hwdec-software-fallback', labFallback);
          }
          // ----------------------------------------------
          if (!androidAttachSurfaceAfterVideoParameters) {
            player.setOption('wid', _wid.toString());
            player.setOption('vo', vo);
          }
          // ----------------------------------------------
        } catch (exception, stacktrace) {
'@

$LoadCount = ([regex]::Matches($Text, [regex]::Escape($OldLoad))).Count
if ($LoadCount -ne 1) {
    throw "expected exactly one AndroidVideoController on_load VO block, found $LoadCount"
}
$Text = $Text.Replace($OldLoad, $NewLoad)

$OldField = @'
  String? _current;
'@
$NewField = @'
  String? _current;
  String? _surfaceVo;
'@
$FieldCount = ([regex]::Matches($Text, [regex]::Escape($OldField))).Count
if ($FieldCount -ne 1) {
    throw "expected exactly one AndroidVideoController _current field, found $FieldCount"
}
$Text = $Text.Replace($OldField, $NewField)

$OldSurface = @'
        if (_current != current) {
          _current = current;
'@
$NewSurface = @'
        // A Surface that already served another VO type must not be reused:
        // native_window_api_connect fails with -22 on the second connection.
        // Reopening the same path with a different decoder-lab vo hits this.
        final surfaceVo = vo;
        if (_current != current || _surfaceVo != surfaceVo) {
          _current = current;
          _surfaceVo = surfaceVo;
'@
$SurfaceCount = ([regex]::Matches($Text, [regex]::Escape($OldSurface))).Count
if ($SurfaceCount -ne 1) {
    throw "expected exactly one AndroidVideoController Surface block, found $SurfaceCount"
}
$Text = $Text.Replace($OldSurface, $NewSurface)

[IO.File]::WriteAllText($Target, $Text, [Text.UTF8Encoding]::new($false))
Write-Host "media-kit Android decoder-lab hwdec/VO hook applied: $Target"


# libmpv 换成 1-Reality/libmpv-android-video-build 的 20261107：mpv 与 20260906 同一份源码，
# 只多了 FFmpeg 的 MediaCodec 解码器支持 skip_frame=nonref（丢非参考帧补丁）
$Gradle = Join-Path $MediaKitDir.FullName 'libs/android/media_kit_libs_android_video/android/build.gradle'
$GradleText = [IO.File]::ReadAllText($Gradle)
$Jars = @(
    @{ Abi = 'arm64-v8a';   Old = '98df6410375cc7a4be7e6eff56f9ccd88fa52678973cc23bcf7e934ab8c8682d'; New = '919c591cb8c523afcfec3fafe48b636e0b5e503e5ea3aa520d348e7d3523a0fb' },
    @{ Abi = 'armeabi-v7a'; Old = '75ba2199848cd6224817320ddfabb7d7ea48fb4cfb1721b0090043d5a8a38602'; New = '30381cfd8ef0d38477271a0798038ce7d94a3593774bf0f56f897a9cb676bfc4' },
    @{ Abi = 'x86_64';      Old = '1caa6198de22808bd7f10fcff2923f5eb174cc42ef24569aeafb98c6597457a4'; New = 'e91f369670ba609a4b0fc4ddcb91c3aea8920e89ef11082733aaf007a7803b5b' }
)
foreach ($j in $Jars) {
    $OldLine = "[`"url`": `"https://github.com/My-Responsitories/libmpv-android-video-build/releases/download/20260906/default-$($j.Abi).jar`", `"sha256`": `"$($j.Old)`", `"destination`": file(`"`$buildDir/20260906/default-$($j.Abi).jar`")]"
    $NewLine = "[`"url`": `"https://github.com/1-Reality/libmpv-android-video-build/releases/download/20261107/default-$($j.Abi).jar`", `"sha256`": `"$($j.New)`", `"destination`": file(`"`$buildDir/20261107/default-$($j.Abi).jar`")]"
    $n = ([regex]::Matches($GradleText, [regex]::Escape($OldLine))).Count
    if ($n -ne 1) { throw "expected exactly one libmpv jar line for $($j.Abi), found $n" }
    $GradleText = $GradleText.Replace($OldLine, $NewLine)
}
[IO.File]::WriteAllText($Gradle, $GradleText, [Text.UTF8Encoding]::new($false))
Write-Host "libmpv jars -> 1-Reality 20261107: $Gradle"