enum OrientationPolicyMode {
  simple('简单配置'),
  advanced('高级配置');

  final String desc;
  const OrientationPolicyMode(this.desc);
}

enum AppInitialOrientation {
  system('跟随系统当前方向'),
  portrait('竖屏'),
  landscape('横屏'),
  portraitUp('正竖屏'),
  portraitDown('倒竖屏'),
  landscapeLeft('左横屏'),
  landscapeRight('右横屏');

  final String desc;
  const AppInitialOrientation(this.desc);
}

enum AppRotationMode {
  lockInitial('保持初始方向'),
  followSystem('遵循系统旋转设置'),
  alwaysAuto('始终自动旋转');

  final String desc;
  const AppRotationMode(this.desc);
}

enum WindowedPlayerRotationMode {
  inheritApp('继承 APP 运行方向策略'),
  keepCurrent('保持进入视频页时的方向'),
  followSystem('遵循系统旋转设置'),
  alwaysAuto('始终自动旋转');

  final String desc;
  const WindowedPlayerRotationMode(this.desc);
}

enum FullScreenRotationSource {
  keepCurrent('保持当前方向'),
  followSystem('遵循系统旋转设置'),
  alwaysAuto('始终自动旋转'),
  appGravity('APP 重力方向');

  final String desc;
  const FullScreenRotationSource(this.desc);
}

enum FullScreenAllowedOrientation {
  all('全部'),
  landscape('仅横屏'),
  portrait('仅竖屏'),
  entryAxis('保持进入时横竖方向'),
  entryExact('保持进入时具体方向');

  final String desc;
  const FullScreenAllowedOrientation(this.desc);
}

enum OrientationFullscreenTrigger {
  off('关闭'),
  landscapeEnter('横置进入'),
  portraitExit('竖置退出'),
  both('横置进入并竖置退出');

  final String desc;
  const OrientationFullscreenTrigger(this.desc);
}

enum OrientationTriggerSource {
  system('系统方向'),
  appGravity('APP 重力方向'),
  any('任一满足'),
  both('同时满足');

  final String desc;
  const OrientationTriggerSource(this.desc);
}

enum OrientationTriggerContent {
  all('所有视频'),
  landscapeVideo('仅横屏视频'),
  portraitVideo('仅竖屏视频');

  final String desc;
  const OrientationTriggerContent(this.desc);
}

enum EntryOrientationPolicy {
  keepCurrent('不改变当前方向'),
  video('按视频方向'),
  portrait('强制竖屏'),
  landscape('强制横屏'),
  ratio('按视频与屏幕比例判断'),
  portraitUp('正竖屏'),
  portraitDown('倒竖屏'),
  landscapeLeft('左横屏'),
  landscapeRight('右横屏'),
  triggerDirection('跟随触发方向');

  final String desc;
  const EntryOrientationPolicy(this.desc);
}

enum OrientationAutoExitScope {
  orientationOnly('仅方向触发进入的全屏'),
  automatic('所有自动进入的全屏'),
  all('所有全屏');

  final String desc;
  const OrientationAutoExitScope(this.desc);
}

enum FullscreenEntryCause {
  manual,
  playbackAuto,
  orientation,
}

enum OrientationHandoffExperiment {
  off('关闭（正常逻辑）'),
  currentImmediate('当前交权：立即'),
  current5s('当前交权：延迟 5 秒'),
  unspecifiedImmediate('UNSPECIFIED：立即'),
  unspecified5s('UNSPECIFIED：延迟 5 秒'),
  userImmediate('USER：立即'),
  user5s('USER：延迟 5 秒'),
  fullUserImmediate('FULL_USER：立即'),
  fullUser5s('FULL_USER：延迟 5 秒'),
  fullSensorImmediate('FULL_SENSOR：立即'),
  fullSensor5s('FULL_SENSOR：延迟 5 秒'),
  holdEntry('不交权：保持入场方向');

  final String desc;
  const OrientationHandoffExperiment(this.desc);
}

enum ExitOrientationMode {
  restoreApp('恢复当前页面方向策略'),
  keepPlayer('保持播放器方向，之后继续正常旋转'),
  lockPlayer('锁定播放器方向');

  final String desc;
  const ExitOrientationMode(this.desc);
}

abstract final class OrientationMask {
  static const int portraitUp = 1;
  static const int portraitDown = 2;
  static const int landscapeLeft = 4;
  static const int landscapeRight = 8;
  static const int portrait = portraitUp | portraitDown;
  static const int landscape = landscapeLeft | landscapeRight;
  static const int all = portrait | landscape;
}
