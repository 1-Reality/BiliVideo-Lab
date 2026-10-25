import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 「压低到」：别人说话时我们让一让。
/// 显示：跷跷板左边是我们的一杯水，水位就是音量；右边是正在播报的导航，
/// 我们压得越低，它的气泡越大；背景弹幕的条数和浓淡也跟着音量走；水位下降时杯口往外洒水；
/// 左上角一朵放射花，开几瓣就是几成。
/// 调节和显示分开：拖跷跷板细调，点下面的杯子选档，按加减号 5% 微调
Future<int?> showDuckVolumeDialog(BuildContext context, int initial) =>
    showDialog<int>(
      context: context,
      builder: (_) => _DuckVolumeDialog(initial),
    );

class _DuckVolumeDialog extends StatefulWidget {
  const _DuckVolumeDialog(this.initial);

  final int initial;

  @override
  State<_DuckVolumeDialog> createState() => _DuckVolumeDialogState();
}

class _Drop {
  _Drop(this.position, this.velocity);

  Offset position;
  Offset velocity;
}

/// 画面状态。每帧只通知画布重画，不重建对话框里的其他部件
class _Scene extends ChangeNotifier {
  _Scene(this.shown);

  double shown;
  double time = 0;
  final drops = <_Drop>[];

  void repaint() => notifyListeners();
}

class _DuckVolumeDialogState extends State<_DuckVolumeDialog>
    with SingleTickerProviderStateMixin {
  static const _min = 5;
  static const _max = 95;
  static const _cups = [15, 30, 50, 70, 90];

  late int _percent = widget.initial.clamp(_min, _max);
  // 拖动时的连续值，落到 5 的倍数才改 _percent
  late double _dragValue = _percent.toDouble();
  // 画面上的值追着 _percent 缓动
  late final _scene = _Scene(_percent.toDouble());

  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Size _sceneSize = Size.zero;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scene.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.1) return;
    final scene = _scene..time += dt;
    final diff = _percent - scene.shown;
    if (diff < -0.5 && _sceneSize != Size.zero) {
      final geo = _Geo(_sceneSize, scene.shown);
      final away = geo.lipOnLeft ? -1.0 : 1.0;
      for (var i = 0; i < 2; i++) {
        scene.drops.add(
          _Drop(
            geo.lip + Offset(_random.nextDouble() * 4 - 2, 0),
            Offset(
              away * (40 + _random.nextDouble() * 60),
              -20 + _random.nextDouble() * 40,
            ),
          ),
        );
      }
    }
    scene.shown += diff * math.min(1, dt * 6);
    for (final drop in scene.drops) {
      drop.velocity += Offset(0, 900 * dt);
      drop.position += drop.velocity * dt;
    }
    scene.drops.removeWhere((drop) => drop.position.dy > _sceneSize.height);
    scene.repaint();
  }

  void _set(int value) {
    final next = value.clamp(_min, _max);
    if (next == _percent) return;
    HapticFeedback.selectionClick();
    setState(() {
      _percent = next;
      _dragValue = next.toDouble();
    });
  }

  void _onDrag(DragUpdateDetails details) {
    // 往下拖压低我们这边
    final delta = details.delta.dy / _sceneSize.height * 120;
    _dragValue = (_dragValue - delta).clamp(_min.toDouble(), _max.toDouble());
    _set((_dragValue / 5).round() * 5);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('压低到', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '别人说话时我们让一让。拖跷跷板、点杯子或按加减号',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.outline,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // 高度只按屏幕高度留余地，免得横屏时对话框超出屏幕
                _sceneSize = Size(
                  width,
                  math.min(
                    width * 0.75,
                    MediaQuery.sizeOf(context).height * 0.45,
                  ),
                );
                return GestureDetector(
                  onVerticalDragUpdate: _onDrag,
                  child: SizedBox(
                    width: _sceneSize.width,
                    height: _sceneSize.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ScenePainter(
                              scene: _scene,
                              colors: colors,
                              textStyle: theme.textTheme.bodySmall!,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          top: 4,
                          child: _ClaudeFlower(
                            scene: _scene,
                            colors: colors,
                            size: math.min(54, _sceneSize.height * 0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final cup in _cups)
                  GestureDetector(
                    onTap: () => _set(cup),
                    child: CustomPaint(
                      size: const Size(40, 52),
                      painter: _CupPainter(
                        fill: cup / 100,
                        selected: cup == _percent,
                        colors: colors,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _set(_percent - 5),
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    '$_percent%',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _set(_percent + 5),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: Get.back, child: const Text('取消')),
                TextButton(
                  onPressed: () => Get.back(result: _percent),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 跷跷板的几何：左端坐着我们的杯子，右端坐着导航
class _Geo {
  _Geo(Size size, double shown) {
    pivot = Offset(size.width / 2, size.height * 0.8);
    half = math.min(size.width * 0.36, 220);
    // 大于 0 时左端下沉：我们压得越低，左边越往下
    angle = (50 - shown) / 45 * 0.3;
    final dir = Offset(math.cos(angle), -math.sin(angle));
    left = pivot - dir * half;
    right = pivot + dir * half;
    glassWidth = math.min(56, size.width * 0.13);
    glassHeight = glassWidth * 1.3;
    final topLeft = toWorld(left, Offset(-glassWidth / 2, -6 - glassHeight));
    final topRight = toWorld(left, Offset(glassWidth / 2, -6 - glassHeight));
    lipOnLeft = topLeft.dy >= topRight.dy;
    lip = lipOnLeft ? topLeft : topRight;
  }

  late final Offset pivot;
  late final double half;
  late final double angle;
  late final Offset left;
  late final Offset right;
  late final double glassWidth;
  late final double glassHeight;
  late final bool lipOnLeft;
  late final Offset lip;

  /// 跷跷板一端的局部坐标（随板转）换到画布坐标
  Offset toWorld(Offset end, Offset local) {
    final c = math.cos(-angle);
    final s = math.sin(-angle);
    return end +
        Offset(local.dx * c - local.dy * s, local.dx * s + local.dy * c);
  }

  Path glassPath() => Path()
    ..moveTo(-glassWidth / 2, -6 - glassHeight)
    ..lineTo(glassWidth / 2, -6 - glassHeight)
    ..lineTo(glassWidth * 0.38, -6)
    ..lineTo(-glassWidth * 0.38, -6)
    ..close();
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.scene,
    required this.colors,
    required this.textStyle,
  }) : super(repaint: scene);

  final _Scene scene;
  final ColorScheme colors;
  final TextStyle textStyle;

  double get shown => scene.shown;
  double get time => scene.time;
  List<_Drop> get drops => scene.drops;

  static const _danmaku = [
    '前方高能',
    '哈哈哈哈哈',
    '下次一定',
    '好家伙',
    '名场面',
    '妙啊',
    '泪目',
    '这也行',
    '二刷了',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _Geo(size, shown);
    _paintDanmaku(canvas, size);

    // 支点和地面
    final ground = geo.pivot.dy + 30;
    canvas
      ..drawLine(
        Offset(0, ground),
        Offset(size.width, ground),
        Paint()
          ..color = colors.outlineVariant
          ..strokeWidth = 2,
      )
      ..drawPath(
        Path()
          ..moveTo(geo.pivot.dx, geo.pivot.dy)
          ..lineTo(geo.pivot.dx - 18, ground)
          ..lineTo(geo.pivot.dx + 18, ground)
          ..close(),
        Paint()..color = colors.secondary,
      )
      // 板
      ..drawLine(
        geo.left,
        geo.right,
        Paint()
          ..color = colors.onSurfaceVariant
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );

    _paintGlass(canvas, size, geo);
    _paintNavigator(canvas, geo);

    final dropPaint = Paint()..color = colors.primary.withValues(alpha: 0.7);
    for (final drop in drops) {
      canvas.drawCircle(drop.position, 2.5, dropPaint);
    }
  }

  // 弹幕条数和浓淡跟着音量走
  void _paintDanmaku(Canvas canvas, Size size) {
    final count = (shown / 100 * _danmaku.length).ceil().clamp(
      1,
      _danmaku.length,
    );
    final alpha = 0.15 + 0.55 * shown / 100;
    final top = size.height * 0.04;
    final lane = size.height * 0.42 / _danmaku.length;
    for (var i = 0; i < count; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: _danmaku[i],
          style: textStyle.copyWith(
            color: colors.onSurface.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final speed = 36 + (i * 17) % 40;
      final travel = size.width + painter.width;
      final x = size.width - (time * speed + i * 97) % travel;
      painter
        ..paint(canvas, Offset(x, top + i * lane))
        ..dispose();
    }
  }

class _ClaudeFlower extends StatelessWidget {
  const _ClaudeFlower({
    required this.scene,
    required this.colors,
    required this.size,
  });

  static const _asset = 'assets/images/claude_ai_symbol.svg';
  static const _angles = <double>[
    279.75,
    310.75,
    351.25,
    13.75,
    41.75,
    57.25,
    92.75,
    124.25,
    146.75,
    181.25,
    213.75,
    244.25,
  ];

  final _Scene scene;
  final ColorScheme colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scene,
      builder: (context, _) {
        final open = scene.shown / 100 * _angles.length;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset(
                _asset,
                colorFilter: ColorFilter.mode(
                  colors.outlineVariant.withValues(alpha: 0.5),
                  BlendMode.srcIn,
                ),
              ),
              for (var i = 0; i < _angles.length; i++)
                if (open - i > 0)
                  ClipPath(
                    clipper: _ClaudePetalClipper(_angles[i]),
                    child: SvgPicture.asset(
                      _asset,
                      colorFilter: ColorFilter.mode(
                        colors.secondary.withValues(
                          alpha: 0.25 + 0.75 * (open - i).clamp(0.0, 1.0),
                        ),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _ClaudePetalClipper extends CustomClipper<Path> {
  _ClaudePetalClipper(this.angle);

  final double angle;

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 1.5;
    const halfAngle = 9 * math.pi / 180;
    final mid = angle * math.pi / 180;
    final path = Path()..moveTo(center.dx, center.dy);
    for (var i = 0; i <= 8; i++) {
      final a = mid - halfAngle + (halfAngle * 2) * i / 8;
      path.lineTo(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
    }
    return path..close();
  }

  @override
  bool shouldReclip(_ClaudePetalClipper oldClipper) => oldClipper.angle != angle;
}

  // 杯子随板倾斜，水面始终水平
  void _paintGlass(Canvas canvas, Size size, _Geo geo) {
    final glass = geo.glassPath();
    final level = geo.toWorld(
      geo.left,
      Offset(0, -6 - shown / 100 * geo.glassHeight * 0.92),
    );
    canvas
      ..save()
      ..translate(geo.left.dx, geo.left.dy)
      ..rotate(-geo.angle)
      ..clipPath(glass)
      ..rotate(geo.angle)
      ..translate(-geo.left.dx, -geo.left.dy)
      ..drawRect(
        Rect.fromLTRB(0, level.dy, size.width, size.height),
        Paint()..color = colors.primary.withValues(alpha: 0.55),
      )
      ..restore()
      ..save()
      ..translate(geo.left.dx, geo.left.dy)
      ..rotate(-geo.angle)
      ..drawPath(
        glass,
        Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      )
      ..restore();
  }

  // 导航：我们压得越低，它的气泡越大
  void _paintNavigator(Canvas canvas, _Geo geo) {
    const radius = 16.0;
    canvas
      ..save()
      ..translate(geo.right.dx, geo.right.dy)
      ..rotate(-geo.angle)
      ..drawCircle(
        const Offset(0, -6 - radius),
        radius,
        Paint()..color = colors.tertiary,
      )
      ..drawPath(
        Path()
          ..moveTo(0, -6 - radius * 1.7)
          ..lineTo(radius * 0.55, -6 - radius * 0.45)
          ..lineTo(0, -6 - radius * 0.8)
          ..lineTo(-radius * 0.55, -6 - radius * 0.45)
          ..close(),
        Paint()..color = colors.onTertiary,
      )
      ..restore();

    final scale = 0.75 + (100 - shown) / 100 * 0.7;
    final painter = TextPainter(
      text: TextSpan(
        text: '前方 300 米右转',
        style: textStyle.copyWith(
          color: colors.onTertiaryContainer,
          fontSize: (textStyle.fontSize ?? 12) * scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final anchor = geo.right - Offset(0, 6 + radius * 2 + 12);
    final bubble = Rect.fromLTWH(
      anchor.dx - painter.width / 2 - 8,
      anchor.dy - painter.height - 10,
      painter.width + 16,
      painter.height + 10,
    );
    final shifted = bubble.shift(
      Offset(
        math.min(0, geo.pivot.dx * 2 - 4 - bubble.right),
        0,
      ),
    );
    final bubblePaint = Paint()..color = colors.tertiaryContainer;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(shifted, const Radius.circular(10)),
        bubblePaint,
      )
      ..drawPath(
        Path()
          ..moveTo(anchor.dx - 6, shifted.bottom)
          ..lineTo(anchor.dx + 6, shifted.bottom)
          ..lineTo(anchor.dx, anchor.dy + 2)
          ..close(),
        bubblePaint,
      );
    painter
      ..paint(canvas, shifted.topLeft + const Offset(8, 5))
      ..dispose();
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.textStyle != textStyle;
}

class _CupPainter extends CustomPainter {
  _CupPainter({
    required this.fill,
    required this.selected,
    required this.colors,
  });

  final double fill;
  final bool selected;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cup = Path()
      ..moveTo(w * 0.1, h * 0.08)
      ..lineTo(w * 0.9, h * 0.08)
      ..lineTo(w * 0.78, h * 0.95)
      ..lineTo(w * 0.22, h * 0.95)
      ..close();
    final level = h * 0.95 - fill * h * 0.85;
    canvas
      ..save()
      ..clipPath(cup)
      ..drawRect(
        Rect.fromLTRB(0, level, w, h),
        Paint()
          ..color = colors.primary.withValues(alpha: selected ? 0.7 : 0.35),
      )
      ..restore()
      ..drawPath(
        cup,
        Paint()
          ..color = selected ? colors.primary : colors.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 1.5,
      );
  }

  @override
  bool shouldRepaint(_CupPainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.colors != colors;
}