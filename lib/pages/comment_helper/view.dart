import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/common/widgets/view_safe_area.dart';
import 'package:PiliBro/services/comment_helper_service.dart';
import 'package:material_ui/material_ui.dart';

class CommentHelperPage extends StatelessWidget {
  const CommentHelperPage({super.key});

  String _time(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds).toString();

  @override
  Widget build(BuildContext context) {
    final records = CommentHelperService.records;
    return SimpleScaffold(
      appBar: AppBar(title: const Text(CommentHelperService.name)),
      body: ViewSafeArea(
        child: records.isEmpty
            ? const Center(child: Text('还没有被吞的评论记录'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final item = records[index];
                  final detected =
                      (item['detectedAtMs'] as num?)?.toInt() ?? 0;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12, right: 36),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundImage: AssetImage(
                                    CommentHelperService.avatarAsset,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    CommentHelperService.name,
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  _time(detected),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ColorScheme.of(context).outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('检测到这条由本客户端发送的评论已经不可见：'),
                            const SizedBox(height: 8),
                            SelectableText(item['message']?.toString() ?? ''),
                            const SizedBox(height: 8),
                            Text(
                              item['reason']?.toString() ?? '评论不可见',
                              style: TextStyle(
                                color: ColorScheme.of(context).error,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              'OID ${item['oid']} · 类型 ${item['type']} · '
                              'RPID ${item['rpid']} · ROOT ${item['root']} · '
                              'PARENT ${item['parent']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (item['pictures'] case final List pictures
                                when pictures.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SelectableText('图片：$pictures'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
