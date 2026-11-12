import 'package:PiliBro/grpc/bilibili/app/listener/v1.pb.dart'
    show Author, BKArcPart, BKArchive, BKStat, DetailItem, PlayItem;
import 'package:PiliBro/models_new/fav/fav_detail/media.dart';
import 'package:PiliBro/models_new/video/video_detail/data.dart';
import 'package:fixnum/fixnum.dart' show Int64;

// 私密稿件（state=-50）不在 gRPC Listener 的数据里，播放列表条目由 web 数据构造。
// DetailItem.playable 借来放稿件 state：-50 的条目取流走 web playurl，其余照旧走 gRPC。

/// 收藏夹一页 -> 播放列表条目；失效稿件（attr 最低位是 1，见过 1、9）不进列表。
/// 条目里只有首 P：占位分 P 的 page 放的是分 P 总数，大于 1 的选中后再用详情换成真实分 P
List<DetailItem> favPlaylist(List<FavDetailItemModel> medias) => [
  for (final e in medias)
    if (e.type == 2 && e.attr! & 1 == 0)
      DetailItem(
        item: PlayItem(
          itemType: 1,
          oid: Int64(e.id!),
          subId: [Int64(e.ugc!.firstCid!)],
        ),
        arc: BKArchive(
          oid: Int64(e.id!),
          title: e.title,
          cover: e.cover,
          desc: e.intro,
          duration: Int64(e.duration!),
          displayedOid: e.bvid,
        ),
        parts: [
          BKArcPart(
            oid: Int64(e.id!),
            subId: Int64(e.ugc!.firstCid!),
            title: e.title,
            duration: Int64(e.duration!),
            page: e.page,
          ),
        ],
        owner: Author(
          mid: Int64(e.upper!.mid!),
          name: e.upper!.name,
          avatar: e.upper!.face,
        ),
        stat: BKStat(view: e.cntInfo!.play),
        // 私密稿件的 attr 是 384，公开的是 0
        playable: e.attr! > 127 ? -50 : 0,
      ),
];

/// web 详情 -> 播放列表条目，带全部分 P
DetailItem viewDetailItem(VideoDetailData d, Iterable<Int64> subId) {
  final oid = Int64(d.aid!);
  final owner = d.owner!;
  final stat = d.stat!;
  return DetailItem(
    item: PlayItem(itemType: 1, oid: oid, subId: subId),
    arc: BKArchive(
      oid: oid,
      title: d.title,
      cover: d.pic,
      desc: d.desc,
      duration: Int64(d.duration!),
      rid: d.tid,
      rname: d.tname,
      copyright: d.copyright,
      publish: Int64(d.pubdate!),
      displayedOid: d.bvid,
    ),
    parts: [
      for (final e in d.pages!)
        BKArcPart(
          oid: oid,
          subId: Int64(e.cid!),
          title: e.part,
          duration: Int64(e.duration!),
          page: e.page,
        ),
    ],
    owner: Author(mid: Int64(owner.mid!), name: owner.name, avatar: owner.face),
    stat: BKStat(
      view: stat.view,
      like: stat.like,
      coin: stat.coin.toInt(),
      favourite: stat.favorite,
      reply: stat.reply,
      share: stat.share,
    ),
    playable: d.isViewSelf! ? -50 : 0,
  );
}