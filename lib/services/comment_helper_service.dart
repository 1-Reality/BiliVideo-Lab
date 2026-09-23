import 'package:PiliBro/utils/storage.dart';
import 'package:flutter/foundation.dart';

abstract final class CommentHelperService {
  static const uid = 0;
  static const name = '哥哥科技小助手';
  static const avatarAsset = 'assets/images/brotech_comment_helper.jpg';

  static final ValueNotifier<int> revision = ValueNotifier(0);

  static List<Map<String, dynamic>> get records {
    final values = GStorage.commentHelper.values
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList();
    values.sort(
      (a, b) => ((b['detectedAtMs'] as num?) ?? 0).compareTo(
        (a['detectedAtMs'] as num?) ?? 0,
      ),
    );
    return values;
  }

  static Map<String, dynamic>? get latest {
    final values = records;
    return values.isEmpty ? null : values.first;
  }

  static Future<void> recordHidden({
    required int oid,
    required int type,
    required int rpid,
    required int root,
    required int parent,
    required int sentAtSeconds,
    required int authorUid,
    required String message,
    required List pictures,
    required Object? sourceId,
    required String reason,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await GStorage.commentHelper.put(rpid.toString(), {
      'schemaVersion': 1,
      'assistantUid': uid,
      'assistantName': name,
      'status': 'hidden',
      'reason': reason,
      'message': message,
      'pictures': pictures,
      'oid': oid,
      'type': type,
      'rpid': rpid,
      'root': root,
      'parent': parent,
      'authorUid': authorUid,
      'sourceId': sourceId?.toString(),
      'sentAtSeconds': sentAtSeconds,
      'detectedAtMs': now,
    });
    revision.value++;
  }
}
