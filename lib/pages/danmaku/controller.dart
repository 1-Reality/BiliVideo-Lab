import 'dart:async' show unawaited;
import 'dart:collection';
import 'dart:io' show File;
import 'dart:math' show log;

import 'package:PiliBro/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliBro/grpc/dm.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/plugin/pl_player/controller.dart';
import 'package:PiliBro/plugin/pl_player/models/data_source.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/danmaku_merge/models.dart';
import 'package:PiliBro/utils/danmaku_merge/worker_client.dart';
import 'package:PiliBro/utils/danmaku_utils.dart';
import 'package:PiliBro/utils/path_utils.dart';
import 'package:PiliBro/utils/storage_pref.dart';
import 'package:PiliBro/utils/utils.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;

class PlDanmakuController {
  PlDanmakuController(
    this._cid,
    this._plPlayerController,
    this._isFileSource,
  ) : _mergeDanmaku = _plPlayerController.mergeDanmaku {
    // 与第一段弹幕请求并行拉起合并 isolate
    if (_mergeDanmaku) unawaited(_mergeWorker.warmUp());
  }

  final int _cid;
  final PlPlayerController _plPlayerController;
  final bool _mergeDanmaku;
  final bool _isFileSource;

  late final _isLogin = Accounts.main.isLogin;

  final Map<int, List<DanmakuElem>> _dmSegMap = HashMap();
  // 已请求的段落标记
  late final Set<int> _requestedSeg = HashSet();

  static const int segmentLength = 360000;
  static const int segmentBuckets = 3600;
  int _segmentIndex = -1;
  int _segmentStartBucket = 0;
  int _segmentEndBucket = 0;

  // 以下仅在开启合并弹幕时使用，关闭时一个都不会被创建
  late final _rawSeg = HashMap<int, List<DanmakuElem>>();
  late final _mergeStarted = HashSet<int>();
  late final _mergeWorker = DanmakuMergeWorkerClient(
    dictionaryLoader: rootBundle.loadString,
  );
  late final _mergeWindowMs = Pref.mergeDanmakuWindowSeconds * 1000;
  late final _mergeConfig = DanmakuMergeConfig(
    enabled: true,
    windowMs: _mergeWindowMs,
    maxDistance: Pref.mergeDanmakuMaxDistance,
    maxCosine: Pref.mergeDanmakuMaxCosine,
    representativePercent: Pref.mergeDanmakuRepresentativePercent,
    usePinyin: Pref.mergeDanmakuUsePinyin,
    crossMode: Pref.mergeDanmakuCrossMode,
    skipSubtitle: Pref.mergeDanmakuSkipSubtitle,
    skipAdvanced: Pref.mergeDanmakuSkipAdvanced,
    skipBottom: Pref.mergeDanmakuSkipBottom,
  );
  // 字号 = 15 * log(count) / log(底)，count 超过门槛才放大，15 即全局基准字号
  late final bool _enlarge = Pref.danmakuEnlarge;
  late final int _enlargeThreshold = Pref.danmakuEnlargeThreshold;
  late final double _enlargeK = 15 / log(Pref.danmakuEnlargeLogBase);
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    if (_mergeDanmaku) {
      _mergeWorker.dispose();
      _rawSeg.clear();
      _mergeStarted.clear();
    }
    _dmSegMap.clear();
    _requestedSeg.clear();
  }

  Future<void> queryDanmaku(int segmentIndex) async {
    if (_isFileSource) {
      return;
    }
    if (_requestedSeg.contains(segmentIndex)) {
      return;
    }
    _requestedSeg.add(segmentIndex);
    final res = await DmGrpc.dmSegMobile(
      cid: _cid,
      segmentIndex: segmentIndex + 1,
    );

    if (res case Success(:final response)) {
      if (response.state == 1) {
        _plPlayerController.dmState.add(_cid);
      }
      if (_mergeDanmaku) {
        _storeRaw(segmentIndex, response.elems);
      } else {
        handleDanmaku(response.elems);
      }
    } else {
      // 后继段拿不到时，前一段不再等它，直接合并
      if (_mergeDanmaku && segmentIndex > 0) {
        unawaited(_mergeSegment(segmentIndex - 1, force: true));
      }
      _requestedSeg.remove(segmentIndex);
    }
  }

  int? get _lastSegment {
    final seconds = _plPlayerController.duration.value;
    return seconds > 0 ? (seconds * 1000 - 1) ~/ segmentLength : null;
  }

  // 合并一段需要它的后继段（簇会跨段），所以先存原始数据，后继到了再合并。
  // 空段也要入表：它是"后继已就绪"的信号
  void _storeRaw(int segmentIndex, List<DanmakuElem> elems) {
    if (_isLogin) {
      for (final element in elems) {
        element.isSelf = element.midHash == _plPlayerController.midHash;
      }
    }
    _rawSeg[segmentIndex] = elems;
    if (segmentIndex > 0) {
      unawaited(_mergeSegment(segmentIndex - 1));
    }
    unawaited(_mergeSegment(segmentIndex));
  }

  Future<void> _mergeSegment(int segmentIndex, {bool force = false}) async {
    final current = _rawSeg[segmentIndex];
    if (current == null || _mergeStarted.contains(segmentIndex)) return;
    final next = _rawSeg[segmentIndex + 1];
    if (!force &&
        next == null &&
        !_isFileSource &&
        segmentIndex != _lastSegment) {
      return;
    }
    _mergeStarted.add(segmentIndex);
    if (current.isEmpty) {
      _rawSeg.remove(segmentIndex);
      return;
    }

    var lastProgress = 0;
    for (final element in current) {
      if (element.progress > lastProgress) lastProgress = element.progress;
    }
    final prefixEnd = lastProgress + _mergeWindowMs;
    try {
      final merged = await _mergeWorker.mergeSegment(
        segmentIndex: segmentIndex,
        config: _mergeConfig,
        currentSegment: current,
        nextSegmentPrefix: next == null
            ? const []
            : next.where((e) => e.progress < prefixEnd).toList(growable: false),
      );
      if (_disposed) return;
      handleDanmaku(merged);
    } catch (e, s) {
      Utils.reportError(e, s);
      if (!_disposed) handleDanmaku(current);
    } finally {
      _rawSeg.remove(segmentIndex);
    }
  }

  void handleDanmaku(List<DanmakuElem> elems) {
    if (elems.isEmpty) return;

    final filters = _plPlayerController.filters;
    final shouldFilter = filters.count != 0;
    for (final element in elems) {
      if (_isLogin && !_mergeDanmaku) {
        element.isSelf = element.midHash == _plPlayerController.midHash;
      }

      if (!element.isSelf && shouldFilter && filters.remove(element)) {
        continue;
      }

      if (_mergeDanmaku && element.count > 1) {
        element.fontsize = _enlarge && element.count > _enlargeThreshold
            ? (log(element.count) * _enlargeK).round()
            : 15;
      }

      final int pos = element.progress ~/ 100; //每0.1秒存储一次
      (_dmSegMap[pos] ??= []).add(element);
    }
  }

  List<DanmakuElem>? getCurrentDanmakuAtBucket(int bucket) {
    if (_isFileSource) {
      initFileDmIfNeeded();
    } else {
      if (bucket < _segmentStartBucket || bucket >= _segmentEndBucket) {
        _segmentIndex = bucket ~/ segmentBuckets;
        _segmentStartBucket = _segmentIndex * segmentBuckets;
        _segmentEndBucket = _segmentStartBucket + segmentBuckets;
        if (_mergeDanmaku) {
          // 合并需要后继段：当前段先请求，再提前请求后面两段
          final last = _lastSegment;
          for (var i = _segmentIndex; i <= _segmentIndex + 2; i++) {
            if (last == null || i <= last) unawaited(queryDanmaku(i));
          }
        }
      }
      if (!_requestedSeg.contains(_segmentIndex)) {
        queryDanmaku(_segmentIndex);
        return null;
      }
    }
    return _dmSegMap[bucket];
  }

  bool _fileDmLoaded = false;

  void initFileDmIfNeeded() {
    if (_fileDmLoaded) return;
    _fileDmLoaded = true;
    _initFileDm();
  }

  @pragma('vm:notify-debugger-on-exception')
  Future<void> _initFileDm() async {
    try {
      final file = File(
        path.join(
          (_plPlayerController.dataSource as FileSource).dir,
          PathUtils.danmakuName,
        ),
      );
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final elem = DmSegMobileReply.fromBuffer(bytes).elems;
      if (_mergeDanmaku) {
        _storeRaw(0, elem);
      } else {
        handleDanmaku(elem);
      }
    } catch (e, s) {
      Utils.reportError(e, s);
    }
  }
}
