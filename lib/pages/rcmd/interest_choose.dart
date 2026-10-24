import 'package:material_ui/material_ui.dart';

/// 新用户首屏 App 推荐下发的兴趣选择。选完返回 interest_id、interest_result、
/// interest_pos_ids，由推荐流带着重新请求一次
Future<Map<String, dynamic>?> showInterestChoose(
  BuildContext context,
  Map<String, dynamic> data,
) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => _InterestChoose(data),
);

class _InterestChoose extends StatefulWidget {
  const _InterestChoose(this.data);

  final Map<String, dynamic> data;

  @override
  State<_InterestChoose> createState() => _InterestChooseState();
}

class _InterestChooseState extends State<_InterestChoose> {
  late final Map<String, dynamic> data = widget.data;
  late final List items = data['items'] ?? const [];
  int? gender;
  int? age;
  final selected = <String>{};

  // 每个可选项的位置标识：有子项的用「主.子」，选中结果按这个顺序回传
  late final List<String> posIds = [
    for (final item in items)
      if ((item['sub_items'] as List?)?.isNotEmpty ?? false)
        for (final sub in item['sub_items']) '${item['id']}.${sub['id']}'
      else
        '${item['id']}',
  ];

  Widget _choices(
    String? title,
    List? options,
    int? value,
    ValueChanged<int> onSelected,
  ) {
    if (options == null || options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title?.isNotEmpty ?? false) _title(title!),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in options)
              ChoiceChip(
                label: Text(e['title'] ?? ''),
                selected: value == e['id'],
                onSelected: (_) => setState(() => onSelected(e['id'])),
              ),
          ],
        ),
      ],
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _chip(String key, String label) => FilterChip(
    label: Text(label),
    selected: selected.contains(key),
    onSelected: (value) =>
        setState(() => value ? selected.add(key) : selected.remove(key)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? subTitle = data['sub_title'];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            data['title'] ?? '选择你感兴趣的内容',
            style: theme.textTheme.titleLarge,
          ),
          if (subTitle?.isNotEmpty ?? false)
            Text(subTitle!, style: TextStyle(color: theme.colorScheme.outline)),
          _choices(
            data['gender_title'],
            data['genders'],
            gender,
            (v) => gender = v,
          ),
          _choices(data['age_title'], data['ages'], age, (v) => age = v),
          for (final item in items) ...[
            _title(item['name'] ?? ''),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (item['sub_items'] as List?)?.isNotEmpty ?? false
                  ? [
                      for (final sub in item['sub_items'])
                        _chip('${item['id']}.${sub['id']}', sub['name'] ?? ''),
                    ]
                  : [_chip('${item['id']}', item['name'] ?? '')],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: selected.isEmpty && gender == null && age == null
                ? null
                : () => Navigator.pop(context, {
                    'interest_id': data['unique_id'],
                    'interest_result': [
                      ...posIds.where(selected.contains),
                      ?gender?.toString(),
                      ?age?.toString(),
                    ].join(','),
                    'interest_pos_ids': posIds.join(','),
                  }),
            child: Text(data['confirm_text'] ?? '完成'),
          ),
        ],
      ),
    );
  }
}