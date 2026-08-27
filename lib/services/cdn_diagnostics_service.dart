import 'package:PiliPlus/utils/storage.dart';

typedef CdnDiagnosticGroup = ({
  int runStartedAtUs,
  int recordedAtUs,
  List<Map<String, dynamic>> records,
});

abstract final class CdnDiagnosticsService {
  static const _prefix = 'cdnDiagnostic:';
  static int _sequence = 0;

  static Future<void> append(Map<String, dynamic> record) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final id = '$_prefix$now:${_sequence++}';
    try {
      await GStorage.appendCdnDiagnostic((id: id, record: record));
    } catch (_) {
      // 诊断记录失败绝不能反过来影响测速本身。
    }
  }

  static List<({String id, Map<String, dynamic> record})> _allEntries() {
    final merged = <String, Map<String, dynamic>>{
      for (final entry in GStorage.readCdnDiagnosticsSync())
        entry.id: entry.record,
    };
    for (final key in GStorage.video.keys) {
      if (key is! String || !key.startsWith(_prefix)) continue;
      final raw = GStorage.video.get(key);
      if (raw is Map) {
        merged[key] = raw.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    }
    return [
      for (final entry in merged.entries)
        (id: entry.key, record: entry.value),
    ];
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

  static Future<void> deleteRuns(Set<int> runStartedAtUs) async {
    if (runStartedAtUs.isEmpty) return;

    final keep = <({String id, Map<String, dynamic> record})>[];
    final legacyKeys = <dynamic>[];

    for (final entry in _allEntries()) {
      final value = entry.record;
      final run = (value['testRunStartedAtUs'] as num?)?.toInt() ??
          (value['recordedAtUs'] as num?)?.toInt() ??
          0;
      if (runStartedAtUs.contains(run)) {
        if (GStorage.video.containsKey(entry.id)) {
          legacyKeys.add(entry.id);
        }
      } else {
        keep.add(entry);
      }
    }

    await GStorage.replaceCdnDiagnostics(keep);
    if (legacyKeys.isNotEmpty) {
      await GStorage.video.deleteAll(legacyKeys);
    }
  }
}
