// Inspired by the existing danmaku merge pipeline.
// This file defines isolate-safe request/response payloads.

import 'dart:isolate';

import 'package:PiliBro/utils/danmaku_merge/models.dart';

class DanmakuMergeTaskPayload {
  const DanmakuMergeTaskPayload({
    required this.taskId,
    required this.segmentIndex,
    required this.config,
    required this.currentSegment,
    required this.nextSegmentPrefix,
  });

  final int taskId;
  final int segmentIndex;
  final DanmakuMergeConfig config;
  final TransferableTypedData currentSegment;
  final TransferableTypedData nextSegmentPrefix;

  Map<String, Object?> toMessage() {
    return <String, Object?>{
      'type': 'task',
      'taskId': taskId,
      'segmentIndex': segmentIndex,
      'config': _configToMessage(config),
      'currentSegment': currentSegment,
      'nextSegmentPrefix': nextSegmentPrefix,
    };
  }

  static DanmakuMergeTaskPayload fromMessage(Map<Object?, Object?> message) {
    return DanmakuMergeTaskPayload(
      taskId: message['taskId']! as int,
      segmentIndex: message['segmentIndex']! as int,
      config: _configFromMessage(message['config']! as Map<Object?, Object?>),
      currentSegment:
          message['currentSegment']! as TransferableTypedData,
      nextSegmentPrefix:
          message['nextSegmentPrefix']! as TransferableTypedData,
    );
  }

  static Map<String, Object?> _configToMessage(DanmakuMergeConfig config) {
    return <String, Object?>{
      'enabled': config.enabled,
      'windowMs': config.windowMs,
      'maxDistance': config.maxDistance,
      'maxCosine': config.maxCosine,
      'representativePercent': config.representativePercent,
      'usePinyin': config.usePinyin,
      'crossMode': config.crossMode,
      'skipSubtitle': config.skipSubtitle,
      'skipAdvanced': config.skipAdvanced,
      'skipBottom': config.skipBottom,
    };
  }

  static DanmakuMergeConfig _configFromMessage(Map<Object?, Object?> message) {
    return DanmakuMergeConfig(
      enabled: message['enabled']! as bool,
      windowMs: message['windowMs']! as int,
      maxDistance: message['maxDistance']! as int,
      maxCosine: message['maxCosine']! as int,
      representativePercent: message['representativePercent']! as int,
      usePinyin: message['usePinyin']! as bool,
      crossMode: message['crossMode']! as bool,
      skipSubtitle: message['skipSubtitle']! as bool,
      skipAdvanced: message['skipAdvanced']! as bool,
      skipBottom: message['skipBottom']! as bool,
    );
  }
}

class DanmakuMergeResultPayload {
  const DanmakuMergeResultPayload({
    required this.taskId,
    required this.segmentIndex,
    required this.mergedSegment,
  });

  final int taskId;
  final int segmentIndex;
  final TransferableTypedData mergedSegment;

  Map<String, Object?> toMessage() {
    return <String, Object?>{
      'type': 'result',
      'taskId': taskId,
      'segmentIndex': segmentIndex,
      'mergedSegment': mergedSegment,
    };
  }

  static DanmakuMergeResultPayload fromMessage(Map<Object?, Object?> message) {
    return DanmakuMergeResultPayload(
      taskId: message['taskId']! as int,
      segmentIndex: message['segmentIndex']! as int,
      mergedSegment: message['mergedSegment']! as TransferableTypedData,
    );
  }
}

class DanmakuMergeErrorPayload {
  const DanmakuMergeErrorPayload({
    required this.taskId,
    required this.message,
    required this.stackTrace,
  });

  final int taskId;
  final String message;
  final String stackTrace;

  Map<String, Object?> toMessage() {
    return <String, Object?>{
      'type': 'error',
      'taskId': taskId,
      'message': message,
      'stackTrace': stackTrace,
    };
  }
}