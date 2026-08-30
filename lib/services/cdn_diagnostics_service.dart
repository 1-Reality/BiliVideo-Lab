import 'package:PiliPlus/utils/storage.dart';

typedef CdnDiagnosticGroup = ({
  int runStartedAtUs,
  int recordedAtUs,
  List<Map<String, dynamic>> records,
});

abstract final class CdnDiagnosticsService {
  static const _prefix = 'cdnDiagnostic:';
  static int _sequence = 0;
  static int? _activeRun;
  static final List<Map<String, dynamic>> _activeRecords = [];
  static Future<void> _writeChain = Future.value();

  static Future<void> append(Map<String, dynamic> record) => _enqueue(() async {
      final now = DateTime.now().microsecondsSinceEpoch;
      final id = '$_prefix$now:${_sequence++}';
      final run = (record['testRunStartedAtUs'] as num?)?.toInt() ?? now;
      if (_activeRun != run) {
        _activeRun = run;
        _activeRecords
          ..clear()
          ..addAll(
            _allEntries()
                .map((entry) => entry.record)
                .where(
                  (item) =>
                      (item['testRunStartedAtUs'] as num?)?.toInt() == run,
                ),
          );
      }
      final cdn = record['cdn'] is Map ? record['cdn'] as Map : const {};
      final index = cdn['index'];
      _activeRecords.removeWhere((item) {
        final old = item['cdn'];
        return old is Map && old['index'] == index;
      });
      _activeRecords.add(record);
      await GStorage.replaceCdnDiagnostics([
        for (final item in _activeRecords)
          (id: '$id:${item['recordedAtUs']}', record: item),
      ]);
    });

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

  static List<({String id, Map<String, dynamic> record})> _allEntries() {
    return GStorage.readCdnDiagnosticsSync();
  }

  static List<Map<String, dynamic>> snapshot() {
    final records = [
      for (final entry in _allEntries()) entry.record,
    ];
    records.sort(
      (a, b) => ((b['recordedAtUs'] as num?) ?? 0).compareTo(
        (a['recordedAtUs'] as num?) ?? 0,
      ),
    );
    return records;
  }

  static List<CdnDiagnosticGroup> groupedSnapshot() {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final record in snapshot()) {
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

  static Future<void> deleteRuns(Set<int> runStartedAtUs) => _enqueue(() async {
    if (runStartedAtUs.isEmpty) return;

    final keep = <({String id, Map<String, dynamic> record})>[];
    for (final entry in _allEntries()) {
      final value = entry.record;
      final run = (value['testRunStartedAtUs'] as num?)?.toInt() ??
          (value['recordedAtUs'] as num?)?.toInt() ??
          0;
      if (!runStartedAtUs.contains(run)) keep.add(entry);
    }

    await GStorage.replaceCdnDiagnostics(keep);
    if (keep.isEmpty) {
      _activeRun = null;
      _activeRecords.clear();
    }
  });

  static Future<void> clearLatest() => _enqueue(() async {
      _activeRun = null;
      _activeRecords.clear();
      await GStorage.replaceCdnDiagnostics(const []);
    });
}
