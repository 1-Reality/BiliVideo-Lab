import 'dart:io' show Platform;

import 'package:PiliBro/plugin/pl_player/models/orientation_mode.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/orientation_policy.dart';

abstract final class BrotherDiagnosticListener {
  static const int metrics = 1;
  static const int proposedSystem = 2;
  static const int appGravity = 4;
}

final class BrotherPhaseDiagnostics {
  const BrotherPhaseDiagnostics({
    required this.name,
    required this.defaultRuntime,
    required this.resumeLandscapeRuntime,
    required this.resumePortraitRuntime,
    required this.allowed,
    required this.runtimeListeners,
    required this.latch,
    required this.latchListening,
    required this.notes,
  });

  final String name;
  final String defaultRuntime;
  final String? resumeLandscapeRuntime;
  final String? resumePortraitRuntime;
  final String allowed;
  final int runtimeListeners;
  final String? latch;
  final bool latchListening;
  final List<String> notes;
}

final class BrotherDiagnosticsSnapshot {
  const BrotherDiagnosticsSnapshot({
    required this.phases,
    required this.triggerListeners,
    required this.triggerNotes,
  });

  final List<BrotherPhaseDiagnostics> phases;
  final int triggerListeners;
  final List<String> triggerNotes;
}

/// 从编译好的哥哥科技方案推算各场景会启用哪些监听，只读方案，不碰运行状态
abstract final class BrotherDiagnosticsCompiler {
  static bool get _supportsProposedRotation =>
      Platform.isAndroid && DeviceUtils.sdkInt >= 34;

  static BrotherDiagnosticsSnapshot compile(BrotherOrientationPlan plan) {
    final triggerNotes = <String>{};
    var triggerListeners = 0;

    void addTriggerSignals(
      int mask, {
      required bool gravityAllowed,
      required String scope,
    }) {
      if (mask & BrotherOrientationSignalMask.window != 0) {
        triggerListeners |= BrotherDiagnosticListener.metrics;
      }
      if (mask & BrotherOrientationSignalMask.proposedSystem != 0) {
        if (_supportsProposedRotation) {
          triggerListeners |= BrotherDiagnosticListener.proposedSystem;
        } else {
          triggerNotes.add('$scope：系统低于 Android 14，「系统建议方向」信号无效');
        }
      }
      if (mask & BrotherOrientationSignalMask.appGravity != 0) {
        if (gravityAllowed) {
          triggerListeners |= BrotherDiagnosticListener.appGravity;
        } else {
          triggerNotes.add('$scope：系统旋转锁定已开启，重力信号不生效');
        }
      }
    }

    if (plan.landscapeEnter) {
      addTriggerSignals(
        plan.enterSignalMask,
        gravityAllowed:
            !plan.windowed.gravityFollowSystemLock || plan.systemAutoRotate,
        scope: '横置进入全屏',
      );
    }
    if (plan.portraitExit) {
      final gravityAllowed =
          !plan.fullscreen.gravityFollowSystemLock || plan.systemAutoRotate;
      addTriggerSignals(
        plan.exitSignalMask,
        gravityAllowed: gravityAllowed,
        scope: '竖置退出全屏',
      );
      if (plan.manualExitConfirmations > 0) {
        addTriggerSignals(
          plan.manualExitSignalMask,
          gravityAllowed: gravityAllowed,
          scope: '手动全屏的退出确认',
        );
      }
    }

    return BrotherDiagnosticsSnapshot(
      phases: [
        _phase(plan, 'APP 普通页面', plan.app, hasResume: true, appPhase: true),
        _phase(
          plan,
          '视频非全屏',
          plan.windowed,
          hasResume: true,
          appPhase: false,
        ),
        _phase(
          plan,
          '视频全屏',
          plan.fullscreen,
          hasResume: false,
          appPhase: false,
        ),
      ],
      triggerListeners: triggerListeners,
      triggerNotes: triggerNotes.toList(growable: false),
    );
  }

  static BrotherPhaseDiagnostics _phase(
    BrotherOrientationPlan plan,
    String name,
    BrotherPhaseConfig phase, {
    required bool hasResume,
    required bool appPhase,
  }) {
    final masks = _possibleAllowedMasks(plan, phase);
    final notes = <String>{};
    var listeners = 0;

    void addRuntime(BrotherRuntimeMode mode) {
      final candidate = phase.copyWith(runtimeMode: mode);
      for (final mask in masks) {
        final active =
            mask != 0 && !(appPhase && mode == BrotherRuntimeMode.appGravity);
        if (!active) {
          if (appPhase && mode == BrotherRuntimeMode.appGravity) {
            notes.add('${mode.desc}：APP 主页/普通页不可用');
          }
          continue;
        }
        if (!appPhase && mode == BrotherRuntimeMode.appGravity) {
          if (candidate.gravityFollowSystemLock && !plan.systemAutoRotate) {
            notes.add('${mode.desc}：系统旋转锁定已开启，改为锁定当前方向');
          } else {
            listeners |= BrotherDiagnosticListener.appGravity;
          }
        }
        if (!appPhase &&
            candidate.runtimeActivation ==
                BrotherRuntimeActivation.afterSourceChange &&
            mode != BrotherRuntimeMode.appGravity &&
            mode != BrotherRuntimeMode.inheritRequest &&
            mode != BrotherRuntimeMode.locked) {
          if (!_supportsProposedRotation) {
            notes.add('${mode.desc}：系统低于 API 34，无法等待首次转动');
          } else if (mode == BrotherRuntimeMode.followSystemAllowed &&
              !plan.systemAutoRotate) {
            notes.add('${mode.desc}：系统旋转锁定已开启，不等待首次转动');
          } else {
            listeners |= BrotherDiagnosticListener.proposedSystem;
          }
        }
        if (OrientationPolicy.brotherRuntimeNeedsGuard(candidate, mask)) {
          listeners |= BrotherDiagnosticListener.metrics;
        }
      }
    }

    final runtimeModes = <BrotherRuntimeMode>[phase.runtimeMode];
    if (hasResume) {
      final portraitMode = phase.resumePortraitRuntimeMode;
      if (portraitMode != null && portraitMode != phase.runtimeMode) {
        runtimeModes.add(portraitMode);
      }
      final landscapeMode = phase.resumeLandscapeRuntimeMode;
      if (landscapeMode != null &&
          landscapeMode != phase.runtimeMode &&
          landscapeMode != portraitMode) {
        runtimeModes.add(landscapeMode);
      }
    }
    for (final mode in runtimeModes) {
      addRuntime(mode);
    }

    var latchListening = false;
    if (appPhase && phase.runtimeLatchAxis != BrotherRuntimeLatchAxis.off) {
      for (final mode in runtimeModes) {
        for (final mask in masks) {
          final interpreted = OrientationPolicy.interpretBrotherAppRuntimeLatch(
            phase.copyWith(runtimeMode: mode),
            allowedMask: mask,
          );
          if (!interpreted.enabled) continue;
          latchListening = true;
          final target = interpreted.targetPhase;
          if (target.runtimeMode != BrotherRuntimeMode.appGravity &&
              OrientationPolicy.brotherRuntimeNeedsGuard(target, mask)) {
            listeners |= BrotherDiagnosticListener.metrics;
          }
        }
      }
    }

    return BrotherPhaseDiagnostics(
      name: name,
      defaultRuntime: _modeLabel(plan, phase, phase.runtimeMode, appPhase),
      resumeLandscapeRuntime: hasResume
          ? _resumeLabel(
              plan,
              phase,
              phase.resumeLandscapeRuntimeMode,
              appPhase,
            )
          : null,
      resumePortraitRuntime: hasResume
          ? _resumeLabel(
              plan,
              phase,
              phase.resumePortraitRuntimeMode,
              appPhase,
            )
          : null,
      allowed: _allowedLabel(plan, phase),
      runtimeListeners: listeners,
      latch: appPhase && phase.runtimeLatchAxis != BrotherRuntimeLatchAxis.off
          ? '${phase.runtimeLatchAxis.desc}，切换为${_modeLabel(plan, phase, phase.runtimeLatchMode, true)}'
          : null,
      latchListening: latchListening,
      notes: notes.toList(growable: false),
    );
  }

  static String _resumeLabel(
    BrotherOrientationPlan plan,
    BrotherPhaseConfig phase,
    BrotherRuntimeMode? mode,
    bool appPhase,
  ) => mode == null ? '沿用运行期间的旋转方式' : _modeLabel(plan, phase, mode, appPhase);

  static String _modeLabel(
    BrotherOrientationPlan plan,
    BrotherPhaseConfig phase,
    BrotherRuntimeMode mode,
    bool appPhase,
  ) {
    final candidate = phase.copyWith(runtimeMode: mode);
    for (final mask in _possibleAllowedMasks(plan, phase)) {
      if (!(appPhase && mode == BrotherRuntimeMode.appGravity)) {
        return mode.desc;
      }
    }
    return '${mode.desc}（APP 常规页面不可用）';
  }

  static Set<int> _possibleAllowedMasks(
    BrotherOrientationPlan plan,
    BrotherPhaseConfig phase,
  ) {
    final finalMask = plan.effectiveFinalMask;
    return switch (phase.allowedBasis) {
      BrotherAllowedBasis.fixed => {phase.allowedMask & finalMask},
      BrotherAllowedBasis.entryAxis => {
          OrientationMask.portrait & finalMask,
          OrientationMask.landscape & finalMask,
        },
      BrotherAllowedBasis.entryExact => {
          OrientationMask.portraitUp & finalMask,
          OrientationMask.portraitDown & finalMask,
          OrientationMask.landscapeLeft & finalMask,
          OrientationMask.landscapeRight & finalMask,
        },
    };
  }

  static String _allowedLabel(
    BrotherOrientationPlan plan,
    BrotherPhaseConfig phase,
  ) => switch (phase.allowedBasis) {
    BrotherAllowedBasis.fixed =>
      _maskLabel(phase.allowedMask & plan.effectiveFinalMask),
    BrotherAllowedBasis.entryAxis =>
      '${phase.allowedBasis.desc}，受最终方向许可限制：${_maskLabel(plan.effectiveFinalMask)}',
    BrotherAllowedBasis.entryExact =>
      '${phase.allowedBasis.desc}，受最终方向许可限制：${_maskLabel(plan.effectiveFinalMask)}',
  };

  static String _maskLabel(int mask) {
    if (mask == 0) return '无';
    if (mask == OrientationMask.all) return '全部';
    return [
      if (mask & OrientationMask.portraitUp != 0) '竖屏',
      if (mask & OrientationMask.portraitDown != 0) '倒竖',
      if (mask & OrientationMask.landscapeLeft != 0) '左横',
      if (mask & OrientationMask.landscapeRight != 0) '右横',
    ].join('、');
  }
}

/// 把编译结果排成可读的文字，不做策略推断
abstract final class BrotherOrientationDiagnostics {
  static String describe(BrotherDiagnosticsSnapshot snapshot) {
    // 某个监听在哪些场景会启用
    String where(int bit) {
      final scopes = [
        for (final phase in snapshot.phases)
          if (phase.runtimeListeners & bit != 0) '${phase.name}运行期间',
        if (bit == BrotherDiagnosticListener.metrics)
          for (final phase in snapshot.phases)
            if (phase.latchListening) '${phase.name}等待一次性切换',
        if (snapshot.triggerListeners & bit != 0) '方向触发全屏',
      ];
      return scopes.isEmpty ? '不订阅' : '会订阅：${scopes.join('、')}';
    }

    return [
      '【监听与开销】',
      '重力传感器（持续采样、耗电最多）：${where(BrotherDiagnosticListener.appGravity)}',
      '系统建议方向（Android 14 起、系统回调，开销很小）：${where(BrotherDiagnosticListener.proposedSystem)}',
      '窗口尺寸变化（仅在屏幕旋转时回调，几乎无开销）：${where(BrotherDiagnosticListener.metrics)}',
      '以上监听只在对应场景里启用、离开即注销：不轮询。',
      '',
      '【各生命周期】',
      for (final phase in snapshot.phases) ..._phaseLines(phase),
      if (snapshot.triggerNotes.isNotEmpty) ...[
        '',
        '【方向触发】',
        ...snapshot.triggerNotes,
      ],
    ].join('\n');
  }

  static List<String> _phaseLines(BrotherPhaseDiagnostics phase) => [
    '${phase.name}：运行期间 ${phase.defaultRuntime}',
    if (phase.resumeLandscapeRuntime != null)
      '  从下级以横屏返回后：${phase.resumeLandscapeRuntime}；以竖屏返回后：${phase.resumePortraitRuntime}',
    '  允许方向：${phase.allowed}',
    if (phase.latch != null) '  一次性切换：${phase.latch}',
    for (final note in phase.notes) '  注意：$note',
  ];}