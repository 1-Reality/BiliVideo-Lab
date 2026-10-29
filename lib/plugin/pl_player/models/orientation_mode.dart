enum OrientationPolicyMode {
  simple('简单配置'),
  advanced('高级配置'),
  brotherTech('哥哥科技模式');

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
  alwaysAuto('始终自动旋转（忽略旋转锁定）');

  final String desc;
  const AppRotationMode(this.desc);
}

enum WindowedPlayerRotationMode {
  inheritApp('沿用 APP 普通页面的设置'),
  keepCurrent('保持进入视频页时的方向'),
  followSystem('遵循系统旋转设置'),
  alwaysAuto('始终自动旋转（忽略旋转锁定）');

  final String desc;
  const WindowedPlayerRotationMode(this.desc);
}

enum FullScreenRotationSource {
  keepCurrent('保持当前方向'),
  followSystem('遵循系统旋转设置'),
  alwaysAuto('始终自动旋转（忽略旋转锁定）'),
  appGravity('APP 重力传感器');

  final String desc;
  const FullScreenRotationSource(this.desc);
}

enum FullScreenAllowedOrientation {
  all('全部'),
  landscape('仅横屏'),
  portrait('仅竖屏'),
  entryAxis('只允许进入时那一轴（同为横或同为竖）'),
  entryExact('只允许进入时精确那个方向');

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
  system('系统界面方向'),
  appGravity('APP 重力传感器'),
  any('两者任一满足'),
  both('两者同时满足');

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
  ratio('竖屏视频或屏幕接近方形（长宽比小于 1.2，如折叠屏内屏）时竖屏，否则横屏'),
  portraitUp('正竖屏'),
  portraitDown('倒竖屏'),
  landscapeLeft('左横屏'),
  landscapeRight('右横屏'),
  triggerDirection('触发时手机所处的方向');

  final String desc;
  const EntryOrientationPolicy(this.desc);
}

enum FullscreenEntryCause {
  manual,
  playbackAuto,
  orientation,
}

abstract final class FullscreenEntryCauseMask {
  static const int manual = 1;
  static const int playbackAuto = 2;
  static const int orientation = 4;
  static const int all = manual | playbackAuto | orientation;

  static int of(FullscreenEntryCause cause) => switch (cause) {
    FullscreenEntryCause.manual => manual,
    FullscreenEntryCause.playbackAuto => playbackAuto,
    FullscreenEntryCause.orientation => orientation,
  };
}

enum ExitOrientationMode {
  restoreApp('恢复为当前页面原本的旋转设置'),
  keepPlayer('保持播放器方向，之后继续正常旋转'),
  lockPlayer('锁定为全屏时的方向');

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


enum BrotherOrientationPhase {
  app('APP 普通页面'),
  windowed('视频非全屏'),
  fullscreen('视频全屏');

  final String desc;
  const BrotherOrientationPhase(this.desc);
}

enum BrotherDirectionAction {
  keepCurrent('保持当前方向，不主动旋转'),
  systemCurrent('锁定为当前方向'),
  startupDirection('恢复 APP 启动时的方向'),
  video('按视频横竖方向'),
  ratio('竖屏视频或屏幕长宽比不到 16:9 时竖屏，否则横屏'),
  portrait('竖屏'),
  landscape('横屏'),
  portraitUp('正竖屏'),
  portraitDown('倒竖屏'),
  landscapeLeft('左横屏'),
  landscapeRight('右横屏'),
  triggerDirection('触发时手机所处的方向');

  final String desc;
  const BrotherDirectionAction(this.desc);
}

enum BrotherRuntimeMode {
  inheritRequest('沿用当前生效的方向设置，不重新指定'),
  unspecified('不指定，按系统默认处理（UNSPECIFIED）'),
  landscape('横屏（LANDSCAPE）'),
  portrait('竖屏（PORTRAIT）'),
  user('跟随系统旋转锁定，多数设备不含倒竖屏（USER）'),
  behind('与下层界面方向相同（BEHIND）'),
  sensor('按传感器旋转，忽略旋转锁定，多数设备不含倒竖屏（SENSOR）'),
  noSensor('不使用传感器，保持设备自然方向（NOSENSOR）'),
  sensorLandscape('横屏，按传感器切换左右横屏（SENSOR_LANDSCAPE）'),
  sensorPortrait('竖屏，按传感器切换正倒竖屏（SENSOR_PORTRAIT）'),
  reverseLandscape('反向横屏（REVERSE_LANDSCAPE）'),
  reversePortrait('反向竖屏（REVERSE_PORTRAIT）'),
  fullSensor('按传感器四向旋转，忽略旋转锁定（FULL_SENSOR）'),
  userLandscape('横屏，旋转锁定关闭时可切换左右横屏（USER_LANDSCAPE）'),
  userPortrait('竖屏，旋转锁定关闭时可切换正倒竖屏（USER_PORTRAIT）'),
  fullUser('跟随系统旋转锁定，四向旋转（FULL_USER）'),
  locked('锁定当前方向（LOCKED）'),
  followSystemAllowed('跟随系统旋转锁定，限于最终许可'),
  alwaysAutoAllowed('忽略系统旋转锁定，限于最终许可'),
  systemGate('只读系统旋转开关：开启时锁定，关闭时四向旋转'),
  appGravity('由 APP 重力传感器控制');

  final String desc;
  const BrotherRuntimeMode(this.desc);
}

enum BrotherRuntimeActivation {
  immediate('立即生效'),
  afterSourceChange('手机首次转动后生效');

  final String desc;
  const BrotherRuntimeActivation(this.desc);
}

enum BrotherAllowedBasis {
  fixed('固定允许的方向（手工选择）'),
  entryAxis('与进入时同大方向'),
  entryExact('仅限进入时具体方向');

  final String desc;
  const BrotherAllowedBasis(this.desc);
}

enum BrotherRuntimeLatchAxis {
  off('关闭'),
  portrait('处于竖屏时（含进入时已为竖屏）'),
  landscape('处于横屏时（含进入时已为横屏）'),
  portraitEdge('由横屏转为竖屏时（不含进入时已为竖屏）'),
  landscapeEdge('由竖屏转为横屏时（不含进入时已为横屏）');

  final String desc;
  const BrotherRuntimeLatchAxis(this.desc);

  bool get targetsLandscape =>
      this == BrotherRuntimeLatchAxis.landscape ||
      this == BrotherRuntimeLatchAxis.landscapeEdge;

  bool get edgeTriggered =>
      this == BrotherRuntimeLatchAxis.portraitEdge ||
      this == BrotherRuntimeLatchAxis.landscapeEdge;
}

final class BrotherPhaseConfig {
  const BrotherPhaseConfig({
    required this.enterAction,
    required this.resumeAction,
    required this.runtimeMode,
    required this.runtimeActivation,
    required this.allowedBasis,
    required this.allowedMask,
    required this.gravityFollowSystemLock,
    required this.angleDegrees,
    this.resumePortraitRuntimeMode,
    this.resumeLandscapeRuntimeMode,
    this.runtimeLatchAxis = BrotherRuntimeLatchAxis.off,
    this.runtimeLatchMode = BrotherRuntimeMode.locked,
  });

  static const defaultApp = BrotherPhaseConfig(
    enterAction: BrotherDirectionAction.systemCurrent,
    resumeAction: BrotherDirectionAction.keepCurrent,
    runtimeMode: BrotherRuntimeMode.unspecified,
    runtimeActivation: BrotherRuntimeActivation.immediate,
    allowedBasis: BrotherAllowedBasis.fixed,
    allowedMask: OrientationMask.all,
    gravityFollowSystemLock: true,
    angleDegrees: 30,
    resumePortraitRuntimeMode: BrotherRuntimeMode.locked,
    resumeLandscapeRuntimeMode: BrotherRuntimeMode.alwaysAutoAllowed,
    runtimeLatchAxis: BrotherRuntimeLatchAxis.portrait,
    runtimeLatchMode: BrotherRuntimeMode.followSystemAllowed,
  );

  static const defaultWindowed = BrotherPhaseConfig(
    enterAction: BrotherDirectionAction.keepCurrent,
    resumeAction: BrotherDirectionAction.startupDirection,
    runtimeMode: BrotherRuntimeMode.alwaysAutoAllowed,
    runtimeActivation: BrotherRuntimeActivation.immediate,
    allowedBasis: BrotherAllowedBasis.fixed,
    allowedMask: OrientationMask.all,
    gravityFollowSystemLock: true,
    angleDegrees: 30,
    resumeLandscapeRuntimeMode: BrotherRuntimeMode.followSystemAllowed,
    runtimeLatchAxis: BrotherRuntimeLatchAxis.off,
    runtimeLatchMode: BrotherRuntimeMode.locked,
  );

  static const defaultFullscreen = BrotherPhaseConfig(
    enterAction: BrotherDirectionAction.video,
    resumeAction: BrotherDirectionAction.keepCurrent,
    runtimeMode: BrotherRuntimeMode.locked,
    runtimeActivation: BrotherRuntimeActivation.immediate,
    allowedBasis: BrotherAllowedBasis.fixed,
    allowedMask: OrientationMask.all,
    gravityFollowSystemLock: true,
    angleDegrees: 30,
    runtimeLatchAxis: BrotherRuntimeLatchAxis.off,
    runtimeLatchMode: BrotherRuntimeMode.locked,
  );

  final BrotherDirectionAction enterAction;
  final BrotherDirectionAction resumeAction;
  final BrotherRuntimeMode runtimeMode;
  final BrotherRuntimeActivation runtimeActivation;
  final BrotherAllowedBasis allowedBasis;
  final int allowedMask;
  final bool gravityFollowSystemLock;
  final int angleDegrees;
  final BrotherRuntimeMode? resumePortraitRuntimeMode;
  final BrotherRuntimeMode? resumeLandscapeRuntimeMode;
  final BrotherRuntimeLatchAxis runtimeLatchAxis;
  final BrotherRuntimeMode runtimeLatchMode;

  BrotherPhaseConfig copyWith({
    BrotherDirectionAction? enterAction,
    BrotherDirectionAction? resumeAction,
    BrotherRuntimeMode? runtimeMode,
    BrotherRuntimeActivation? runtimeActivation,
    BrotherAllowedBasis? allowedBasis,
    int? allowedMask,
    bool? gravityFollowSystemLock,
    int? angleDegrees,
    BrotherRuntimeLatchAxis? runtimeLatchAxis,
    BrotherRuntimeMode? runtimeLatchMode,
  }) => BrotherPhaseConfig(
    enterAction: enterAction ?? this.enterAction,
    resumeAction: resumeAction ?? this.resumeAction,
    runtimeMode: runtimeMode ?? this.runtimeMode,
    runtimeActivation: runtimeActivation ?? this.runtimeActivation,
    allowedBasis: allowedBasis ?? this.allowedBasis,
    allowedMask: allowedMask ?? this.allowedMask,
    gravityFollowSystemLock:
        gravityFollowSystemLock ?? this.gravityFollowSystemLock,
    angleDegrees: angleDegrees ?? this.angleDegrees,
    resumePortraitRuntimeMode: resumePortraitRuntimeMode,
    resumeLandscapeRuntimeMode: resumeLandscapeRuntimeMode,
    runtimeLatchAxis: runtimeLatchAxis ?? this.runtimeLatchAxis,
    runtimeLatchMode: runtimeLatchMode ?? this.runtimeLatchMode,
  );

  BrotherPhaseConfig withResumeRuntime({
    required bool landscape,
    required BrotherRuntimeMode? mode,
  }) => BrotherPhaseConfig(
    enterAction: enterAction,
    resumeAction: resumeAction,
    runtimeMode: runtimeMode,
    runtimeActivation: runtimeActivation,
    allowedBasis: allowedBasis,
    allowedMask: allowedMask,
    gravityFollowSystemLock: gravityFollowSystemLock,
    angleDegrees: angleDegrees,
    resumePortraitRuntimeMode:
        landscape ? resumePortraitRuntimeMode : mode,
    resumeLandscapeRuntimeMode:
        landscape ? mode : resumeLandscapeRuntimeMode,
    runtimeLatchAxis: runtimeLatchAxis,
    runtimeLatchMode: runtimeLatchMode,
  );

  BrotherRuntimeMode runtimeForResume(int directionBit) =>
      (directionBit & OrientationMask.landscape != 0
              ? resumeLandscapeRuntimeMode
              : resumePortraitRuntimeMode) ??
          runtimeMode;

  BrotherPhaseConfig effectiveForResume({
    required bool resume,
    required int directionBit,
  }) {
    if (!resume) return this;
    final selected = runtimeForResume(directionBit);
    return selected == runtimeMode ? this : copyWith(runtimeMode: selected);
  }


  List<Object> toStorage() => [
    enterAction.index,
    resumeAction.index,
    runtimeMode.index,
    runtimeActivation.index,
    allowedBasis.index,
    allowedMask,
    gravityFollowSystemLock,
    angleDegrees,
    resumePortraitRuntimeMode?.index ?? -1,
    resumeLandscapeRuntimeMode?.index ?? -1,
    runtimeLatchAxis.index,
    runtimeLatchMode.index,
  ];

  static BrotherPhaseConfig fromStorage(List raw) {
    final resumePortrait = raw[8] as int;
    final resumeLandscape = raw[9] as int;
    return BrotherPhaseConfig(
      enterAction: BrotherDirectionAction.values[raw[0] as int],
      resumeAction: BrotherDirectionAction.values[raw[1] as int],
      runtimeMode: BrotherRuntimeMode.values[raw[2] as int],
      runtimeActivation: BrotherRuntimeActivation.values[raw[3] as int],
      allowedBasis: BrotherAllowedBasis.values[raw[4] as int],
      allowedMask: raw[5] as int,
      gravityFollowSystemLock: raw[6] as bool,
      angleDegrees: raw[7] as int,
      resumePortraitRuntimeMode: resumePortrait == -1
          ? null
          : BrotherRuntimeMode.values[resumePortrait],
      resumeLandscapeRuntimeMode: resumeLandscape == -1
          ? null
          : BrotherRuntimeMode.values[resumeLandscape],
      runtimeLatchAxis: BrotherRuntimeLatchAxis.values[raw[10] as int],
      runtimeLatchMode: BrotherRuntimeMode.values[raw[11] as int],
    );
  }
}

abstract final class BrotherOrientationSignalMask {
  static const int window = 1;
  static const int proposedSystem = 2;
  static const int appGravity = 4;
  static const int all = window | proposedSystem | appGravity;
}

enum FullscreenExitCause {
  manual,
  playbackAuto,
  orientation,
}

abstract final class FullscreenExitCauseMask {
  static const int manual = 1;
  static const int playbackAuto = 2;
  static const int orientation = 4;
  static const int all = manual | playbackAuto | orientation;

  static int of(FullscreenExitCause cause) => switch (cause) {
    FullscreenExitCause.manual => manual,
    FullscreenExitCause.playbackAuto => playbackAuto,
    FullscreenExitCause.orientation => orientation,
  };
}
