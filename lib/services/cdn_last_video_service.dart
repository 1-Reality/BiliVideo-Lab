import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/utils/storage.dart';

class CdnLastVideoSnapshot {
  const CdnLastVideoSnapshot({
    required this.playUrl,
    required this.quality,
    required this.preferredCodec,
  });

  final PlayUrlModel playUrl;
  final int quality;
  final String? preferredCodec;

  List<VideoItem> get videos {
    final all = playUrl.dash?.video ?? const <VideoItem>[];
    if (all.isEmpty) return const <VideoItem>[];
    final exact = all.where((item) => item.id == quality).toList(growable: false);
    if (exact.isNotEmpty) return exact;
    final fallbackQuality = all.first.id;
    return all
        .where((item) => item.id == fallbackQuality)
        .toList(growable: false);
  }
}

abstract final class CdnLastVideoService {
  static const _key = 'cdn:lastPlayedVideo';

  static Future<void> remember({
    required String bvid,
    required int cid,
    required int quality,
    required String preferredCodec,
    required VideoType videoType,
    required bool tryLook,
    int? epId,
    int? seasonId,
  }) async {
    await GStorage.video.put(_key, <String, dynamic>{
      'bvid': bvid,
      'cid': cid,
      'quality': quality,
      'preferredCodec': preferredCodec,
      'videoType': videoType.name,
      'tryLook': tryLook,
      'epId': epId,
      'seasonId': seasonId,
    });
  }

  static Future<CdnLastVideoSnapshot?> load() async {
    final raw = GStorage.video.get(_key);
    if (raw is! Map) return null;

    final bvid = raw['bvid']?.toString();
    final cid = (raw['cid'] as num?)?.toInt();
    final quality = (raw['quality'] as num?)?.toInt();
    final typeName = raw['videoType']?.toString();
    if (bvid == null || cid == null || quality == null || typeName == null) {
      return null;
    }

    VideoType? type;
    for (final item in VideoType.values) {
      if (item.name == typeName) {
        type = item;
        break;
      }
    }
    if (type == null) return null;

    final result = await VideoHttp.videoUrl(
      bvid: bvid,
      cid: cid,
      qn: quality,
      epid: raw['epId'],
      seasonId: raw['seasonId'],
      tryLook: raw['tryLook'] == true,
      videoType: type,
    );
    if (result case Success(:final response)) {
      final snapshot = CdnLastVideoSnapshot(
        playUrl: response,
        quality: quality,
        preferredCodec: raw['preferredCodec']?.toString(),
      );
      return snapshot.videos.isEmpty ? null : snapshot;
    }
    return null;
  }
}
