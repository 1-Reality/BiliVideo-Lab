import 'package:PiliBro/utils/storage.dart';

typedef CdnDiagnosticGroup = ({
  int runStartedAtUs,
  int recordedAtUs,
  List<Map<String, dynamic>> records,
});

abstract final class CdnDiagnosticsService {
  static int? _activeRun;
  static final List<Map<String, dynamic>> _activeHistoryRecords = [];
  static final List<Map<String, dynamic>> _activeLatestRecords = [];
  static Future<void> _writeChain = Future.value();

  static void append({
    required Map<String, dynamic> historyRecord,
    required Map<String, dynamic> latestRecord,
  }) {
    final run = (historyRecord['testRunStartedAtUs'] as num?)?.toInt() ??
        DateTime.now().microsecondsSinceEpoch;
    if (_activeRun != run) {
      _activeRun = run;
      _activeHistoryRecords.clear();
      _activeLatestRecords.clear();
    }
    _replaceCdn(_activeHistoryRecords, historyRecord);
    _replaceCdn(_activeLatestRecords, latestRecord);
  }

  static void _replaceCdn(
    List<Map<String, dynamic>> records,
    Map<String, dynamic> record,
  ) {
    final cdn = record['cdn'] is Map ? record['cdn'] as Map : const {};
    final index = cdn['index'];
    records.removeWhere((item) {
      final old = item['cdn'];
      return old is Map && old['index'] == index;
    });
    records.add(record);
  }

  static Future<void> flushRun() {
    if (_activeHistoryRecords.isEmpty || _activeLatestRecords.isEmpty) {
      return _writeChain;
    }
    final history = List<Map<String, dynamic>>.of(_activeHistoryRecords);
    final latest = List<Map<String, dynamic>>.of(_activeLatestRecords);
    return _enqueue(() async {
      await GStorage.replaceCdnDiagnostics([
        for (final item in latest)
          (id: item['recordedAtUs']?.toString() ?? '', record: item),
      ]);
      await GStorage.appendCdnDiagnosticsHistory([
        for (final item in history)
          (id: item['recordedAtUs']?.toString() ?? '', record: item),
      ]);
    });
  }

  static Future<void> _enqueue(Future<void> Function() action) {
    Future<void> run(dynamic _) async {
      try {
        await action();
      } catch (_) {
        // 诊断记录失败绝不能反过来影响测速本身。
      }
    }

    _writeChain = _writeChain.then(run, onError: run);
    return _writeChain;
  }

  static List<Map<String, dynamic>> latestSnapshot() {
    final records = [
      for (final entry in GStorage.readCdnDiagnosticsSync()) entry.record,
    ];
    _sortRecords(records);
    return records;
  }

  static List<Map<String, dynamic>> historySnapshot() {
    final records = [
      for (final entry in GStorage.readCdnDiagnosticsHistorySync()) entry.record,
    ];
    _sortRecords(records);
    return records;
  }

  static void _sortRecords(List<Map<String, dynamic>> records) {
    records.sort(
      (a, b) => ((b['recordedAtUs'] as num?) ?? 0).compareTo(
        (a['recordedAtUs'] as num?) ?? 0,
      ),
    );
  }

  static List<CdnDiagnosticGroup> groupedLatestSnapshot() =>
      _group(latestSnapshot());

  static List<CdnDiagnosticGroup> groupedHistorySnapshot() =>
      _group(historySnapshot());

  static List<CdnDiagnosticGroup> _group(
    List<Map<String, dynamic>> records,
  ) {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final run = (record['testRunStartedAtUs'] as num?)?.toInt() ??
          (record['recordedAtUs'] as num?)?.toInt() ??
          0;
      (grouped[run] ??= []).add(record);
    }
    final groups = <CdnDiagnosticGroup>[
      for (final entry in grouped.entries)
        (
          runStartedAtUs: entry.key,
          recordedAtUs: entry.value
              .map((record) => (record['recordedAtUs'] as num?)?.toInt() ?? 0)
              .fold(0, (a, b) => a > b ? a : b),
          records: entry.value,
        ),
    ];
    groups.sort((a, b) => b.runStartedAtUs.compareTo(a.runStartedAtUs));
    return groups;
  }

  static Future<void> deleteHistoryRuns(Set<int> runStartedAtUs) =>
      _enqueue(() async {
        if (runStartedAtUs.isEmpty) return;

        final keep = <({String id, Map<String, dynamic> record})>[];
        for (final entry in GStorage.readCdnDiagnosticsHistorySync()) {
          final value = entry.record;
          final run = (value['testRunStartedAtUs'] as num?)?.toInt() ??
              (value['recordedAtUs'] as num?)?.toInt() ??
              0;
          if (!runStartedAtUs.contains(run)) keep.add(entry);
        }

        await GStorage.replaceCdnDiagnosticsHistory(keep);
      });

  static Future<void> clearLatest() {
    _activeRun = null;
    _activeHistoryRecords.clear();
    _activeLatestRecords.clear();
    return _enqueue(() => GStorage.replaceCdnDiagnostics(const []));
  }
}
