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


enum BrotherOrientationPhase {
  app('APP 普通页面'),
  windowed('视频非全屏'),
  fullscreen('视频全屏');

  final String desc;
  const BrotherOrientationPhase(this.desc);
}

enum BrotherDirectionAction {
  keepCurrent('保持当前，不发送方向请求'),
  systemCurrent('读取并采用当前界面方向'),
  startupDirection('采用 APP 启动方向'),
  video('按视频横竖方向'),
  ratio('按视频与屏幕比例判断'),
  portrait('竖屏'),
  landscape('横屏'),
  portraitUp('正竖屏'),
  portraitDown('倒竖屏'),
  landscapeLeft('左横屏'),
  landscapeRight('右横屏'),
  triggerDirection('采用触发方向');

  final String desc;
  const BrotherDirectionAction(this.desc);
}

enum BrotherRuntimeMode {
  inheritRequest('沿用当前方向规则'),
  unspecified('系统自行决定（UNSPECIFIED）'),
  landscape('横屏（LANDSCAPE）'),
  portrait('竖屏（PORTRAIT）'),
  user('用户方向（USER）'),
  behind('继承后层（BEHIND）'),
  sensor('传感器（SENSOR）'),
  noSensor('禁用传感器（NOSENSOR）'),
  sensorLandscape('横屏传感器（SENSOR_LANDSCAPE）'),
  sensorPortrait('竖屏传感器（SENSOR_PORTRAIT）'),
  reverseLandscape('反向横屏（REVERSE_LANDSCAPE）'),
  reversePortrait('反向竖屏（REVERSE_PORTRAIT）'),
  fullSensor('全方向传感器（FULL_SENSOR）'),
  userLandscape('用户横屏（USER_LANDSCAPE）'),
  userPortrait('用户竖屏（USER_PORTRAIT）'),
  fullUser('完整遵循用户设置（FULL_USER）'),
  locked('锁定当前（LOCKED）'),
  followSystemAllowed('遵循系统旋转并应用方向许可'),
  alwaysAutoAllowed('忽略系统锁定并应用方向许可'),
  systemGate('仅读取系统旋转开关（关=LOCKED，开=FULL_SENSOR）'),
  appGravity('APP 重力传感器');

  final String desc;
  const BrotherRuntimeMode(this.desc);
}

enum BrotherRuntimeActivation {
  immediate('立即接管'),
  afterSourceChange('等待运行方向源首次变化后接管');

  final String desc;
  const BrotherRuntimeActivation(this.desc);
}

enum BrotherAllowedBasis {
  fixed('固定许可集合'),
  entryAxis('进入时横竖轴'),
  entryExact('进入时具体方向');

  final String desc;
  const BrotherAllowedBasis(this.desc);
}

enum BrotherRuntimeLatchAxis {
  off('关闭'),
  portrait('首次转入竖屏后'),
  landscape('首次转入横屏后');

  final String desc;
  const BrotherRuntimeLatchAxis(this.desc);
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

  Iterable<BrotherRuntimeMode> get possibleRuntimeModes sync* {
    yield runtimeMode;
    final portrait = resumePortraitRuntimeMode;
    if (portrait != null && portrait != runtimeMode) yield portrait;
    final landscape = resumeLandscapeRuntimeMode;
    if (landscape != null &&
        landscape != runtimeMode &&
        landscape != portrait) {
      yield landscape;
    }
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

  static BrotherPhaseConfig fromStorage(
    Object? raw, {
    required BrotherPhaseConfig fallback,
  }) {
    if (raw is! List || raw.length < 7) return fallback;
    T value<T extends Enum>(List<T> values, Object? index, T orElse) =>
        index is int && index >= 0 && index < values.length
            ? values[index]
            : orElse;
    final v2 = raw.length >= 8;
    final v3 = raw.length >= 12;
    BrotherRuntimeMode? nullableRuntime(Object? index) =>
        index is int &&
            index >= 0 &&
            index < BrotherRuntimeMode.values.length
        ? BrotherRuntimeMode.values[index]
        : null;
    return BrotherPhaseConfig(
      enterAction: value(
        BrotherDirectionAction.values,
        raw[0],
        fallback.enterAction,
      ),
      resumeAction: value(
        BrotherDirectionAction.values,
        raw[1],
        fallback.resumeAction,
      ),
      runtimeMode: value(
        BrotherRuntimeMode.values,
        raw[2],
        fallback.runtimeMode,
      ),
      runtimeActivation: v2
          ? value(
              BrotherRuntimeActivation.values,
              raw[3],
              fallback.runtimeActivation,
            )
          : fallback.runtimeActivation,
      allowedBasis: value(
        BrotherAllowedBasis.values,
        raw[v2 ? 4 : 3],
        fallback.allowedBasis,
      ),
      allowedMask: raw[v2 ? 5 : 4] is int
          ? raw[v2 ? 5 : 4] as int
          : fallback.allowedMask,
      gravityFollowSystemLock: raw[v2 ? 6 : 5] is bool
          ? raw[v2 ? 6 : 5] as bool
          : fallback.gravityFollowSystemLock,
      angleDegrees: raw[v2 ? 7 : 6] is int
          ? raw[v2 ? 7 : 6] as int
          : fallback.angleDegrees,
      resumePortraitRuntimeMode: v3
          ? nullableRuntime(raw[8])
          : fallback.resumePortraitRuntimeMode,
      resumeLandscapeRuntimeMode: v3
          ? nullableRuntime(raw[9])
          : fallback.resumeLandscapeRuntimeMode,
      runtimeLatchAxis: v3
          ? value(
              BrotherRuntimeLatchAxis.values,
              raw[10],
              fallback.runtimeLatchAxis,
            )
          : fallback.runtimeLatchAxis,
      runtimeLatchMode: v3
          ? value(
              BrotherRuntimeMode.values,
              raw[11],
              fallback.runtimeLatchMode,
            )
          : fallback.runtimeLatchMode,
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
