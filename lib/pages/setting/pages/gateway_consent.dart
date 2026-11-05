import 'dart:async';
import 'dart:io';

import 'package:PiliBro/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliBro/utils/device_utils.dart';
import 'package:PiliBro/utils/page_utils.dart';
import 'package:PiliBro/utils/permission_handler.dart';
import 'package:PiliBro/utils/storage.dart';
import 'package:material_ui/material_ui.dart';

// ─── 存储键 ───────────────────────────────────────────────────────────────────
// 写在 LocalCacheKey 里即可，这里用字面量直接引用，省一次间接
const _kGatewayConsented = 'gatewayConsented';

// ─── 是否已同意（给调用方检查用） ─────────────────────────────────────────────
bool get gatewayConsented =>
    GStorage.localCache.get(_kGatewayConsented, defaultValue: false) == true;

// ─── 入口：从任意渠道调用，已同意直接 return，否则 push 授权页 ─────────────────
/// 返回 true 表示已授权（包含本次同意），false 表示用户关掉了窗口。
Future<bool> requireGatewayConsent(BuildContext context) async {
  if (gatewayConsented) return true;
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const GatewayConsentPage()),
  );
  return result == true;
}

// ─── 授权页面 ─────────────────────────────────────────────────────────────────
class GatewayConsentPage extends StatefulWidget {
  const GatewayConsentPage({super.key});

  @override
  State<GatewayConsentPage> createState() => _GatewayConsentPageState();
}

class _GatewayConsentPageState extends State<GatewayConsentPage> {
  static const _total = 10;

  Timer? _timer;
  int _remaining = _total;
  bool _ready = false; // 倒计时归零后解锁同意按钮

  // Android 17+ 本地网络权限状态，null = 未查询 / 非 Android
  bool? _lanGranted;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _checkLan();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _ready = true;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  Future<void> _checkLan() async {
    if (!Platform.isAndroid || DeviceUtils.sdkInt < 37) return;
    final granted = await Permission.accessLocalNetwork.isGranted;
    if (mounted) setState(() => _lanGranted = granted);
  }

  Future<void> _requestLan() async {
    final status = await Permission.accessLocalNetwork.request();
    if (mounted) setState(() => _lanGranted = status.isGranted);
  }

  Future<void> _agree() async {
    await GStorage.localCache.put(_kGatewayConsented, true);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = Theme.of(context).textTheme;
    final showLan = Platform.isAndroid && DeviceUtils.sdkInt >= 37;

    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('使用须知'),
        actions: [
          IconButton(
            tooltip: '查看许可证',
            icon: const Icon(Icons.balance_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _LicensePage()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // ── 主标题区 ──────────────────────────────────────────────────
              Icon(
                Icons.hub_outlined,
                size: 56,
                color: cs.primary,
              ),
              const SizedBox(height: 20),
              Text(
                '网关管理',
                textAlign: TextAlign.center,
                style: tt.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '该程序从云端加载并缓存内容至您的设备',
                textAlign: TextAlign.center,
                style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
              ),

              const SizedBox(height: 32),

              // ── 条款卡片 ──────────────────────────────────────────────────
              _TermsCard(cs: cs, tt: tt),

              const SizedBox(height: 20),

              // ── 查看许可证（文字入口） ─────────────────────────────────────
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _LicensePage()),
                ),
                icon: const Icon(Icons.balance_outlined, size: 18),
                label: const Text('查看完整许可证'),
              ),

              const SizedBox(height: 12),

              // ── 关注 / 支持开发者 ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _DevButton(
                      icon: Icons.person_pin_circle_outlined,
                      iconColor: const Color(0xFF7C4DFF),
                      label: '关注开发者',
                      url: 'https://space.bilibili.com/388010726',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DevButton(
                      icon: Icons.favorite_border_rounded,
                      iconColor: const Color(0xFFE91E63),
                      label: '支持开发者',
                      url: 'https://www.goofish.com/personal?userId=2216485229713',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 本地网络权限状态（Android 17+ 专属） ──────────────────────
              if (showLan) ...[
                _LanPermissionRow(
                  granted: _lanGranted,
                  onTap: _lanGranted == true ? null : _requestLan,
                ),
                const SizedBox(height: 20),
              ],

              const Spacer(),

              // ── 底部操作区 ────────────────────────────────────────────────
              _BottomBar(
                remaining: _remaining,
                ready: _ready,
                total: _total,
                onAgree: _agree,
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 条款卡片 ─────────────────────────────────────────────────────────────────
class _TermsCard extends StatelessWidget {
  const _TermsCard({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '主要条款',
              style: tt.labelLarge!.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _TermLine(
              cs: cs,
              tt: tt,
              text: '本程序从云端加载并缓存内容至您的设备，严格遵循哥哥科技显著署名许可证（以下简称"许可证"）。',
            ),
            const SizedBox(height: 8),
            _TermLine(
              cs: cs,
              tt: tt,
              text: '根据许可证规定，程序中任何名称均不得被篡改、弱化，或以非预期方式呈现。',
            ),
            const SizedBox(height: 8),
            _TermLine(
              cs: cs,
              tt: tt,
              text: '通过使用本程序，即表示您已阅读并同意上述条款及完整许可证内容。',
            ),
          ],
        ),
      ),
    );
  }
}

class _TermLine extends StatelessWidget {
  const _TermLine({required this.cs, required this.tt, required this.text});

  final ColorScheme cs;
  final TextTheme tt;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: tt.bodySmall!.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 关注 / 支持开发者按钮 ────────────────────────────────────────────────────
class _DevButton extends StatelessWidget {
  const _DevButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    return Material(
      color: iconColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => PageUtils.launchURL(url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 本地网络权限行 ────────────────────────────────────────────────────────────
class _LanPermissionRow extends StatelessWidget {
  const _LanPermissionRow({required this.granted, required this.onTap});

  final bool? granted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final granted = this.granted;

    final Color color;
    final IconData icon;
    final String label;

    if (granted == null) {
      color = cs.onSurfaceVariant;
      icon = Icons.wifi_tethering_outlined;
      label = '正在检查本地网络权限…';
    } else if (granted) {
      color = Colors.green.shade600;
      icon = Icons.wifi_tethering;
      label = '本地网络权限 · 已授权';
    } else {
      color = cs.error;
      icon = Icons.wifi_tethering_error_outlined;
      label = '本地网络权限缺失 · 点击申请';
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

// ─── 底部操作栏（倒计时 + 同意按钮） ──────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.remaining,
    required this.ready,
    required this.total,
    required this.onAgree,
  });

  final int remaining;
  final bool ready;
  final int total;
  final VoidCallback onAgree;

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);

    return Column(
      children: [
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ready ? 1.0 : (total - remaining) / total,
            minHeight: 3,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              ready ? cs.primary : cs.primary.withValues(alpha: 0.55),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: ready ? onAgree : null,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: ready
                  ? const Text(
                      '我已阅读并同意',
                      key: ValueKey('agree'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text(
                      '请阅读上述条款（$remaining 秒）',
                      key: ValueKey(remaining),
                      style: const TextStyle(fontSize: 14),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 许可证二级页（独立 Scaffold，计时在父页继续） ────────────────────────────
class _LicensePage extends StatelessWidget {
  const _LicensePage();

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.of(context);
    final tt = Theme.of(context).textTheme;

    return SimpleScaffold(
      appBar: AppBar(title: const Text('哥哥科技显著署名许可证')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '哥哥科技显著署名许可证\nGege Technology Prominent Attribution License',
              style: tt.titleMedium!.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _LicenseSection(
              cs: cs,
              tt: tt,
              title: '第一条　署名义务',
              body: '本程序及其任何衍生版本在任何公开渠道分发时，须以不低于原版同等显著程度显示作者"哥哥科技（Gege Technology）"的完整署名。任何削减、遮蔽、替换或以非预期方式呈现上述署名的行为均构成违约。',
            ),
            _LicenseSection(
              cs: cs,
              tt: tt,
              title: '第二条　名称完整性',
              body: '程序中的任何名称（包括应用名称、模块名称、功能名称及界面文案中的专有名词）均不得被篡改、弱化，或在未获书面授权的情况下以其他名称替代。',
            ),
            _LicenseSection(
              cs: cs,
              tt: tt,
              title: '第三条　云端内容',
              body: '本程序从云端加载并将内容缓存至用户设备，以提供功能。用户理解并接受此数据流转行为。缓存数据的所有权归属及使用限制以各内容提供方许可条款为准。',
            ),
            _LicenseSection(
              cs: cs,
              tt: tt,
              title: '第四条　无担保声明',
              body: '本程序按"现状"提供，不附带任何明示或暗示的担保。作者对因使用本程序产生的任何直接或间接损失不承担责任。',
            ),
            _LicenseSection(
              cs: cs,
              tt: tt,
              title: '第五条　许可证延续',
              body: '在本许可证明确授权范围之外的权利均予保留。本许可证的任何条款若被认定无效，不影响其余条款的效力。',
            ),
            const SizedBox(height: 8),
            Text(
              '© 哥哥科技（Gege Technology）. 保留所有权利。',
              style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenseSection extends StatelessWidget {
  const _LicenseSection({
    required this.cs,
    required this.tt,
    required this.title,
    required this.body,
  });

  final ColorScheme cs;
  final TextTheme tt;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.labelLarge!.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: tt.bodyMedium!.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
