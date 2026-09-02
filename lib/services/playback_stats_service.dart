import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' show max, min;

import 'package:PiliBro/utils/storage.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';

abstract final class PlaybackStatsService {
  static const schemaVersion = 5;
  static const metricDefinitionVersion = 3;
  static const storageLayoutVersion = 2;
  static const _seekThresholdUs = 1000000;
  static const _rewindEligibilityUs = 5000000;
  static const _flushInterval = Duration(minutes: 2);

  static final _clock = Stopwatch()..start();
  static Map<String, dynamic>? _stats;
  static Timer? _flushTimer;
  static Future<void> _writeChain = Future.value();
  static bool _dirty = false;
  static bool _snapshotting = false;
  static int _monthStamp = -1;
  static String _cachedMonthKey = '';
  static final Set<String> _dirtyKeys = {};
  static final Set<String> _dirtyMonths = {};
  static final Set<String> _dirtyVideoUpUids = {};
  static final Set<String> _dirtyLiveUids = {};
  static final Set<String> _dirtyDimensions = {};
  static final Set<String> _dirtyCrossDimensions = {};
  static final Set<String> _legacyCompositeKeys = {};
  static const _monthPrefix = '@month:';
  static const _videoUpPrefix = '@videoUp:';
  static const _livePrefix = '@live:';
  static const _dimensionPrefix = '@dimension:';
  static const _crossDimensionPrefix = '@crossDimension:';
  static const _compositeKeys = {
    'months',
    'videoByUpUid',
    'liveByUid',
    'dimensions',
    'crossDimensions',
  };
  static AppLifecycleListener? _appLifecycleListener;
  static bool _appForeground = false;
  static int _appLastWallUs = 0;
  static String _pageCategory = 'other';
  static int _pageLastWallUs = 0;

  static final NavigatorObserver pageRouteObserver =
      PlaybackPageRouteObserver();
  static final _trailingZeros = RegExp(r'0+$');
  static final _trailingDot = RegExp(r'\.$');

  static bool _active = false;
  static bool _live = false;
  static bool _playing = false;
  static bool _buffering = false;
  static bool _completedIdle = false;
  static bool _videoCommentPanelVisible = false;
  static int _commentPanelLastWallUs = 0;
  static String? _mediaKey;
  static String? _liveUid;
  static String? _liveName;
  static String? _videoUpUid;
  static String? _videoUpName;
  static bool _videoUpStartRecorded = false;
  static int _lastWallUs = 0;
  static int _lastPositionUs = 0;
  static int _suppressDiscontinuityUntilUs = 0;
  static int? _pendingPositionUs;
  static double _rate = 1;
  static String _rateKey = '1';
  static double _nominalRate = 1;
  static bool _temporaryRate = false;
  static double _defaultRate = 1;
  static _RewindEpisode? _rewind;
  static int _trailingPauseUs = 0;
  static int _trailingNormalPauseUs = 0;
  static int _trailingRewindPauseUs = 0;
  static final Map<String, int> _trailingNormalPauseBySpeed = {};
  static final Map<String, int> _trailingRewindPauseBySpeed = {};
  static int _sourceDurationUs = 0;
  static int _sessionActiveUs = 0;
  static int _sessionMediaAdvanceUs = 0;
  static double _sessionNominalMediaUs = 0;
  static double _sessionNominalIncludingLongPressUs = 0;
  static int _sessionPausedUs = 0;
  static int _sessionBufferingUs = 0;
  static int _sessionUniqueCoveredUs = 0;
  static int _sessionRepeatCoveredUs = 0;
  static int _sessionMaxPositionUs = 0;
  static bool _sessionCompleted = false;
  static bool _videoSessionOpen = false;
  static final List<({int start, int end})> _coveredIntervals = [];
  static String _orientation = 'unknown';
  static String _contentType = 'ugc';
  static String _partitionId = 'unknown';
  static String _partitionName = '未知分区';
  static String _codec = 'unknown';
  static String _quality = 'unknown';
  static String _network = 'unknown';
  static String _playbackForm = 'window';
  static String _subtitle = 'unknown';
  static String _danmaku = 'unknown';
  static String _copyright = 'unknown';
  static String _decoder = 'unknown';
  static Map<String, String>? _dimensionAxesCache;
  static int _dimensionAxesCacheVersion = -1;
  static int _dimensionAxesCacheTimeKey = -1;
  static int _dimensionAxesCacheOffsetMinutes = 0;
  static int _dimensionContextVersion = 0;

  static void initializeAppLifecycle() {
    _ensureInitialized();
    if (_appLifecycleListener != null) return;
    final now = _clock.elapsedMicroseconds;
    _appLastWallUs = now;
    _pageLastWallUs = now;
    _commentPanelLastWallUs = now;
    _appForeground = WidgetsBinding.instance.lifecycleState == .resumed;
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        final now = _clock.elapsedMicroseconds;
        _settleAppForeground(now);
        _settlePageDwell(now);
        _settleCommentPanel(now);
        _appForeground = state == .resumed;
        if (!_appForeground) unawaited(flush());
      },
    );
  }

  static void _ensureInitialized() {
    if (_stats != null) return;
    _stats = _loadStatsFromStorage();
    _stats!.putIfAbsent(
      'nominalMediaIncludingLongPressUs',
      () => _stats!['nominalMediaUs'] as num? ?? 0,
    );
    _stats!['schemaVersion'] = schemaVersion;
    _stats!['metricDefinitionVersion'] = metricDefinitionVersion;
    _stats!['storageLayoutVersion'] = storageLayoutVersion;
    _dirtyKeys.addAll(const [
      'schemaVersion',
      'metricDefinitionVersion',
      'storageLayoutVersion',
    ]);
    _queueLegacyCompositeMigration();
    _flushTimer ??= Timer.periodic(
      _flushInterval,
      (_) => flush(),
    );
  }

  static Map<String, dynamic> _stringMap(Map raw) => raw.map(
    (key, value) => MapEntry(
      key.toString(),
      value is Map ? _stringMap(value) : value,
    ),
  );

  // Statistics stay in this process for their whole lifetime. Hive values are
  // normalized when loading, so copying a nested record for every position
  // callback only creates garbage and makes old months cost more than new
  // ones. Convert legacy maps once; mutate normalized records in place.
  static Map<String, dynamic> _mutableMap(dynamic value) =>
      value is Map<String, dynamic>
      ? value
      : value is Map
      ? _stringMap(value)
      : <String, dynamic>{};

  static Map<String, dynamic> _loadStatsFromStorage() {
    final raw = GStorage.playbackStats.toMap();
    if (raw.isEmpty) {
      return <String, dynamic>{
        'schemaVersion': schemaVersion,
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      };
    }
    final data = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      if (!_isShardKey(key)) data[key] = entry.value;
    }
    Map<String, dynamic> composite(String key) {
      final current = data[key];
      final value = current is Map
          ? _stringMap(current)
          : <String, dynamic>{};
      data[key] = value;
      return value;
    }

    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (key.startsWith(_monthPrefix)) {
        final shard = key.substring(_monthPrefix.length);
        final separator = shard.indexOf(':');
        if (separator > 0) {
          final month = shard.substring(0, separator);
          final field = shard.substring(separator + 1);
          final months = composite('months');
          final monthValue = months[month] is Map
              ? _stringMap(months[month] as Map)
              : <String, dynamic>{};
          monthValue[field] = value is Map ? _stringMap(value) : value;
          months[month] = monthValue;
        } else if (value is Map) {
          composite('months')[shard] = _stringMap(value);
        }
      } else if (key.startsWith(_videoUpPrefix) && value is Map) {
        composite('videoByUpUid')[key.substring(_videoUpPrefix.length)] =
            _stringMap(value);
      } else if (key.startsWith(_livePrefix) && value is Map) {
        composite('liveByUid')[key.substring(_livePrefix.length)] =
            _stringMap(value);
      } else if (key.startsWith(_dimensionPrefix) && value is Map) {
        _restoreNestedShard(
          composite('dimensions'),
          key.substring(_dimensionPrefix.length),
          value,
        );
      } else if (key.startsWith(_crossDimensionPrefix) && value is Map) {
        _restoreNestedShard(
          composite('crossDimensions'),
          key.substring(_crossDimensionPrefix.length),
          value,
        );
      }
    }
    return data;
  }

  static bool _isShardKey(String key) =>
      key.startsWith(_monthPrefix) ||
      key.startsWith(_videoUpPrefix) ||
      key.startsWith(_livePrefix) ||
      key.startsWith(_dimensionPrefix) ||
      key.startsWith(_crossDimensionPrefix);

  static void _restoreNestedShard(
    Map<String, dynamic> target,
    String shard,
    Map value,
  ) {
    final separator = shard.indexOf(':');
    if (separator <= 0) return;
    final axis = shard.substring(0, separator);
    final axisValue = shard.substring(separator + 1);
    final values = target[axis] is Map
        ? _stringMap(target[axis] as Map)
        : <String, dynamic>{};
    values[axisValue] = _stringMap(value);
    target[axis] = values;
  }

  static void _queueLegacyCompositeMigration() {
    for (final key in _compositeKeys) {
      if (!GStorage.playbackStats.containsKey(key)) continue;
      _legacyCompositeKeys.add(key);
      final value = _stats![key];
      if (value is! Map) continue;
      switch (key) {
        case 'months':
          for (final month in value.entries) {
            if (month.value is Map) {
              _dirtyMonths.addAll(
                (month.value as Map).keys.map(
                  (field) => '${month.key}:$field',
                ),
              );
            }
          }
        case 'videoByUpUid':
          _dirtyVideoUpUids.addAll(value.keys.map((item) => item.toString()));
        case 'liveByUid':
          _dirtyLiveUids.addAll(value.keys.map((item) => item.toString()));
        case 'dimensions':
          for (final axis in value.entries) {
            if (axis.value is Map) {
              _dirtyDimensions.addAll(
                (axis.value as Map).keys.map(
                  (item) => '${axis.key}:$item',
                ),
              );
            }
          }
        case 'crossDimensions':
          for (final axis in value.entries) {
            if (axis.value is Map) {
              _dirtyCrossDimensions.addAll(
                (axis.value as Map).keys.map(
                  (item) => '${axis.key}:$item',
                ),
              );
            }
          }
      }
    }
    if (_legacyCompositeKeys.isNotEmpty) _dirty = true;
  }

  static void _add(String key, num value) {
    if (value == 0) return;
    final current = _stats![key] as num? ?? 0;
    _stats![key] = value is double || current is double
        ? current.toDouble() + value
        : current.toInt() + value.toInt();
    _markDirty(key);
    _addMonthValue(key, value);
  }

  static void _markDirty(String key) {
    _dirty = true;
    _dirtyKeys.add(key);
  }

  static void _markMonthDirty(String field, [String? month]) {
    _dirty = true;
    _dirtyMonths.add('${month ?? _monthKey}:$field');
  }

  static void _markVideoUpDirty(String uid) {
    _dirty = true;
    _dirtyVideoUpUids.add(uid);
  }

  static void _markLiveDirty(String uid) {
    _dirty = true;
    _dirtyLiveUids.add(uid);
  }

  static void _markDimensionDirty(
    String axis,
    String value, {
    bool cross = false,
  }) {
    _dirty = true;
    (cross ? _dirtyCrossDimensions : _dirtyDimensions).add('$axis:$value');
  }

  static String get _monthKey {
    final now = DateTime.now();
    final stamp = now.year * 12 + now.month;
    if (stamp != _monthStamp) {
      _monthStamp = stamp;
      _cachedMonthKey = _monthKeyFor(now);
    }
    return _cachedMonthKey;
  }

  static String _monthKeyFor(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}';

  static void _addMonthValue(String key, num value) {
    if (value == 0 || key == 'months') return;
    final months = _map('months');
    final monthKey = _monthKey;
    final month = _mutableMap(months[monthKey]);
    final current = month[key] as num? ?? 0;
    month[key] = value is double || current is double
        ? current.toDouble() + value
        : current.toInt() + value.toInt();
    months[monthKey] = month;
    _markMonthDirty(key);
  }

  static void _settleAppForeground(int now) {
    if (_appForeground) _add('appForegroundUs', max(0, now - _appLastWallUs));
    _appLastWallUs = now;
  }

  static void _settlePageDwell(int now) {
    if (_appForeground) {
      final elapsed = max(0, now - _pageLastWallUs);
      _add('pageForegroundUs', elapsed);
      _addBucket('pageDwellUs', _pageCategory, elapsed);
    }
    _pageLastWallUs = now;
  }

  static void _settleCommentPanel(int now) {
    final elapsed = max(0, now - _commentPanelLastWallUs);
    if (_appForeground && _active && !_live && _videoCommentPanelVisible) {
      _add('commentPanelForegroundUs', elapsed);
      _addVideoUp('commentPanelForegroundUs', elapsed);
      _addDimension('commentPanelForegroundUs', elapsed);
    }
    _commentPanelLastWallUs = now;
  }

  static void setVideoCommentPanelVisible(bool visible) {
    _ensureInitialized();
    if (_videoCommentPanelVisible == visible) return;
    final now = _clock.elapsedMicroseconds;
    _settleCommentPanel(now);
    _videoCommentPanelVisible = visible;
    _commentPanelLastWallUs = now;
  }

  static void _onPageRouteChanged(String? routeName) {
    if (!GStorage.playbackStatsReady) {
      _pageCategory = _routeCategory(routeName);
      return;
    }
    _ensureInitialized();
    final now = _clock.elapsedMicroseconds;
    _settlePageDwell(now);
    _pageCategory = _routeCategory(routeName);
  }

  static String _routeCategory(String? routeName) {
    return switch (routeName) {
      '/videoV' => 'video',
      '/liveRoom' => 'live',
      '/audio' || '/musicDetail' => 'audio',
      '/' || '/home' || '/hot' || '/popularSeries' || '/popularPrecious' =>
        'feed',
      '/dynamics' || '/dynamicDetail' || '/dynTopic' || '/dynTopicRcmd' =>
        'dynamics',
      final name? when name.toLowerCase().contains('search') => 'search',
      '/whisper' ||
      '/whisperDetail' ||
      '/replyMe' ||
      '/atMe' ||
      '/likeMe' ||
      '/sysMsg' ||
      '/msgLikeDetail' ||
      '/commentHelper' => 'messages',
      '/mainReply' || '/myReply' => 'comments',
      '/member' ||
      '/memberDynamics' ||
      '/follow' ||
      '/fan' ||
      '/followed' ||
      '/sameFollowing' ||
      '/editProfile' => 'profile',
      '/fav' ||
      '/favDetail' ||
      '/later' ||
      '/history' ||
      '/download' ||
      '/subscription' ||
      '/subDetail' => 'library',
      '/setting' ||
      '/cdnSettings' ||
      '/playSpeedSet' ||
      '/networkPolicy' ||
      '/playbackStats' ||
      '/trafficStats' ||
      '/colorSetting' ||
      '/fontSetting' ||
      '/displayModeSetting' ||
      '/barSetting' ||
      '/spaceSetting' ||
      '/settingsSearch' ||
      '/danmakuBlock' ||
      '/sponsorBlock' => 'settings',
      '/articlePage' || '/articleList' => 'article',
      _ => 'other',
    };
  }

  static Map<String, dynamic> _map(String key) {
    final current = _stats![key];
    final value = _mutableMap(current);
    _stats![key] = value;
    return value;
  }

  static void _addBucket(String key, String bucket, num value) {
    if (value == 0) return;
    final map = _map(key);
    final current = map[bucket] as num? ?? 0;
    map[bucket] = value is double || current is double
        ? current.toDouble() + value
        : current.toInt() + value.toInt();
    _markDirty(key);
    final months = _map('months');
    final monthKey = _monthKey;
    final month = _mutableMap(months[monthKey]);
    final monthBuckets = _mutableMap(month[key]);
    monthBuckets[bucket] = (monthBuckets[bucket] as num? ?? 0) + value;
    month[key] = monthBuckets;
    months[monthKey] = month;
    _markMonthDirty(key);
  }

  static void _addVideoUp(String key, num value) {
    final uid = _videoUpUid;
    if (uid == null || value == 0) return;
    final name = _videoUpName;
    final byUid = _map('videoByUpUid');
    final item = _mutableMap(byUid[uid]);
    if (name?.isNotEmpty == true) {
      item['name'] = name;
    }
    item[key] = (item[key] as num? ?? 0) + value;
    final months = _mutableMap(item['months']);
    final monthKey = _monthKey;
    final monthItem = _mutableMap(months[monthKey]);
    monthItem[key] = (monthItem[key] as num? ?? 0) + value;
    if (name?.isNotEmpty == true) {
      monthItem['name'] = name;
    }
    months[monthKey] = monthItem;
    item['months'] = months;
    byUid[uid] = item;
    _markVideoUpDirty(uid);
  }

  static void _addVideoUpBucket(String key, String bucket, num value) {
    final uid = _videoUpUid;
    if (uid == null || value == 0) return;
    final byUid = _map('videoByUpUid');
    final item = _mutableMap(byUid[uid]);
    final buckets = _mutableMap(item[key]);
    buckets[bucket] = (buckets[bucket] as num? ?? 0) + value;
    item[key] = buckets;
    final months = _mutableMap(item['months']);
    final monthKey = _monthKey;
    final monthItem = _mutableMap(months[monthKey]);
    final monthBuckets = _mutableMap(monthItem[key]);
    monthBuckets[bucket] = (monthBuckets[bucket] as num? ?? 0) + value;
    monthItem[key] = monthBuckets;
    months[monthKey] = monthItem;
    item['months'] = months;
    byUid[uid] = item;
    _markVideoUpDirty(uid);
  }

  static void _recordVideoUpStart() {
    if (_videoUpUid == null || _videoUpStartRecorded) return;
    _videoUpStartRecorded = true;
    _addVideoUp('openCount', 1);
    final name = _videoUpName;
    if (name != null && name.isNotEmpty) {
      final uid = _videoUpUid!;
      final byUid = _map('videoByUpUid');
      final item = _mutableMap(byUid[uid]);
      _rememberAlias(item, name);
      byUid[uid] = item;
      _markVideoUpDirty(uid);
    }
  }

  static void _rememberAlias(Map<String, dynamic> item, String name) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final aliases = _mutableMap(item['aliases']);
    final alias = _mutableMap(aliases[name]);
    alias.putIfAbsent('firstSeenAtMs', () => now);
    alias['lastSeenAtMs'] = now;
    aliases[name] = alias;
    item['aliases'] = aliases;
  }

  static String _speedKey(double speed) {
    final text = speed.toStringAsFixed(2);
    return text
        .replaceFirst(_trailingZeros, '')
        .replaceFirst(_trailingDot, '');
  }

  static void _recordSourceSpeed(double speed, double defaultSpeed) {
    final key = _speedKey(speed);
    _addBucket('sourceSpeedSelections', key, 1);
    if ((speed - defaultSpeed).abs() < 0.001) {
      _addBucket('defaultSpeedSelections', key, 1);
    }
    _stats!['lastSelectedSpeed'] = speed;
    _markDirty('lastSelectedSpeed');
  }

  static void _addLiveMonth(Map<String, dynamic> item, String key, num value) {
    final months = _mutableMap(item['months']);
    final monthKey = _monthKey;
    final month = _mutableMap(months[monthKey]);
    month[key] = (month[key] as num? ?? 0) + value;
    if (_liveName case final name? when name.isNotEmpty) month['name'] = name;
    months[monthKey] = month;
    item['months'] = months;
  }

  static void _addDimension(
    String primitive,
    num value, {
    String? speed,
  }) {
    if (value == 0) return;
    final now = DateTime.now();
    final axes = _dimensionAxes(now);
    final dimensions = _map('dimensions');
    final monthKey = _monthKeyFor(now);
    for (final axis in axes.entries) {
      final values = _mutableMap(dimensions[axis.key]);
      final item = _mutableMap(values[axis.value]);
      item[primitive] = (item[primitive] as num? ?? 0) + value;
      final months = _mutableMap(item['months']);
      final month = _mutableMap(months[monthKey]);
      month[primitive] = (month[primitive] as num? ?? 0) + value;
      months[monthKey] = month;
      item['months'] = months;
      values[axis.value] = item;
      dimensions[axis.key] = values;
      _markDimensionDirty(axis.key, axis.value);
    }
    if (speed != null) {
      final crosses = _map('crossDimensions');
      final month = _monthKey;
      _addCrossDimensionValue(
        crosses,
        'upSpeed',
        '${_videoUpUid ?? 'unknown'}|$speed',
        month,
        primitive,
        value,
      );
      _addCrossDimensionValue(
        crosses,
        'partitionSpeed',
        '$_partitionId|$speed',
        month,
        primitive,
        value,
      );
      _addCrossDimensionValue(
        crosses,
        'orientationSpeed',
        '$_orientation|$speed',
        month,
        primitive,
        value,
      );
    }
  }

  static void _addCrossDimensionValue(
    Map<String, dynamic> crosses,
    String axis,
    String valueKey,
    String monthKey,
    String primitive,
    num value,
  ) {
    final values = _mutableMap(crosses[axis]);
    final item = _mutableMap(values[valueKey]);
    item[primitive] = (item[primitive] as num? ?? 0) + value;
    final months = _mutableMap(item['months']);
    final month = _mutableMap(months[monthKey]);
    month[primitive] = (month[primitive] as num? ?? 0) + value;
    months[monthKey] = month;
    item['months'] = months;
    values[valueKey] = item;
    crosses[axis] = values;
    _markDimensionDirty(axis, valueKey, cross: true);
  }

  // Position events are the hot path. Four independent calls used to rebuild
  // every axis and recursively copy its month history for the same interval.
  // These four primitives always share one context, month and speed, so update
  // each target exactly once.
  static void _addDimensionPlayback(
    int activePlaybackUs,
    int mediaAdvanceUs,
    num nominalMediaUs,
    num nominalMediaIncludingLongPressUs,
    String speed,
  ) {
    final now = DateTime.now();
    final month = _monthKeyFor(now);
    final axes = _dimensionAxes(now);
    final dimensions = _map('dimensions');
    for (final axis in axes.entries) {
      final values = _mutableMap(dimensions[axis.key]);
      final item = _mutableMap(values[axis.value]);
      final months = _mutableMap(item['months']);
      final current = _mutableMap(months[month]);
      item['activePlaybackUs'] =
          (item['activePlaybackUs'] as num? ?? 0) + activePlaybackUs;
      item['mediaAdvanceUs'] =
          (item['mediaAdvanceUs'] as num? ?? 0) + mediaAdvanceUs;
      item['nominalMediaUs'] =
          (item['nominalMediaUs'] as num? ?? 0) + nominalMediaUs;
      item['nominalMediaIncludingLongPressUs'] =
          (item['nominalMediaIncludingLongPressUs'] as num? ?? 0) +
          nominalMediaIncludingLongPressUs;
      current['activePlaybackUs'] =
          (current['activePlaybackUs'] as num? ?? 0) + activePlaybackUs;
      current['mediaAdvanceUs'] =
          (current['mediaAdvanceUs'] as num? ?? 0) + mediaAdvanceUs;
      current['nominalMediaUs'] =
          (current['nominalMediaUs'] as num? ?? 0) + nominalMediaUs;
      current['nominalMediaIncludingLongPressUs'] =
          (current['nominalMediaIncludingLongPressUs'] as num? ?? 0) +
          nominalMediaIncludingLongPressUs;
      months[month] = current;
      item['months'] = months;
      values[axis.value] = item;
      dimensions[axis.key] = values;
      _markDimensionDirty(axis.key, axis.value);
    }
    final crosses = _map('crossDimensions');
    _addCrossDimensionPlayback(
      crosses,
      'upSpeed',
      '${_videoUpUid ?? 'unknown'}|$speed',
      month,
      activePlaybackUs,
      mediaAdvanceUs,
    );
    _addCrossDimensionPlayback(
      crosses,
      'partitionSpeed',
      '$_partitionId|$speed',
      month,
      activePlaybackUs,
      mediaAdvanceUs,
    );
    _addCrossDimensionPlayback(
      crosses,
      'orientationSpeed',
      '$_orientation|$speed',
      month,
      activePlaybackUs,
      mediaAdvanceUs,
    );
  }

  static void _addCrossDimensionPlayback(
    Map<String, dynamic> crosses,
    String axis,
    String valueKey,
    String monthKey,
    int activePlaybackUs,
    int mediaAdvanceUs,
  ) {
    final values = _mutableMap(crosses[axis]);
    final item = _mutableMap(values[valueKey]);
    final months = _mutableMap(item['months']);
    final month = _mutableMap(months[monthKey]);
    item['activePlaybackUs'] =
        (item['activePlaybackUs'] as num? ?? 0) + activePlaybackUs;
    item['mediaAdvanceUs'] =
        (item['mediaAdvanceUs'] as num? ?? 0) + mediaAdvanceUs;
    month['activePlaybackUs'] =
        (month['activePlaybackUs'] as num? ?? 0) + activePlaybackUs;
    month['mediaAdvanceUs'] =
        (month['mediaAdvanceUs'] as num? ?? 0) + mediaAdvanceUs;
    months[monthKey] = month;
    item['months'] = months;
    values[valueKey] = item;
    crosses[axis] = values;
    _markDimensionDirty(axis, valueKey, cross: true);
  }

  // Session outcomes have one final content identity. Keep them on dimensions
  // that describe the media itself; network, quality and player UI can change
  // during a session and receive interval primitives instead.
  static void _addStaticSessionDimensions(Map<String, num> primitives) {
    if (primitives.isEmpty) return;
    final now = DateTime.now();
    final month = _monthKeyFor(now);
    final axes = <String, String>{
      'orientation': _orientation,
      'content': _contentType,
      'partition': '$_partitionId:$_partitionName',
      'platform': defaultTargetPlatform.name,
      'duration': _durationBand(_sourceDurationUs),
      'copyright': _copyright,
    };
    final dimensions = _map('dimensions');
    for (final axis in axes.entries) {
      final values = _mutableMap(dimensions[axis.key]);
      final item = _mutableMap(values[axis.value]);
      final months = _mutableMap(item['months']);
      final current = _mutableMap(months[month]);
      for (final primitive in primitives.entries) {
        item[primitive.key] =
            (item[primitive.key] as num? ?? 0) + primitive.value;
        current[primitive.key] =
            (current[primitive.key] as num? ?? 0) + primitive.value;
      }
      months[month] = current;
      item['months'] = months;
      values[axis.value] = item;
      dimensions[axis.key] = values;
      _markDimensionDirty(axis.key, axis.value);
    }
  }

  static Map<String, String> _dimensionAxes(DateTime now) {
    final timeKey =
        (((now.year * 13 + now.month) * 32 + now.day) * 24 + now.hour);
    final offsetMinutes = now.timeZoneOffset.inMinutes;
    final cached = _dimensionAxesCache;
    if (cached != null &&
        _dimensionAxesCacheVersion == _dimensionContextVersion &&
        _dimensionAxesCacheTimeKey == timeKey &&
        _dimensionAxesCacheOffsetMinutes == offsetMinutes) {
      return cached;
    }

    final axes = <String, String>{
      'orientation': _orientation,
      'content': _contentType,
      'partition': '$_partitionId:$_partitionName',
      'codec': _codec,
      'quality': _quality,
      'network': _network,
      'platform': defaultTargetPlatform.name,
      'duration': _durationBand(_sourceDurationUs),
      'playbackForm': _playbackForm,
      'subtitle': _subtitle,
      'danmaku': _danmaku,
      'copyright': _copyright,
      'decoder': _decoder,
      'weekday': now.weekday.toString(),
      'hour': now.hour.toString().padLeft(2, '0'),
      'utcOffsetMinutes': offsetMinutes.toString(),
    };
    _dimensionAxesCache = axes;
    _dimensionAxesCacheVersion = _dimensionContextVersion;
    _dimensionAxesCacheTimeKey = timeKey;
    _dimensionAxesCacheOffsetMinutes = offsetMinutes;
    return axes;
  }

  static String _durationBand(int us) => switch (us) {
    <= 0 => 'unknown',
    < 60_000_000 => '<1m',
    < 300_000_000 => '1-5m',
    < 1_200_000_000 => '5-20m',
    < 3_600_000_000 => '20-60m',
    _ => '>=60m',
  };

  static void openMedia({
    required bool isLive,
    required Duration previousPosition,
    required Duration initialPosition,
    required double speed,
    required double defaultSpeed,
    int? cid,
    int? liveUid,
    int? videoUpUid,
    String? videoUpName,
    String? liveName,
    Duration? sourceDuration,
    String? orientation,
    String? contentType,
    int? partitionId,
    String? partitionName,
    String? codec,
    String? quality,
    String? network,
    String? playbackForm,
    String? subtitle,
    bool? danmakuEnabled,
    String? copyright,
    String? decoder,
  }) {
    _ensureInitialized();
    final now = _clock.elapsedMicroseconds;
    if (_active) {
      if (_live) {
        _settleLive(now);
      } else {
        _settleVideo(previousPosition.inMicroseconds, now);
      }
    }

    final nextKey = isLive
        ? 'live:${liveUid ?? 'unknown'}'
        : cid == null
        ? null
        : 'cid:$cid';
    if (nextKey == null) {
      if (_active && !_live) {
        _reclassifyTrailingPauseAsComment();
        _finalizeVideoSession();
      }
      _finishRewind(now, completed: false);
      _active = false;
      _mediaKey = null;
      _videoUpUid = null;
      _videoUpName = null;
      _videoUpStartRecorded = false;
      return;
    }

    final sameMedia = _active && _live == isLive && _mediaKey == nextKey;
    if (!sameMedia) {
      if (_active && !_live) {
        _reclassifyTrailingPauseAsComment();
        _finalizeVideoSession();
      }
      _finishRewind(now, completed: false);
      if (isLive) {
        _videoUpUid = null;
        _videoUpName = null;
        _videoUpStartRecorded = false;
        _liveUid = liveUid?.toString() ?? 'unknown';
        _liveName = liveName;
        _add('liveOpenCount', 1);
        final byUid = _map('liveByUid');
        final item = _mutableMap(byUid[_liveUid]);
        item['openCount'] = ((item['openCount'] as num?)?.toInt() ?? 0) + 1;
        if (liveName case final name? when name.isNotEmpty) {
          item['name'] = name;
          _rememberAlias(item, name);
        }
        _addLiveMonth(item, 'openCount', 1);
        byUid[_liveUid!] = item;
        _markLiveDirty(_liveUid!);
      } else {
        _liveUid = null;
        _videoUpUid = videoUpUid?.toString();
        _videoUpName = videoUpName;
        _videoUpStartRecorded = false;
        _recordVideoUpStart();
        _add('videoStarts', 1);
        _recordSourceSpeed(speed, defaultSpeed);
        _beginVideoSession(
          initialPosition.inMicroseconds,
          sourceDuration?.inMicroseconds ?? 0,
        );
      }
    } else if (!isLive && _completedIdle) {
      _restartCompletedVideoSession(initialPosition.inMicroseconds, now);
    } else if (!isLive && videoUpUid != null) {
      _videoUpUid = videoUpUid.toString();
      _videoUpName = videoUpName ?? _videoUpName;
      _recordVideoUpStart();
    }

    _active = true;
    _live = isLive;
    _mediaKey = nextKey;
    _playing = false;
    _buffering = true;
    _completedIdle = false;
    _rate = speed;
    _rateKey = _speedKey(speed);
    _nominalRate = speed;
    _temporaryRate = false;
    _defaultRate = defaultSpeed;
    _lastWallUs = now;
    _lastPositionUs = initialPosition.inMicroseconds;
    _commentPanelLastWallUs = now;
    _pendingPositionUs = _lastPositionUs;
    _suppressDiscontinuityUntilUs = now + _rewindEligibilityUs;
    if (!isLive) {
      updateVideoContext(
        sourceDuration: sourceDuration,
        orientation: orientation,
        contentType: contentType,
        partitionId: partitionId,
        partitionName: partitionName,
        codec: codec,
        quality: quality,
        network: network,
        playbackForm: playbackForm,
        subtitle: subtitle,
        danmakuEnabled: danmakuEnabled,
        copyright: copyright,
        decoder: decoder,
      );
    }
  }

  static void updateVideoContext({
    Duration? sourceDuration,
    String? orientation,
    String? contentType,
    int? partitionId,
    String? partitionName,
    String? codec,
    String? quality,
    String? network,
    String? playbackForm,
    String? subtitle,
    bool? danmakuEnabled,
    String? copyright,
    String? decoder,
  }) {
    _ensureInitialized();
    if (!_active || _live) return;
    if (sourceDuration != null && sourceDuration.inMicroseconds > 0) {
      _sourceDurationUs = sourceDuration.inMicroseconds;
    }
    if (orientation != null) _orientation = orientation;
    if (contentType != null) _contentType = contentType;
    if (partitionId != null) _partitionId = partitionId.toString();
    if (partitionName != null && partitionName.isNotEmpty) {
      _partitionName = partitionName;
    }
    if (codec != null) _codec = codec;
    if (quality != null) _quality = quality;
    if (network != null) _network = network;
    if (playbackForm != null) _playbackForm = playbackForm;
    if (subtitle != null) _subtitle = subtitle;
    if (danmakuEnabled != null) _danmaku = danmakuEnabled ? 'on' : 'off';
    if (copyright != null) _copyright = copyright;
    if (decoder != null) _decoder = decoder;
    _dimensionContextVersion++;
  }

  static void updateLiveIdentity({
    int? liveUid,
    String? liveName,
  }) {
    _ensureInitialized();
    if (liveUid != null) _liveUid = liveUid.toString();
    if (liveName == null || liveName.isEmpty) return;
    _liveName = liveName;
    final uid = _liveUid;
    if (uid == null) return;
    final byUid = _map('liveByUid');
    final item = _mutableMap(byUid[uid]);
    item['name'] = liveName;
    _rememberAlias(item, liveName);
    byUid[uid] = item;
    _markLiveDirty(uid);
  }

  static void changePlaybackForm(String form, Duration position) {
    _ensureInitialized();
    if (!_active || _live || form == _playbackForm) return;
    _settleVideo(position.inMicroseconds, _clock.elapsedMicroseconds);
    _playbackForm = form;
    _dimensionContextVersion++;
  }

  static void _beginVideoSession(
    int initialPositionUs,
    int sourceDurationUs, {
    bool resetContext = true,
  }) {
    _videoSessionOpen = true;
    _sourceDurationUs = sourceDurationUs;
    _sessionActiveUs = 0;
    _sessionMediaAdvanceUs = 0;
    _sessionNominalMediaUs = 0;
    _sessionNominalIncludingLongPressUs = 0;
    _sessionPausedUs = 0;
    _sessionBufferingUs = 0;
    _sessionUniqueCoveredUs = 0;
    _sessionRepeatCoveredUs = 0;
    _sessionMaxPositionUs = initialPositionUs;
    _sessionCompleted = false;
    _coveredIntervals.clear();
    _dimensionContextVersion++;
    if (!resetContext) return;
    _orientation = 'unknown';
    _contentType = 'ugc';
    _partitionId = 'unknown';
    _partitionName = '未知分区';
    _codec = 'unknown';
    _quality = 'unknown';
    _network = 'unknown';
    _playbackForm = 'window';
    _subtitle = 'unknown';
    _danmaku = 'unknown';
    _copyright = 'unknown';
    _decoder = 'unknown';
  }

  static void _restartCompletedVideoSession(int positionUs, int now) {
    _finalizeVideoSession();
    _finishRewind(now, completed: false);
    _beginVideoSession(
      positionUs,
      _sourceDurationUs,
      resetContext: false,
    );
    _completedIdle = false;
    _lastPositionUs = positionUs;
    _lastWallUs = now;
    _pendingPositionUs = positionUs;
    _suppressDiscontinuityUntilUs = now + _rewindEligibilityUs;
  }

  static void _recordCoverage(int rawStartUs, int rawEndUs) {
    var start = rawStartUs;
    var end = rawEndUs;
    if (start > end) (start, end) = (end, start);
    if (start < 0) start = 0;
    if (end < 0) end = 0;
    if (_sourceDurationUs > 0) {
      if (start > _sourceDurationUs) start = _sourceDurationUs;
      if (end > _sourceDurationUs) end = _sourceDurationUs;
    }
    if (end <= start) return;

    final covered = _coveredIntervals;
    final span = end - start;
    if (covered.isEmpty) {
      covered.add((start: start, end: end));
      _sessionUniqueCoveredUs += span;
      return;
    }
    final last = covered.last;
    if (start >= last.start) {
      if (start >= last.end) {
        if (start == last.end) {
          covered[covered.length - 1] = (start: last.start, end: end);
        } else {
          covered.add((start: start, end: end));
        }
        _sessionUniqueCoveredUs += span;
        return;
      }
      if (end >= last.end) {
        final unique = end - last.end;
        covered[covered.length - 1] = (start: last.start, end: end);
        _sessionUniqueCoveredUs += unique;
        _sessionRepeatCoveredUs += span - unique;
        return;
      }
    }

    var mergedStart = start;
    var mergedEnd = end;
    var overlap = 0;
    final next = <({int start, int end})>[];
    var inserted = false;
    for (final interval in _coveredIntervals) {
      if (interval.end < mergedStart) {
        next.add(interval);
      } else if (interval.start > mergedEnd) {
        if (!inserted) {
          next.add((start: mergedStart, end: mergedEnd));
          inserted = true;
        }
        next.add(interval);
      } else {
        overlap += max(
          0,
          min(end, interval.end) - max(start, interval.start),
        );
        mergedStart = min(mergedStart, interval.start);
        mergedEnd = max(mergedEnd, interval.end);
      }
    }
    if (!inserted) next.add((start: mergedStart, end: mergedEnd));
    _coveredIntervals
      ..clear()
      ..addAll(next);
    final unique = max(0, span - overlap);
    _sessionUniqueCoveredUs += unique;
    _sessionRepeatCoveredUs += span - unique;
  }

  static void _finalizeVideoSession() {
    if (!_videoSessionOpen) return;
    _videoSessionOpen = false;
    final played = _sessionActiveUs > 0;
    final sessionPrimitives = <String, num>{
      'sessionOpenedCount': 1,
      if (played) 'sessionPlayedCount': 1,
      if (played && _sessionCompleted) 'sessionCompletedCount': 1,
      if (played && !_sessionCompleted) 'sessionEarlyExitCount': 1,
      if (!played && !_sessionCompleted) 'sessionNeverPlayedExitCount': 1,
      if (played && _sourceDurationUs > 0) ...{
        'playedSourceDurationUs': _sourceDurationUs,
        'sessionCoverageRatioSum': _sessionUniqueCoveredUs / _sourceDurationUs,
        'sessionCoverageEligibleCount': 1,
      },
    };
    for (final primitive in sessionPrimitives.entries) {
      _add(primitive.key, primitive.value);
      _addVideoUp(primitive.key, primitive.value);
    }
    _addStaticSessionDimensions(sessionPrimitives);
    if (_sourceDurationUs > 0) {
      _add('openedSourceDurationUs', _sourceDurationUs);
      _addVideoUp('openedSourceDurationUs', _sourceDurationUs);
      _addDimension('openedSourceDurationUs', _sourceDurationUs);
    }
    _add('grossMediaAdvanceUs', _sessionMediaAdvanceUs);
    _add('uniqueCoveredUs', _sessionUniqueCoveredUs);
    _add('repeatCoveredUs', _sessionRepeatCoveredUs);
    _addVideoUp('grossMediaAdvanceUs', _sessionMediaAdvanceUs);
    _addVideoUp('uniqueCoveredUs', _sessionUniqueCoveredUs);
    _addVideoUp('repeatCoveredUs', _sessionRepeatCoveredUs);
    _addDimension('grossMediaAdvanceUs', _sessionMediaAdvanceUs);
    _addDimension('uniqueCoveredUs', _sessionUniqueCoveredUs);
    _addDimension('repeatCoveredUs', _sessionRepeatCoveredUs);

    if (played) {
      final activeScale = 1 / _sessionActiveUs;
      _addHistogram(
        'sessionActualSpeedHistogram',
        _sessionMediaAdvanceUs * activeScale,
        const [0.75, 1, 1.25, 1.5, 2, 2.5, 3, 4],
      );
      _addHistogram(
        'sessionNominalSpeedHistogram',
        _sessionNominalMediaUs * activeScale,
        const [0.75, 1, 1.25, 1.5, 2, 2.5, 3, 4],
      );
      _addHistogram(
        'sessionNominalLongPressSpeedHistogram',
        _sessionNominalIncludingLongPressUs * activeScale,
        const [0.75, 1, 1.25, 1.5, 2, 2.5, 3, 4],
      );
    }
    if (_sourceDurationUs > 0) {
      final sourceDurationScale = 1 / _sourceDurationUs;
      _addHistogram(
        'sessionCoverageHistogram',
        _sessionUniqueCoveredUs * sourceDurationScale,
        const [0.1, 0.25, 0.5, 0.75, 0.9, 0.99],
      );
      _addHistogram(
        'sessionExitPositionHistogram',
        _sessionMaxPositionUs * sourceDurationScale,
        const [0.1, 0.25, 0.5, 0.75, 0.9, 0.99],
      );
    }
    if (_sessionMediaAdvanceUs > 0) {
      _addHistogram(
        'sessionRepeatRatioHistogram',
        _sessionRepeatCoveredUs / _sessionMediaAdvanceUs,
        const [0.01, 0.05, 0.1, 0.25, 0.5],
      );
    }
    _addHistogram(
      'sessionWatchDurationHistogram',
      _sessionActiveUs * 0.000001,
      const [60, 300, 1200, 3600, 7200],
    );
    if (_sourceDurationUs > 0) {
      _addHistogram(
        'sessionSourceDurationHistogram',
        _sourceDurationUs * 0.000001,
        const [60, 300, 1200, 3600, 7200],
      );
    }
    _addBucket(
      'sessionOutcomeCounts',
      _sessionCompleted ? 'completed' : 'earlyExit',
      1,
    );
    _coveredIntervals.clear();
  }

  static void _addHistogram(
    String key,
    double value,
    List<num> upperBounds,
  ) {
    if (!value.isFinite || value < 0) return;
    String bucket = '>${upperBounds.last}';
    num lower = 0;
    for (final upper in upperBounds) {
      if (value <= upper) {
        bucket = '$lower-$upper';
        break;
      }
      lower = upper;
    }
    _addBucket(key, bucket, 1);
  }

  static void setVideoUpUid({
    required int cid,
    required int? videoUpUid,
    String? videoUpName,
  }) {
    _ensureInitialized();
    if (!_active || _live || _mediaKey != 'cid:$cid' || videoUpUid == null) {
      return;
    }
    _videoUpUid = videoUpUid.toString();
    _videoUpName = videoUpName ?? _videoUpName;
    _recordVideoUpStart();
  }

  static void samplePosition(Duration position) {
    _ensureInitialized();
    if (!_active || _live) return;
    _settleVideo(position.inMicroseconds, _clock.elapsedMicroseconds);
  }

  static void updatePlaying(bool playing, Duration position) {
    _ensureInitialized();
    final now = _clock.elapsedMicroseconds;
    if (_active) {
      if (_live) {
        _settleLive(now);
      } else {
        _settleVideo(position.inMicroseconds, now);
        if (_completedIdle && playing) {
          _restartCompletedVideoSession(position.inMicroseconds, now);
        }
      }
      if (playing != _playing) {
        if (playing) {
          _clearTrailingPause();
          _add('playbackSegments', 1);
        } else if (!_completedIdle) {
          _add('pauseCount', 1);
          _addVideoUp('pauseCount', 1);
        }
      }
    }
    if (playing) _completedIdle = false;
    _playing = playing;
  }

  static void updateBuffering(bool buffering, Duration position) {
    _ensureInitialized();
    final now = _clock.elapsedMicroseconds;
    if (_active) {
      if (_live) {
        _settleLive(now);
      } else {
        _settleVideo(position.inMicroseconds, now);
        if (_completedIdle && buffering) {
          _restartCompletedVideoSession(position.inMicroseconds, now);
        }
      }
      if (buffering && !_buffering) {
        _add('bufferingCount', 1);
        _addVideoUp('bufferingCount', 1);
      }
    }
    _buffering = buffering;
  }

  static void changeSpeed(
    double speed,
    Duration position, {
    required bool recordSelection,
    bool temporary = false,
  }) {
    _ensureInitialized();
    if (_active && !_live) {
      _settleVideo(position.inMicroseconds, _clock.elapsedMicroseconds);
      if (recordSelection) {
        final key = _speedKey(speed);
        _addBucket('manualSpeedSelections', key, 1);
        _stats!['lastSelectedSpeed'] = speed;
        _add('rateChangeCount', 1);
        _addVideoUp('rateChangeCount', 1);
        _markDirty('lastSelectedSpeed');
      }
      if (temporary && !_temporaryRate) {
        _add('longPressCount', 1);
        _addVideoUp('longPressCount', 1);
      }
    }
    _rate = speed;
    _rateKey = _speedKey(speed);
    _temporaryRate = temporary;
    if (!temporary) _nominalRate = speed;
  }

  static void seek(
    Duration from,
    Duration to, {
    required bool userInitiated,
  }) {
    _ensureInitialized();
    if (!_active || _live) return;
    final now = _clock.elapsedMicroseconds;
    _settleVideo(from.inMicroseconds, now);
    if (_completedIdle) {
      _restartCompletedVideoSession(to.inMicroseconds, now);
      return;
    }
    _completedIdle = false;
    if (userInitiated) {
      _recordSeek(from.inMicroseconds, to.inMicroseconds, now);
    } else {
      _finishRewind(now, completed: false);
    }
    _sessionMaxPositionUs = max(_sessionMaxPositionUs, to.inMicroseconds);
    _lastPositionUs = to.inMicroseconds;
    _lastWallUs = now;
    _pendingPositionUs = _lastPositionUs;
    _suppressDiscontinuityUntilUs = now + 2000000;
  }

  static void rebase(Duration position) {
    _ensureInitialized();
    if (!_active || _live) return;
    final now = _clock.elapsedMicroseconds;
    _settleVideo(position.inMicroseconds, now);
    _lastPositionUs = position.inMicroseconds;
    _lastWallUs = now;
    _pendingPositionUs = _lastPositionUs;
    _suppressDiscontinuityUntilUs = now + 2000000;
  }

  static void markCompleted(Duration position) {
    _ensureInitialized();
    if (!_active || _live || _completedIdle) return;
    _settleVideo(position.inMicroseconds, _clock.elapsedMicroseconds);
    _reclassifyTrailingPauseAsComment();
    _add('completedVideos', 1);
    _addVideoUp('completedCount', 1);
    _sessionCompleted = true;
    _completedIdle = true;
  }

  static void endMedia(Duration position) {
    _ensureInitialized();
    if (!_active) return;
    final now = _clock.elapsedMicroseconds;
    if (_live) {
      _settleLive(now);
    } else {
      _settleVideo(position.inMicroseconds, now);
      _reclassifyTrailingPauseAsComment();
      _finalizeVideoSession();
    }
    _finishRewind(now, completed: false);
    _active = false;
    _mediaKey = null;
    _liveUid = null;
    _liveName = null;
    _videoUpUid = null;
    _videoUpName = null;
    _videoUpStartRecorded = false;
    _pendingPositionUs = null;
    unawaited(flush());
  }

  static void endMediaIfMatches({
    required bool isLive,
    required Duration position,
    int? cid,
    int? liveUid,
  }) {
    _ensureInitialized();
    final key = isLive
        ? 'live:${liveUid ?? 'unknown'}'
        : cid == null
        ? null
        : 'cid:$cid';
    if (_active && _live == isLive && _mediaKey == key) {
      endMedia(position);
    }
  }

  static void _settleLive(int now) {
    if (!_active || !_live) return;
    final elapsed = max(0, now - _lastWallUs);
    if (elapsed > 0) {
      _add('liveWatchUs', elapsed);
      final uid = _liveUid;
      if (uid != null) {
        final byUid = _map('liveByUid');
        final item = _mutableMap(byUid[uid]);
        item['watchUs'] = ((item['watchUs'] as num?) ?? 0).toInt() + elapsed;
        if (_liveName case final name? when name.isNotEmpty) item['name'] = name;
        _addLiveMonth(item, 'watchUs', elapsed);
        byUid[uid] = item;
        _markLiveDirty(uid);
      }
    }
    _lastWallUs = now;
  }

  static void _settleVideo(int positionUs, int now) {
    if (!_active || _live) return;
    _settleCommentPanel(now);
    final wallUs = max(0, now - _lastWallUs);
    final mediaDeltaUs = positionUs - _lastPositionUs;
    if (_pendingPositionUs case final target?) {
      if (now >= _suppressDiscontinuityUntilUs) {
        _pendingPositionUs = null;
      } else if ((positionUs - target).abs() > _seekThresholdUs) {
        // Some backends briefly publish the pre-seek position. Do not turn
        // that stale sample into a completed rewind or a second seek.
        _lastWallUs = now;
        return;
      } else {
        _pendingPositionUs = null;
      }
    }

    if (_completedIdle) {
      // Waiting on an already completed video is neither playback nor pause.
      _add('commentAreaUs', wallUs);
      _addVideoUp('commentAreaUs', wallUs);
      _addDimension('commentAreaUs', wallUs);
    } else if (_buffering) {
      _sessionBufferingUs += wallUs;
      _add('bufferingUs', wallUs);
      _addVideoUp('bufferingUs', wallUs);
      _addDimension('bufferingUs', wallUs);
      final rewind = _rewind;
      final speed = _rateKey;
      if (rewind == null) {
        _add('normalBufferingUs', wallUs);
        _addVideoUp('normalBufferingUs', wallUs);
        _addBucket('normalSpeedBufferingUs', speed, wallUs);
        _addVideoUpBucket('normalSpeedBufferingUs', speed, wallUs);
      } else {
        _add('rewindBufferingUs', wallUs);
        _addVideoUp('rewindBufferingUs', wallUs);
        _addBucket('rewindSpeedBufferingUs', speed, wallUs);
        _addVideoUpBucket('rewindSpeedBufferingUs', speed, wallUs);
        rewind.bufferingUs += wallUs;
      }
    } else if (_playing) {
      final speed = _rateKey;
      final nominalMediaUs = wallUs * _nominalRate;
      final rateMediaUs = wallUs * _rate;
      _add('activePlaybackUs', wallUs);
      _addVideoUp('activePlaybackUs', wallUs);
      _add('nominalMediaUs', nominalMediaUs);
      _add('nominalMediaIncludingLongPressUs', rateMediaUs);
      _addVideoUp('nominalMediaUs', nominalMediaUs);
      _addVideoUp('nominalMediaIncludingLongPressUs', rateMediaUs);
      _addBucket('speedActiveUs', speed, wallUs);
      _addVideoUpBucket('speedActiveUs', speed, wallUs);
      if (_temporaryRate) {
        _add('longPressActiveUs', wallUs);
        _addBucket('longPressSpeedActiveUs', speed, wallUs);
        _addVideoUp('longPressActiveUs', wallUs);
        _addVideoUpBucket('longPressSpeedActiveUs', speed, wallUs);
      }

      final toleranceUs = max(2000000, rateMediaUs * 2).round();
      final discontinuity =
          mediaDeltaUs < -_seekThresholdUs ||
          mediaDeltaUs > rateMediaUs + toleranceUs;
      int mediaAdvanceUs;
      var rewindPlaybackUs = 0;
      var rewindMediaAdvanceUs = 0;
      if (discontinuity) {
        mediaAdvanceUs = now < _suppressDiscontinuityUntilUs
            ? 0
            : min(max(0, mediaDeltaUs), rateMediaUs.round());
        final rewindPart = _advanceRewind(
          _lastPositionUs,
          _lastPositionUs + mediaAdvanceUs,
          wallUs,
          now,
        );
        rewindPlaybackUs = rewindPart.playbackUs;
        rewindMediaAdvanceUs = rewindPart.mediaAdvanceUs;
        if (now >= _suppressDiscontinuityUntilUs) {
          _add('detectedDiscontinuityCount', 1);
          _recordSeek(_lastPositionUs, positionUs, now);
        }
      } else {
        mediaAdvanceUs = max(0, mediaDeltaUs);
        final rewindPart = _advanceRewind(
          _lastPositionUs,
          positionUs,
          wallUs,
          now,
        );
        rewindPlaybackUs = rewindPart.playbackUs;
        rewindMediaAdvanceUs = rewindPart.mediaAdvanceUs;
      }
      _add('mediaAdvanceUs', mediaAdvanceUs);
      _addVideoUp('mediaAdvanceUs', mediaAdvanceUs);
      _sessionActiveUs += wallUs;
      _sessionMediaAdvanceUs += mediaAdvanceUs;
      _sessionNominalMediaUs += nominalMediaUs;
      _sessionNominalIncludingLongPressUs += rateMediaUs;
      _sessionMaxPositionUs = max(_sessionMaxPositionUs, positionUs);
      _recordCoverage(
        _lastPositionUs,
        _lastPositionUs + mediaAdvanceUs,
      );
      final normalPlaybackUs = wallUs - rewindPlaybackUs;
      final normalMediaAdvanceUs = mediaAdvanceUs - rewindMediaAdvanceUs;
      _addBucket('speedMediaAdvanceUs', speed, mediaAdvanceUs);
      _add('rewindPlaybackUs', rewindPlaybackUs);
      _add('rewindMediaAdvanceUs', rewindMediaAdvanceUs);
      _add('normalPlaybackUs', normalPlaybackUs);
      _add('normalMediaAdvanceUs', normalMediaAdvanceUs);
      _addVideoUp('rewindPlaybackUs', rewindPlaybackUs);
      _addVideoUp('rewindMediaAdvanceUs', rewindMediaAdvanceUs);
      _addVideoUp('normalPlaybackUs', normalPlaybackUs);
      _addVideoUp('normalMediaAdvanceUs', normalMediaAdvanceUs);
      _addDimensionPlayback(
        wallUs,
        mediaAdvanceUs,
        nominalMediaUs,
        rateMediaUs,
        speed,
      );
      _addBucket(
        'rewindSpeedActiveUs',
        speed,
        rewindPlaybackUs,
      );
      _addBucket(
        'rewindSpeedMediaAdvanceUs',
        speed,
        rewindMediaAdvanceUs,
      );
      _addBucket(
        'normalSpeedActiveUs',
        speed,
        normalPlaybackUs,
      );
      _addBucket(
        'normalSpeedMediaAdvanceUs',
        speed,
        normalMediaAdvanceUs,
      );
    } else {
      _sessionPausedUs += wallUs;
      _add('pausedUs', wallUs);
      _addVideoUp('pausedUs', wallUs);
      _addDimension('pausedUs', wallUs);
      _trailingPauseUs += wallUs;
      final rewind = _rewind;
      final speed = _rateKey;
      if (rewind == null) {
        _add('normalPausedUs', wallUs);
        _addVideoUp('normalPausedUs', wallUs);
        _addBucket('normalSpeedPausedUs', speed, wallUs);
        _addVideoUpBucket('normalSpeedPausedUs', speed, wallUs);
        _trailingNormalPauseUs += wallUs;
        _trailingNormalPauseBySpeed.update(
          speed,
          (value) => value + wallUs,
          ifAbsent: () => wallUs,
        );
      } else {
        _add('rewindPausedUs', wallUs);
        _addVideoUp('rewindPausedUs', wallUs);
        _addBucket('rewindSpeedPausedUs', speed, wallUs);
        _addVideoUpBucket('rewindSpeedPausedUs', speed, wallUs);
        _trailingRewindPauseUs += wallUs;
        _trailingRewindPauseBySpeed.update(
          speed,
          (value) => value + wallUs,
          ifAbsent: () => wallUs,
        );
        rewind.pausedUs += wallUs;
      }
    }

    _lastWallUs = now;
    _lastPositionUs = positionUs;
  }

  // A trailing pause is provisional: if playback resumes, it remains pause time.
  // Only when this media session ends without any later resume do we
  // retrospectively classify that final pause as comment-area time.
  static void _clearTrailingPause() {
    _trailingPauseUs = 0;
    _trailingNormalPauseUs = 0;
    _trailingRewindPauseUs = 0;
    _trailingNormalPauseBySpeed.clear();
    _trailingRewindPauseBySpeed.clear();
  }

  // Called only when the current CID/BV lifecycle is being finalized.
  // Because updatePlaying(true) clears the trailing-pause accumulator, any
  // duration reaching here is exactly: paused, then never played again.
  static void _reclassifyTrailingPauseAsComment() {
    if (_trailingPauseUs == 0) return;
    _add('pausedUs', -_trailingPauseUs);
    _addVideoUp('pausedUs', -_trailingPauseUs);
    _addDimension('pausedUs', -_trailingPauseUs);
    _add('commentAreaUs', _trailingPauseUs);
    _addVideoUp('commentAreaUs', _trailingPauseUs);
    _addDimension('commentAreaUs', _trailingPauseUs);
    _add('normalPausedUs', -_trailingNormalPauseUs);
    _add('rewindPausedUs', -_trailingRewindPauseUs);
    _addVideoUp('normalPausedUs', -_trailingNormalPauseUs);
    _addVideoUp('rewindPausedUs', -_trailingRewindPauseUs);
    _sessionPausedUs = max(0, _sessionPausedUs - _trailingPauseUs);
    for (final entry in _trailingNormalPauseBySpeed.entries) {
      _addBucket('normalSpeedPausedUs', entry.key, -entry.value);
      _addVideoUpBucket('normalSpeedPausedUs', entry.key, -entry.value);
    }
    for (final entry in _trailingRewindPauseBySpeed.entries) {
      _addBucket('rewindSpeedPausedUs', entry.key, -entry.value);
      _addVideoUpBucket('rewindSpeedPausedUs', entry.key, -entry.value);
    }
    final rewind = _rewind;
    if (rewind != null) {
      rewind.pausedUs = max(0, rewind.pausedUs - _trailingRewindPauseUs);
    }
    _clearTrailingPause();
  }

  static void _recordSeek(int fromUs, int toUs, int now) {
    final delta = toUs - fromUs;
    if (delta.abs() < _seekThresholdUs) return;
    _finishRewind(now, completed: false);
    if (delta > 0) {
      _add('forwardSeekCount', 1);
      _add('forwardSeekUs', delta);
      _addVideoUp('forwardSeekCount', 1);
      _addVideoUp('forwardSeekUs', delta);
      return;
    }

    final distance = -delta;
    _add('rewindCount', 1);
    _add('rewindUs', distance);
    _addVideoUp('rewindCount', 1);
    _addVideoUp('rewindUs', distance);
    if (_rate > 1) {
      _add('fastRewindCount', 1);
      _add('fastRewindUs', distance);
      _addVideoUp('fastRewindCount', 1);
      _addVideoUp('fastRewindUs', distance);
    }
    _rewind = _RewindEpisode(
      checkpointUs: fromUs,
      distanceUs: distance,
      startedAtUs: now,
    );
  }

  static ({int playbackUs, int mediaAdvanceUs}) _advanceRewind(
    int fromUs,
    int toUs,
    int activeWallUs,
    int now,
  ) {
    final rewind = _rewind;
    if (rewind == null) return (playbackUs: 0, mediaAdvanceUs: 0);
    if (fromUs >= rewind.checkpointUs) {
      _finishRewind(now, completed: true);
      return (playbackUs: 0, mediaAdvanceUs: 0);
    }
    final mediaAdvanceUs = max(0, toUs - fromUs);
    if (toUs >= rewind.checkpointUs && toUs > fromUs) {
      final fraction = (rewind.checkpointUs - fromUs) / mediaAdvanceUs;
      final playbackUs = (activeWallUs * fraction.clamp(0, 1)).round();
      final rewindMediaUs = rewind.checkpointUs - fromUs;
      rewind
        ..activePlaybackUs += playbackUs
        ..mediaAdvanceUs += rewindMediaUs;
      _finishRewind(now, completed: true);
      return (playbackUs: playbackUs, mediaAdvanceUs: rewindMediaUs);
    } else {
      rewind
        ..activePlaybackUs += activeWallUs
        ..mediaAdvanceUs += mediaAdvanceUs;
      return (playbackUs: activeWallUs, mediaAdvanceUs: mediaAdvanceUs);
    }
  }

  static void _finishRewind(int now, {required bool completed}) {
    final rewind = _rewind;
    if (rewind == null) return;
    final eligible =
        completed || now - rewind.startedAtUs >= _rewindEligibilityUs;
    if (eligible) {
      _add('eligibleRewindCount', 1);
      _addVideoUp('eligibleRewindCount', 1);
      if (completed) {
        _add('completedRewindCount', 1);
        _add('completedRewindUs', rewind.distanceUs);
        _add('completedRewindPlaybackUs', rewind.activePlaybackUs);
        _add('completedRewindMediaAdvanceUs', rewind.mediaAdvanceUs);
        _add('completedRewindPausedUs', rewind.pausedUs);
        _add('completedRewindBufferingUs', rewind.bufferingUs);
        _addVideoUp('completedRewindCount', 1);
        _addVideoUp('completedRewindUs', rewind.distanceUs);
        _addVideoUp('completedRewindPlaybackUs', rewind.activePlaybackUs);
        _addVideoUp('completedRewindMediaAdvanceUs', rewind.mediaAdvanceUs);
        _addVideoUp('completedRewindPausedUs', rewind.pausedUs);
        _addVideoUp('completedRewindBufferingUs', rewind.bufferingUs);
      } else {
        _add('abandonedRewindCount', 1);
        _add('abandonedRewindUs', rewind.distanceUs);
        _add('abandonedRewindPlaybackUs', rewind.activePlaybackUs);
        _add('abandonedRewindMediaAdvanceUs', rewind.mediaAdvanceUs);
        _add('abandonedRewindPausedUs', rewind.pausedUs);
        _add('abandonedRewindBufferingUs', rewind.bufferingUs);
        _addVideoUp('abandonedRewindCount', 1);
        _addVideoUp('abandonedRewindUs', rewind.distanceUs);
        _addVideoUp('abandonedRewindPlaybackUs', rewind.activePlaybackUs);
        _addVideoUp('abandonedRewindMediaAdvanceUs', rewind.mediaAdvanceUs);
        _addVideoUp('abandonedRewindPausedUs', rewind.pausedUs);
        _addVideoUp('abandonedRewindBufferingUs', rewind.bufferingUs);
      }
    } else {
      _add('shortRewindExitCount', 1);
      _add('shortRewindUs', rewind.distanceUs);
      _add('shortRewindPlaybackUs', rewind.activePlaybackUs);
      _add('shortRewindMediaAdvanceUs', rewind.mediaAdvanceUs);
      _add('shortRewindPausedUs', rewind.pausedUs);
      _add('shortRewindBufferingUs', rewind.bufferingUs);
      _addVideoUp('shortRewindExitCount', 1);
      _addVideoUp('shortRewindUs', rewind.distanceUs);
      _addVideoUp('shortRewindPlaybackUs', rewind.activePlaybackUs);
      _addVideoUp('shortRewindMediaAdvanceUs', rewind.mediaAdvanceUs);
      _addVideoUp('shortRewindPausedUs', rewind.pausedUs);
      _addVideoUp('shortRewindBufferingUs', rewind.bufferingUs);
    }
    _rewind = null;
    _pendingPositionUs = null;
  }

  static Map<String, dynamic> snapshot() {
    _ensureInitialized();
    final now = _clock.elapsedMicroseconds;
    _settleAppForeground(now);
    _settlePageDwell(now);
    _settleCommentPanel(now);
    if (_active && _live) _settleLive(now);
    final raw = Map<String, dynamic>.from(_stats!);
    final source = _numericMap(raw['sourceSpeedSelections']);
    final manual = _numericMap(raw['manualSpeedSelections']);
    final selections = <String, num>{...source};
    for (final entry in manual.entries) {
      selections.update(
        entry.key,
        (value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    final last = (raw['lastSelectedSpeed'] as num?)?.toDouble();
    final rankedSpeeds = selections.entries
        .map((entry) => (speed: double.tryParse(entry.key), count: entry.value))
        .where((entry) => entry.speed != null)
        .toList()
      ..sort((a, b) {
        final count = b.count.compareTo(a.count);
        if (count != 0) return count;
        if (last != null) {
          final aLast = (a.speed! - last).abs() < 0.001;
          final bLast = (b.speed! - last).abs() < 0.001;
          if (aLast != bLast) return aLast ? -1 : 1;
        }
        return b.speed!.compareTo(a.speed!);
      });
    final favorite = rankedSpeeds.isEmpty ? null : rankedSpeeds.first.speed;

    final active = _number(raw['activePlaybackUs']);
    final media = _number(raw['mediaAdvanceUs']);
    final paused = _number(raw['pausedUs']);
    final buffering = _number(raw['bufferingUs']);
    final observed = active + paused + buffering;
    final uniqueCovered = _number(raw['uniqueCoveredUs']);
    final sourceDuration = _number(raw['openedSourceDurationUs']);
    final nominal = _number(raw['nominalMediaUs']);
    final nominalIncludingLongPress = _number(
      raw['nominalMediaIncludingLongPressUs'],
    );
    final eligible = _number(raw['eligibleRewindCount']);
    final completed = _number(raw['completedRewindCount']);
    final rewindMedia = _number(raw['completedRewindUs']);
    final rewindWall = _number(raw['completedRewindPlaybackUs']);
    final normalWall = _number(raw['normalPlaybackUs']);
    final normalMedia = _number(raw['normalMediaAdvanceUs']);
    final allRewindWall = _number(raw['rewindPlaybackUs']);
    final allRewindMedia = _number(raw['rewindMediaAdvanceUs']);
    final rewindObserved =
        allRewindWall +
        _number(raw['rewindPausedUs']) +
        _number(raw['rewindBufferingUs']);
    final completedRewindObserved =
        rewindWall +
        _number(raw['completedRewindPausedUs']) +
        _number(raw['completedRewindBufferingUs']);
    final openedSessions = _number(raw['sessionOpenedCount']);
    final playedSessions = _number(raw['sessionPlayedCount']);
    final completedSessions = _number(raw['sessionCompletedCount']);
    final coverageSessions = _number(raw['sessionCoverageEligibleCount']);
    final activeScale = active == 0 ? 0 : 1 / active;
    raw['derived'] = {
      'favoriteSpeed': favorite,
      'favoriteSpeeds': [for (final item in rankedSpeeds.take(5)) item.speed],
      'favoriteSpeedWasDefault':
          favorite != null &&
          (_numericMap(
                    raw['defaultSpeedSelections'],
                  )[_speedKey(favorite)] ??
                  0) >
              0,
      'actualAverageSpeed': media * activeScale,
      'newContentEquivalentSpeed': uniqueCovered * activeScale,
      'observedEquivalentSpeed': observed == 0 ? 0 : media / observed,
      'repeatRatio': media == 0 ? 0 : _number(raw['repeatCoveredUs']) / media,
      'coverageRatio': sourceDuration == 0 ? 0 : uniqueCovered / sourceDuration,
      'videoCompletionRate': playedSessions == 0
          ? 0
          : completedSessions / playedSessions,
      'videoOpenCompletionRate': openedSessions == 0
          ? 0
          : completedSessions / openedSessions,
      'averageSessionCoverageRatio': coverageSessions == 0
          ? 0
          : _number(raw['sessionCoverageRatioSum']) / coverageSessions,
      'nominalAverageSpeed': nominal * activeScale,
      'nominalAverageSpeedIncludingLongPress':
          nominalIncludingLongPress * activeScale,
      'savedTimeUs': media - active,
      'normalSavedTimeUs': normalMedia - normalWall,
      'rewindSavedTimeUs': allRewindMedia - allRewindWall,
      'rewindCompletionRate': eligible == 0 ? 0 : completed / eligible,
      'rewindEquivalentSpeed': rewindWall == 0 ? 0 : rewindMedia / rewindWall,
      'rewindObservedEquivalentSpeed': completedRewindObserved == 0
          ? 0
          : rewindMedia / completedRewindObserved,
      'normalObservedUs':
          normalWall +
          _number(raw['normalPausedUs']) +
          _number(raw['normalBufferingUs']),
      'rewindObservedUs': rewindObserved,
      'playerObservedUs': observed,
      'speedSelectionCounts': selections,
    };
    return raw;
  }

  static Map<String, num> _numericMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value is num ? value : 0),
    );
  }

  static num _number(dynamic value) => value is num ? value : 0;

  static String advancedJson() {
    final data = snapshot();
    final derived = data.remove('derived');
    return const JsonEncoder.withIndent('  ').convert({
      '说明': {
        'schemaVersion': schemaVersion,
        'timeUnit': 'microseconds',
        'savedTime': 'mediaAdvanceUs - activePlaybackUs；不包含快进跳转',
        'normalSavedTime': 'normalMediaAdvanceUs - normalPlaybackUs',
        'rewindSavedTime': 'rewindMediaAdvanceUs - rewindPlaybackUs',
        'actualAverageSpeed': 'mediaAdvanceUs / activePlaybackUs',
        'nominalAverageSpeed':
            'nominalMediaUs / activePlaybackUs；临时长按期间仍按长按前的基础倍速积分',
        'nominalAverageSpeedIncludingLongPress':
            'nominalMediaIncludingLongPressUs / activePlaybackUs',
        'appForegroundTime': 'appForegroundUs；使用单调时钟累计应用处于前台的时间',
        'rewindEquivalentSpeed':
            'completedRewindUs / completedRewindPlaybackUs；分子为原视频时间，分母为实际播放时间',
        'rewindObservedEquivalentSpeed': 'completedRewindUs /（completedRewindPlaybackUs + completedRewindPausedUs + completedRewindBufferingUs）；用于回看包含暂停与缓冲在内的真实时间成本',
        'rewindCompletionRate':
            'completedRewindCount / eligibleRewindCount；完成或倒带后停留至少 5 秒才进入分母',
        'videoCompletionRate':
            'sessionCompletedCount / sessionPlayedCount；只把至少产生过实际播放时间的会话放入分母',
        'videoOpenCompletionRate':
            'sessionCompletedCount / sessionOpenedCount；从加载媒体开始计算',
        'averageSessionCoverageRatio':
            'sessionCoverageRatioSum / sessionCoverageEligibleCount；每次有效会话等权，不被长视频额外放大',
        'stateAxes': '普通观看／倒带重看 × 播放／暂停／缓冲 × 当前倍速；临时长按、评论标签实际前台停留、播后或终止暂停停留、去重覆盖、快进跳转、倒带结果，以及按月份、视频 UP、直播主播、页面、分区、横竖屏、编码、清晰度、网络和播放形态等维度汇总的数据另行保存',
      },
      '原语': data,
      '当前推导值': derived,
    });
  }

  static Map<String, dynamic> _storageCopy(Map value) =>
      (jsonDecode(jsonEncode(value)) as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );

  static Map<String, dynamic>? _nestedShardValue(
    String rootKey,
    String shard,
  ) {
    final separator = shard.indexOf(':');
    if (separator <= 0) return null;
    final axis = shard.substring(0, separator);
    final axisValue = shard.substring(separator + 1);
    final root = _stats![rootKey];
    if (root is! Map || root[axis] is! Map) return null;
    final value = (root[axis] as Map)[axisValue];
    return value is Map ? _storageCopy(value) : null;
  }

  static Future<void> flush({bool force = false}) async {
    if (_snapshotting && !force) return;
    _ensureInitialized();
    final now = _clock.elapsedMicroseconds;
    _settleAppForeground(now);
    _settlePageDwell(now);
    _settleCommentPanel(now);
    if (_active && _live) _settleLive(now);
    if (!_dirty) return;
    _stats!['updatedAtMs'] = DateTime.now().millisecondsSinceEpoch;
    _dirtyKeys.add('updatedAtMs');
    final keys = Set<String>.of(_dirtyKeys)
      ..removeAll(_compositeKeys);
    final months = Set<String>.of(_dirtyMonths);
    final videoUpUids = Set<String>.of(_dirtyVideoUpUids);
    final liveUids = Set<String>.of(_dirtyLiveUids);
    final dimensions = Set<String>.of(_dirtyDimensions);
    final crossDimensions = Set<String>.of(_dirtyCrossDimensions);
    final legacyKeys = Set<String>.of(_legacyCompositeKeys);
    final writes = <dynamic, dynamic>{
      for (final key in keys) key: _stats![key],
    };
    final monthMap = _stats!['months'];
    if (monthMap is Map) {
      for (final shard in months) {
        final separator = shard.indexOf(':');
        if (separator <= 0) continue;
        final month = shard.substring(0, separator);
        final field = shard.substring(separator + 1);
        final value = monthMap[month] is Map
            ? (monthMap[month] as Map)[field]
            : null;
        if (value != null) {
          writes['$_monthPrefix$shard'] = value is Map
              ? _storageCopy(value)
              : value;
        }
      }
    }
    final byUp = _stats!['videoByUpUid'];
    if (byUp is Map) {
      for (final uid in videoUpUids) {
        final value = byUp[uid];
        if (value is Map) writes['$_videoUpPrefix$uid'] = _storageCopy(value);
      }
    }
    final byLive = _stats!['liveByUid'];
    if (byLive is Map) {
      for (final uid in liveUids) {
        final value = byLive[uid];
        if (value is Map) writes['$_livePrefix$uid'] = _storageCopy(value);
      }
    }
    for (final shard in dimensions) {
      if (_nestedShardValue('dimensions', shard) case final value?) {
        writes['$_dimensionPrefix$shard'] = value;
      }
    }
    for (final shard in crossDimensions) {
      if (_nestedShardValue('crossDimensions', shard) case final value?) {
        writes['$_crossDimensionPrefix$shard'] = value;
      }
    }
    _dirty = false;
    _dirtyKeys.removeAll(keys);
    _dirtyMonths.removeAll(months);
    _dirtyVideoUpUids.removeAll(videoUpUids);
    _dirtyLiveUids.removeAll(liveUids);
    _dirtyDimensions.removeAll(dimensions);
    _dirtyCrossDimensions.removeAll(crossDimensions);
    _legacyCompositeKeys.removeAll(legacyKeys);
    Future<void> write(dynamic _) async {
      if (writes.isNotEmpty) await GStorage.playbackStats.putAll(writes);
      if (legacyKeys.isNotEmpty) {
        await GStorage.playbackStats.deleteAll(legacyKeys);
      }
    }
    _writeChain = _writeChain.then(write, onError: write);
    try {
      await _writeChain;
    } catch (_) {
      _dirty = true;
      _dirtyKeys.addAll(keys);
      _dirtyMonths.addAll(months);
      _dirtyVideoUpUids.addAll(videoUpUids);
      _dirtyLiveUids.addAll(liveUids);
      _dirtyDimensions.addAll(dimensions);
      _dirtyCrossDimensions.addAll(crossDimensions);
      _legacyCompositeKeys.addAll(legacyKeys);
      rethrow;
    }
  }

  static Future<File> copyHiveSnapshot(File destination) async {
    _snapshotting = true;
    try {
      await flush(force: true);
      await GStorage.playbackStats.flush();
      await destination.parent.create(recursive: true);
      return await GStorage.playbackStatsHiveFile.copy(destination.path);
    } finally {
      _snapshotting = false;
    }
  }

  static Future<void> restoreHiveSnapshot(File source) async {
    _snapshotting = true;
    try {
      await flush(force: true);
      await GStorage.restorePlaybackStatsHive(source);
      reloadFromStorage();
    } finally {
      _snapshotting = false;
    }
  }

  static Future<void> reset() async {
    _ensureInitialized();
    await GStorage.playbackStats.clear();
    _stats = {
      'schemaVersion': schemaVersion,
      'metricDefinitionVersion': metricDefinitionVersion,
      'storageLayoutVersion': storageLayoutVersion,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    _rewind = null;
    _pendingPositionUs = null;
    _clearTrailingPause();
    _dirty = true;
    _dirtyKeys
      ..clear()
      ..addAll(_stats!.keys);
    _dirtyMonths.clear();
    _dirtyVideoUpUids.clear();
    _dirtyLiveUids.clear();
    _dirtyDimensions.clear();
    _dirtyCrossDimensions.clear();
    _legacyCompositeKeys.clear();
    final now = _clock.elapsedMicroseconds;
    _appLastWallUs = now;
    _pageLastWallUs = now;
    _commentPanelLastWallUs = now;
    if (_active) {
      if (_live) {
        _add('liveOpenCount', 1);
        final uid = _liveUid ?? 'unknown';
        _map('liveByUid')[uid] = {'openCount': 1, 'watchUs': 0};
        _markLiveDirty(uid);
      } else {
        _add('videoStarts', 1);
        _videoUpStartRecorded = false;
        _recordVideoUpStart();
        _recordSourceSpeed(_rate, _defaultRate);
        if (_completedIdle) {
          _videoSessionOpen = false;
          _coveredIntervals.clear();
        } else {
          _beginVideoSession(
            _lastPositionUs,
            _sourceDurationUs,
            resetContext: false,
          );
        }
      }
      _lastWallUs = now;
    }
    await flush();
  }

  static void reloadFromStorage() {
    _stats = null;
    _dirty = false;
    _dirtyKeys.clear();
    _dirtyMonths.clear();
    _dirtyVideoUpUids.clear();
    _dirtyLiveUids.clear();
    _dirtyDimensions.clear();
    _dirtyCrossDimensions.clear();
    _legacyCompositeKeys.clear();
    _writeChain = Future.value();
    final now = _clock.elapsedMicroseconds;
    _lastWallUs = now;
    _appLastWallUs = now;
    _pageLastWallUs = now;
    _commentPanelLastWallUs = now;
    _ensureInitialized();
  }
}

final class PlaybackPageRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    PlaybackStatsService._onPageRouteChanged(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    PlaybackStatsService._onPageRouteChanged(previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    PlaybackStatsService._onPageRouteChanged(newRoute?.settings.name);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    PlaybackStatsService._onPageRouteChanged(previousRoute?.settings.name);
  }
}

final class _RewindEpisode {
  _RewindEpisode({
    required this.checkpointUs,
    required this.distanceUs,
    required this.startedAtUs,
  });

  final int checkpointUs;
  final int distanceUs;
  final int startedAtUs;
  int activePlaybackUs = 0;
  int mediaAdvanceUs = 0;
  int pausedUs = 0;
  int bufferingUs = 0;
}
