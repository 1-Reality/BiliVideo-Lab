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
$Old = @'
  /// --vo
  String get vo => configuration.vo ?? 'gpu';
'@
$New = @'
  /// --vo
  ///
  /// Decoder lab may request a different Android VO for the current player.
  /// Read it here so media_kit still owns the Surface/--wid/--vo ordering.
  String? get _decoderLabVo {
    final name = 'user-data/piliplus-decoder-lab-vo'.toNativeUtf8();
    final value = NativePlayer.mpv.mpv_get_property_string(player.ctx, name);
    calloc.free(name.cast());
    if (value.address == 0) return null;
    final result = value.toDartString();
    NativePlayer.mpv.mpv_free(value.cast());
    return result.isEmpty ? null : result;
  }

  String get vo => _decoderLabVo ?? configuration.vo ?? 'gpu';
'@

$Count = ([regex]::Matches($Text, [regex]::Escape($Old))).Count
if ($Count -ne 1) {
    throw "expected exactly one AndroidVideoController --vo getter, found $Count"
}

$Text = $Text.Replace($Old, $New)
[IO.File]::WriteAllText($Target, $Text, [Text.UTF8Encoding]::new($false))
Write-Host "media-kit Android decoder-lab VO hook applied: $Target"
