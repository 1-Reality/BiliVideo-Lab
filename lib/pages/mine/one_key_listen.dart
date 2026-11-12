import 'package:PiliBro/grpc/bilibili/app/listener/v1.pbenum.dart'
    show PlaylistSource;
import 'package:PiliBro/http/fav.dart';
import 'package:PiliBro/http/loading_state.dart';
import 'package:PiliBro/models/common/fav_order_type.dart';
import 'package:PiliBro/models_new/fav/fav_folder/list.dart';
import 'package:PiliBro/pages/audio/view.dart';
import 'package:PiliBro/pages/audio/web_item.dart';
import 'package:PiliBro/utils/accounts.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:PiliBro/utils/storage_key.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 「一键听歌」：在「我的」页面用预先选好的收藏夹直接进入听音频模式。
abstract final class OneKeyListen {
  static int? get mediaId =>
      GStorage.setting.get(SettingBoxKey.oneKeyListenMediaId) as int?;

  /// 点击：播放已选收藏夹；没设置过就先选一次，选完立刻播放。
  static Future<void> play() async {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    var folderId = mediaId;
    if (folderId == null) {
      folderId = await _selectFolder();
      if (folderId == null) return;
    }
    await _launch(folderId);
  }

  /// 长按：只改选中的收藏夹，不立即播放。
  static Future<void> configure() async {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    await _selectFolder();
  }

  static Future<int?> _selectFolder() async {
    final res = await FavHttp.allFavFolders(Accounts.main.mid);
    if (res case Success(:final response)) {
      final list = response.list;
      if (list == null || list.isEmpty) {
        SmartDialog.showToast('没有可用的收藏夹');
        return null;
      }
      final current = mediaId;
      final folder = await showDialog<FavFolderInfo>(
        context: Get.context!,
        builder: (context) => AlertDialog(
          clipBehavior: Clip.hardEdge,
          title: const Text('选择一键听歌的收藏夹'),
          contentPadding: const EdgeInsets.only(top: 5, bottom: 18),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in list)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        item.id == current
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                      ),
                      title: Text(
                        '${item.title}  (${item.mediaCount})',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(item),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      if (folder == null) return null;
      await GStorage.setting.putAll({
        SettingBoxKey.oneKeyListenMediaId: folder.id,
        SettingBoxKey.oneKeyListenFavTitle: folder.title,
      });
      SmartDialog.showToast('已设置：${folder.title}');
      return folder.id;
    } else {
      res.toast();
      return null;
    }
  }

  static Future<void> _launch(int mediaId) async {
    final res = await FavHttp.userFavFolderDetail(
      mediaId: mediaId,
      pn: 1,
      ps: 20,
    );
    if (res case Success(:final response)) {
      final playlist = favPlaylist(response.medias!);
      if (playlist.isEmpty) {
        SmartDialog.showToast('该收藏夹第一页没有可听的视频');
        return;
      }
      final first = playlist.first.item;
      // 后面的页由听视频页接着读
      AudioPage.toAudioPage(
        itemType: 1,
        oid: first.oid.toInt(),
        subId: [first.subId.first.toInt()],
        id: mediaId,
        from: PlaylistSource.MEDIA_LIST,
        playlist: playlist,
        favPn: response.hasMore! ? 2 : null,
        favOrder: FavOrderType.mtime,
      );
    } else {
      res.toast();
    }
  }
}