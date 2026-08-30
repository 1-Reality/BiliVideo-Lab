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

[IO.File]::WriteAllText($Target, $Text, [Text.UTF8Encoding]::new($false))
Write-Host "media-kit Android decoder-lab hwdec/VO hook applied: $Target"
