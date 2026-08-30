import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:PiliPlus/models/common/network_profile.dart';
import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:PiliPlus/utils/connectivity_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_ce/hive.dart';

typedef WindowsTrafficLive = ({
  int appReceived,
  int appSent,
  int interfaceReceived,
  int interfaceSent,
  double appReceiveRate,
  double appSendRate,
  double interfaceReceiveRate,
  double interfaceSendRate,
});

final class TrafficStatsService with WidgetsBindingObserver {
  TrafficStatsService._();

  static final instance = TrafficStatsService._();

  Timer? _timer;
  Future<void>? _initializeFuture;
  StreamSubscription<NetworkPolicyChange>? _networkSubscription;
  ({int received, int sent})? _last;
  ({int received, int sent})? _lastWindowsApp;
  ({int received, int sent})? _lastWindowsInterface;
  int? _lastWindowsInterfaceId;
  int _windowsInterfaceSessionReceived = 0;
  int _windowsInterfaceSessionSent = 0;
  DateTime? _lastAt;
  String? _lastCategory;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, dynamic> _data = {};
  final Set<String> _dirtyHours = {};
  Box<dynamic>? _box;
  bool _dirty = false;
  bool _restoring = false;
  int _dartReceived = 0;
  int _dartSent = 0;
  bool _samplingWindows = false;
  final ValueNotifier<WindowsTrafficLive?> windowsLive = ValueNotifier(null);

  static const _windowsChannel = MethodChannel(
    'org.brotech.piliplus/network_traffic',
  );

  Future<void> initialize() {
    if (_timer != null) return Future.value();
    if (!Platform.isAndroid && !Platform.isWindows) return Future.value();
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    _box = await _openBox();
    final legacy = GStorage.video.get(VideoBoxKey.trafficStats);
    final boxData = _box!.toMap();
    if (boxData.isNotEmpty) {
      _data.addAll(
        boxData.map((key, value) => MapEntry(key.toString(), value)),
      );
    } else {
      final raw =
          GStorage.readJsonMapSync(GStorage.trafficStatsFile) ??
          (legacy is Map
              ? legacy.map(
                  (key, value) => MapEntry(key.toString(), value),
                )
              : null);
      if (raw != null && raw.isNotEmpty) {
        _data.addAll(raw);
        await _box!.putAll(raw);
      }
    }
    if (await GStorage.trafficStatsFile.exists()) {
      await GStorage.trafficStatsFile.delete();
    }
    if (GStorage.video.containsKey(VideoBoxKey.trafficStats)) {
      await GStorage.video.delete(VideoBoxKey.trafficStats);
    }
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) {
      await _windowsChannel.invokeMethod<bool>('installMediaHook');
    }
    await _sample();
    _networkSubscription = ConnectivityUtils.changes.listen((_) => _sample());
    _timer = Timer.periodic(
      Platform.isWindows
          ? const Duration(milliseconds: 250)
          : const Duration(seconds: 5),
      (_) => _sample(),
    );
  }

  void recordApplicationBytes({int received = 0, int sent = 0}) {
    if (!Platform.isWindows) return;
    if (received > 0) _dartReceived += received;
    if (sent > 0) _dartSent += sent;
  }

  String _category(NetworkProfile? profile) => switch (profile?.transport) {
    NetworkTransport.wifi => profile!.useCellularPreferences
        ? 'wifiCellular'
        : 'wifiBroadband',
    NetworkTransport.wired => profile!.useCellularPreferences
        ? 'wiredCellular'
        : 'wiredBroadband',
    NetworkTransport.cellular => 'mobile',
    _ => 'other',
  };

  String _hourKey(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}T'
      '${time.hour.toString().padLeft(2, '0')}';

  Future<void> _sample() async {
    if (_restoring) return;
    if (Platform.isWindows) {
      await _sampleWindows();
      return;
    }
    final current = PiliAndroidHelper.trafficStats();
    if (current == null) return;
    final now = DateTime.now();
    final previous = _last;
    if (previous != null && _lastAt != null && _lastCategory != null) {
      final received = current.received >= previous.received
          ? current.received - previous.received
          : 0;
      final sent = current.sent >= previous.sent ? current.sent - previous.sent : 0;
      if (received != 0 || sent != 0) {
        final hour = _hourKey(_lastAt!);
        final hourly = Map<String, dynamic>.from(
          _data[hour] as Map? ?? const {},
        );
        final category = Map<String, dynamic>.from(
          hourly[_lastCategory] as Map? ?? const {},
        );
        category
          ..['received'] = (category['received'] as num? ?? 0).toInt() + received
          ..['sent'] = (category['sent'] as num? ?? 0).toInt() + sent;
        hourly[_lastCategory!] = category;
        _data[hour] = hourly;
        _dirtyHours.add(hour);
        _dirty = true;
      }
    }
    _last = current;
    _lastAt = now;
    _lastCategory = _category(ConnectivityUtils.current);
    if (_dirty && now.difference(_lastFlush) >= const Duration(seconds: 30)) {
      await flush();
    }
  }

  Future<void> _sampleWindows() async {
    if (_samplingWindows) return;
    _samplingWindows = true;
    Map<Object?, Object?>? media;
    Map<Object?, Object?>? network;
    try {
      final values = await Future.wait([
        _windowsChannel.invokeMapMethod<Object?, Object?>('mediaCounters'),
        _windowsChannel.invokeMapMethod<Object?, Object?>('interfaceCounters'),
      ]);
      media = values[0];
      network = values[1];
      final now = DateTime.now();
      final app = (
        received:
            ((media?['received'] as num?)?.toInt() ?? 0) + _dartReceived,
        sent: ((media?['sent'] as num?)?.toInt() ?? 0) + _dartSent,
      );
      final interface = (
        received: (network?['received'] as num?)?.toInt() ?? 0,
        sent: (network?['sent'] as num?)?.toInt() ?? 0,
      );
      final elapsedUs = _lastAt == null
          ? 0
          : now.difference(_lastAt!).inMicroseconds;
      final appDelta = _delta(app, _lastWindowsApp);
      final interfaceAvailable = network?['available'] == true;
      final interfaceId = (network?['sourceId'] as num?)?.toInt();
      final sameInterface = interfaceAvailable &&
          interfaceId != null &&
          interfaceId == _lastWindowsInterfaceId;
      final interfaceDelta = interfaceAvailable
          ? _delta(interface, sameInterface ? _lastWindowsInterface : null)
          : (received: 0, sent: 0);
      _windowsInterfaceSessionReceived += interfaceDelta.received;
      _windowsInterfaceSessionSent += interfaceDelta.sent;
      if (_lastAt != null && _lastCategory != null) {
        _recordDelta('appObserved.${_lastCategory!}', appDelta, _lastAt!);
        _recordDelta(
          'activeInterface.${_lastCategory!}',
          interfaceDelta,
          _lastAt!,
        );
      }
      if (elapsedUs > 0) {
        windowsLive.value = (
          appReceived: app.received,
          appSent: app.sent,
          interfaceReceived: _windowsInterfaceSessionReceived,
          interfaceSent: _windowsInterfaceSessionSent,
          appReceiveRate: appDelta.received * 1000000 / elapsedUs,
          appSendRate: appDelta.sent * 1000000 / elapsedUs,
          interfaceReceiveRate: interfaceDelta.received * 1000000 / elapsedUs,
          interfaceSendRate: interfaceDelta.sent * 1000000 / elapsedUs,
        );
      }
      _lastWindowsApp = app;
      if (interfaceAvailable) {
        _lastWindowsInterface = interface;
        _lastWindowsInterfaceId = interfaceId;
      }
      _lastAt = now;
      _lastCategory = _category(ConnectivityUtils.current);
      if (_dirty &&
          now.difference(_lastFlush) >= const Duration(seconds: 30)) {
        await flush();
      }
    } catch (_) {
      return;
    } finally {
      _samplingWindows = false;
    }
  }

  ({int received, int sent}) _delta(
    ({int received, int sent}) current,
    ({int received, int sent})? previous,
  ) => previous == null
      ? (received: 0, sent: 0)
      : (
          received: current.received >= previous.received
              ? current.received - previous.received
              : 0,
          sent: current.sent >= previous.sent
              ? current.sent - previous.sent
              : 0,
        );

  void _recordDelta(
    String source,
    ({int received, int sent}) delta,
    DateTime at,
  ) {
    if (delta.received == 0 && delta.sent == 0) return;
    final hour = _hourKey(at);
    final hourly = Map<String, dynamic>.from(_data[hour] as Map? ?? const {});
    final category = Map<String, dynamic>.from(
      hourly[source] as Map? ?? const {},
    );
    category
      ..['received'] =
          (category['received'] as num? ?? 0).toInt() + delta.received
      ..['sent'] = (category['sent'] as num? ?? 0).toInt() + delta.sent;
    hourly[source] = category;
    _data[hour] = hourly;
    _dirtyHours.add(hour);
    _dirty = true;
  }

  Future<void> flush() async {
    if (!_dirty) return;
    final hours = Set<String>.of(_dirtyHours);
    final values = <String, dynamic>{
      for (final hour in hours) hour: _data[hour],
    };
    _dirty = false;
    _dirtyHours.removeAll(hours);
    _lastFlush = DateTime.now();
    try {
      await _box?.putAll(values);
    } catch (_) {
      _dirty = true;
      _dirtyHours.addAll(hours);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> snapshot() async {
    if (Platform.isAndroid || Platform.isWindows) await _sample();
    return {
      for (final entry in _data.entries)
        entry.key: Map<String, dynamic>.from(entry.value as Map),
    };
  }

  Future<void> restoreHive(File source) async {
    if (!Platform.isAndroid && !Platform.isWindows) return;
    final currentBox = _box;
    final targetPath = currentBox?.path;
    if (currentBox == null || targetPath == null) {
      throw StateError('流量统计库尚未初始化');
    }
    final target = File(targetPath);
    final previous = File('$targetPath.webdav-previous');
    _restoring = true;
    try {
      await flush();
      await currentBox.close();
      _box = null;
      if (await previous.exists()) await previous.delete();
      if (await target.exists()) await target.rename(previous.path);
      await source.copy(target.path);
      _box = await _openBox();
      _reloadBoxData();
      if (await previous.exists()) await previous.delete();
    } catch (_) {
      await _box?.close();
      _box = null;
      if (await target.exists()) await target.delete();
      if (await previous.exists()) await previous.rename(target.path);
      _box = await _openBox();
      _reloadBoxData();
      rethrow;
    } finally {
      _last = null;
      _lastWindowsApp = null;
      _lastWindowsInterface = null;
      _lastWindowsInterfaceId = null;
      _lastAt = null;
      _lastCategory = null;
      windowsLive.value = null;
      _restoring = false;
    }
    await _sample();
  }

  Future<Box<dynamic>> _openBox() => Hive.openBox(
    'trafficStats',
    compactionStrategy: (entries, deletedEntries) =>
        deletedEntries > 100 && deletedEntries > entries,
  );

  void _reloadBoxData() {
    _data
      ..clear()
      ..addAll(
        _box!.toMap().map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
    _dirty = false;
    _dirtyHours.clear();
  }

  Future<void> reset() async {
    await initialize();
    _restoring = true;
    try {
      _data.clear();
      _dirtyHours.clear();
      _dirty = false;
      await _box?.clear();
      _last = null;
      _lastWindowsApp = null;
      _lastWindowsInterface = null;
      _lastWindowsInterfaceId = null;
      _lastAt = null;
      _lastCategory = null;
      _windowsInterfaceSessionReceived = 0;
      _windowsInterfaceSessionSent = 0;
      windowsLive.value = null;
    } finally {
      _restoring = false;
    }
    await _sample();
  }

  Future<File?> copyHiveSnapshot(File destination) async {
    await initialize();
    final source = hiveFile;
    if (source == null || !await source.exists()) return null;
    _restoring = true;
    try {
      await flush();
      await _box?.flush();
      await destination.parent.create(recursive: true);
      return await source.copy(destination.path);
    } finally {
      _restoring = false;
    }
  }

  Future<({int day, int week, int month})> currentPeriodUsage() async {
    if (!Platform.isAndroid && !Platform.isWindows) {
      return (day: 0, week: 0, month: 0);
    }
    final data = await snapshot();
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final weekStart = dayStart.subtract(Duration(days: dayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    var day = 0;
    var week = 0;
    var month = 0;
    for (final entry in data.entries) {
      final time = DateTime.tryParse('${entry.key}:00:00');
      if (time == null) continue;
      var total = 0;
      final hourly = entry.value as Map;
      for (final item in hourly.entries) {
        if (Platform.isWindows &&
            !item.key.toString().startsWith('appObserved.')) {
          continue;
        }
        final category = item.value;
        if (category is! Map) continue;
        total += (category['received'] as num? ?? 0).toInt();
        total += (category['sent'] as num? ?? 0).toInt();
      }
      if (!time.isBefore(monthStart)) month += total;
      if (!time.isBefore(weekStart)) week += total;
      if (!time.isBefore(dayStart)) day += total;
    }
    return (day: day, week: week, month: month);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _sample().then((_) => flush());
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _networkSubscription?.cancel();
    _networkSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    await flush();
    await _box?.close();
    _box = null;
    _initializeFuture = null;
  }

  File? get hiveFile {
    final boxPath = _box?.path;
    return boxPath == null ? null : File(boxPath);
  }
}
