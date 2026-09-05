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
  system('系统实际方向'),
  appGravity('APP 重力方向'),
  any('任一满足'),
  both('同时满足');

  final String desc;
  const OrientationTriggerSource(this.desc);
}

enum ExitOrientationMode {
  restoreApp('恢复 APP 方向'),
  keepPlayer('保持播放器方向'),
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
