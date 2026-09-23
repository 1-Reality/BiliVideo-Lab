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

/// Cold B -> B'' projection. Consumes compiled BrotherOrientationPlan only.
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
          triggerNotes.add('$scope：当前平台无系统建议方向监听');
        }
      }
      if (mask & BrotherOrientationSignalMask.appGravity != 0) {
        if (gravityAllowed) {
          triggerListeners |= BrotherDiagnosticListener.appGravity;
        } else {
          triggerNotes.add('$scope：APP重力受系统方向锁阻止');
        }
      }
    }

    if (plan.landscapeEnter) {
      addTriggerSignals(
        plan.enterSignalMask,
        gravityAllowed:
            !plan.windowed.gravityFollowSystemLock || plan.systemAutoRotate,
        scope: '进入触发',
      );
    }
    if (plan.portraitExit) {
      final gravityAllowed =
          !plan.fullscreen.gravityFollowSystemLock || plan.systemAutoRotate;
      addTriggerSignals(
        plan.exitSignalMask,
        gravityAllowed: gravityAllowed,
        scope: '退出触发',
      );
      if (plan.manualExitConfirmations > 0) {
        addTriggerSignals(
          plan.manualExitSignalMask,
          gravityAllowed: gravityAllowed,
          scope: '手动退出确认',
        );
      }
    }

    return BrotherDiagnosticsSnapshot(
      phases: [
        _phase(plan, 'APP', plan.app, hasResume: true, appPhase: true),
        _phase(
          plan,
          '非全屏',
          plan.windowed,
          hasResume: true,
          appPhase: false,
        ),
        _phase(
          plan,
          '全屏',
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
        final interpreted = OrientationPolicy.interpretBrotherRuntime(
          candidate,
          allowedMask: mask,
          appPhase: appPhase,
        );
        if (!interpreted.executable) {
          notes.add('${mode.desc}：首页无执行器');
          continue;
        }
        if (interpreted.usesAppGravity) {
          if (candidate.gravityFollowSystemLock && !plan.systemAutoRotate) {
            notes.add('${mode.desc}：系统方向锁关闭时运行时锁定');
          } else {
            listeners |= BrotherDiagnosticListener.appGravity;
          }
        }
        if (interpreted.waitsForSourceChange) {
          if (!_supportsProposedRotation) {
            notes.add('${mode.desc}：当前平台无系统建议方向等待源');
          } else if (mode == BrotherRuntimeMode.followSystemAllowed &&
              !plan.systemAutoRotate) {
            notes.add('${mode.desc}：系统方向锁关闭时不启用等待源');
          } else {
            listeners |= BrotherDiagnosticListener.proposedSystem;
          }
        }
        if (interpreted.needsMetricsGuard) {
          listeners |= BrotherDiagnosticListener.metrics;
        }
      }
    }

    final runtimeModes = hasResume
        ? phase.possibleRuntimeModes
        : <BrotherRuntimeMode>[phase.runtimeMode];
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
          final target = interpreted.targetRuntime;
          if (target.usesAppGravity) {
            listeners |= BrotherDiagnosticListener.appGravity;
          }
          if (target.waitsForSourceChange && _supportsProposedRotation) {
            listeners |= BrotherDiagnosticListener.proposedSystem;
          }
          if (target.needsMetricsGuard) {
            listeners |= BrotherDiagnosticListener.metrics;
          }
          if (!target.executable) {
            notes.add(
              '${interpreted.targetPhase.runtimeMode.desc}：首页无执行器',
            );
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
          ? '${phase.runtimeLatchAxis.desc}→${_modeLabel(plan, phase, phase.runtimeLatchMode, true)}'
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
  ) => mode == null ? '沿用默认' : _modeLabel(plan, phase, mode, appPhase);

  static String _modeLabel(
    BrotherOrientationPlan plan,
    BrotherPhaseConfig phase,
    BrotherRuntimeMode mode,
    bool appPhase,
  ) {
    final candidate = phase.copyWith(runtimeMode: mode);
    for (final mask in _possibleAllowedMasks(plan, phase)) {
      if (OrientationPolicy.interpretBrotherRuntime(
        candidate,
        allowedMask: mask,
        appPhase: appPhase,
      ).executable) {
        return mode.desc;
      }
    }
    return '${mode.desc}（首页无效）';
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
      '${phase.allowedBasis.desc}；最终许可=${_maskLabel(plan.effectiveFinalMask)}',
    BrotherAllowedBasis.entryExact =>
      '${phase.allowedBasis.desc}；最终许可=${_maskLabel(plan.effectiveFinalMask)}',
  };

  static String _maskLabel(int mask) {
    if (mask == 0) return '空集';
    if (mask == OrientationMask.all) return '全部';
    return [
      if (mask & OrientationMask.portraitUp != 0) '正竖',
      if (mask & OrientationMask.portraitDown != 0) '倒竖',
      if (mask & OrientationMask.landscapeLeft != 0) '左横',
      if (mask & OrientationMask.landscapeRight != 0) '右横',
    ].join('、');
  }
}

/// C only. It renders B'' and contains no policy inference.
abstract final class BrotherOrientationDiagnostics {
  static String describe(BrotherDiagnosticsSnapshot snapshot) {
    final lines = <String>[
      for (final phase in snapshot.phases) _phaseLine(phase),
      '触发监听候选：${_listeners(snapshot.triggerListeners)}',
      if (snapshot.triggerNotes.isNotEmpty)
        '触发解释：${snapshot.triggerNotes.join('、')}',
      '监听器均按实际生命周期与需求动态启停，无轮询；“候选”表示该编译结果在对应运行路径可能启用，不等于当前时刻常驻。',
    ];
    return lines.join('\n');
  }

  static String _phaseLine(BrotherPhaseDiagnostics phase) {
    final resume = phase.resumeLandscapeRuntime == null
        ? ''
        : '；横屏返回=${phase.resumeLandscapeRuntime}；竖屏返回=${phase.resumePortraitRuntime}';
    final latch = phase.latch == null
        ? ''
        : '；一次性切换=${phase.latch}；条件监听=${phase.latchListening ? "界面Metrics（命中后立即注销）" : "0"}';
    final note = phase.notes.isEmpty ? '' : '；解释=${phase.notes.join('、')}';
    return '${phase.name}：默认=${phase.defaultRuntime}$resume；许可=${phase.allowed}；常规运行监听候选=${_listeners(phase.runtimeListeners)}$latch$note';
  }

  static String _listeners(int mask) {
    final values = <String>[
      if (mask & BrotherDiagnosticListener.metrics != 0)
        '方向许可Metrics守卫',
      if (mask & BrotherDiagnosticListener.proposedSystem != 0)
        '系统建议方向',
      if (mask & BrotherDiagnosticListener.appGravity != 0) 'APP重力',
    ];
    return values.isEmpty ? '0' : values.join('、');
  }
}
