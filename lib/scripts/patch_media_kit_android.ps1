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