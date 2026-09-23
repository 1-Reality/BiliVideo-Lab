import 'package:collection/collection.dart';
import 'package:hive_ce/hive.dart';

extension BoxExt<E> on Box<E> {
  bool equal(dynamic key, E value) {
    return const DeepCollectionEquality().equals(value, get(key));
  }

  Future<void>? putNE(dynamic key, E value) {
    if (!equal(key, value)) {
      return put(key, value);
    }
    return null;
  }

  Future<void>? putAllNE(Map<dynamic, E> entries) {
    final newEntries = <dynamic, E>{
      for (final entry in entries.entries)
        if (!equal(entry.key, entry.value)) entry.key: entry.value,
    };
    return newEntries.isEmpty ? null : putAll(newEntries);
  }
}
