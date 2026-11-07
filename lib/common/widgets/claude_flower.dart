import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

const _claudePetalEdges = <double>[
  271.8,
  297.8,
  341.4,
  364.7,
  386.9,
  408.3,
  433.9,
  460.4,
  488.1,
  518.8,
  548.5,
  590.3,
  631.8,
];

/// 按真实花瓣的角度逐瓣点亮，[fraction] 是 0 到 1 的几成
class ClaudeFlower extends StatelessWidget {
  const ClaudeFlower({super.key, required this.fraction, required this.size});

  static const _asset = 'assets/images/claude_ai_symbol.svg';

  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final open = (fraction * (_claudePetalEdges.length - 1)).clamp(
      0.0,
      (_claudePetalEdges.length - 1).toDouble(),
    );
    final partial = open - open.floor();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SvgPicture.asset(
            _asset,
            colorFilter: ColorFilter.mode(
              ColorScheme.of(context).outlineVariant.withValues(alpha: 0.5),
              BlendMode.srcIn,
            ),
          ),
          ClipPath(
            clipper: _ClaudePetalClipper(open: open),
            child: SvgPicture.asset(
              _asset,
              colorFilter: const ColorFilter.mode(
                Color(0xFFD97757),
                BlendMode.srcIn,
              ),
            ),
          ),
          if (partial > 0)
            ClipPath(
              clipper: _ClaudePetalClipper(open: open, partialOnly: true),
              child: SvgPicture.asset(
                _asset,
                colorFilter: ColorFilter.mode(
                  const Color(0xFFD97757).withValues(
                    alpha: 0.25 + 0.75 * partial,
                  ),
                  BlendMode.srcIn,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClaudePetalClipper extends CustomClipper<Path> {
  const _ClaudePetalClipper({required this.open, this.partialOnly = false});

  final double open;
  final bool partialOnly;

  @override
  Path getClip(Size size) {
    final shown = open.clamp(0.0, (_claudePetalEdges.length - 1).toDouble());
    final fullCount = shown.floor();
    final fraction = shown - fullCount;
    final center = size.center(Offset.zero);
    final innerRadius = size.width * 0.12;
    final outerRadius = size.width * 0.8;
    final path = Path();

    if (partialOnly) {
      if (fraction > 0 && fullCount < (_claudePetalEdges.length - 1)) {
        _addPetalSector(
          path,
          size,
          fullCount,
          innerRadius,
          outerRadius,
        );
      }
      return path;
    }

    // 中心保持完整，外侧按真实花瓣的角度逐瓣点亮。
    path.addOval(Rect.fromCircle(center: center, radius: innerRadius));
    for (var i = 0; i < fullCount; i++) {
      _addPetalSector(path, size, i, innerRadius, outerRadius);
    }
    return path;
  }

  void _addPetalSector(
    Path path,
    Size size,
    int index,
    double innerRadius,
    double outerRadius,
  ) {
    var start = _claudePetalEdges[index];
    var end = _claudePetalEdges[index + 1];
    if (partialOnly) {
      end = start + (end - start) * (open - open.floor());
    }

    final center = size.center(Offset.zero);
    final startRad = start * math.pi / 180;
    final endRad = end * math.pi / 180;
    final sector = Path()
      ..moveTo(
        center.dx + innerRadius * math.cos(startRad),
        center.dy + innerRadius * math.sin(startRad),
      )
      ..lineTo(
        center.dx + outerRadius * math.cos(startRad),
        center.dy + outerRadius * math.sin(startRad),
      );

    for (var i = 1; i <= 8; i++) {
      final a = startRad + (endRad - startRad) * i / 8;
      sector.lineTo(
        center.dx + outerRadius * math.cos(a),
        center.dy + outerRadius * math.sin(a),
      );
    }

    sector.lineTo(
      center.dx + innerRadius * math.cos(endRad),
      center.dy + innerRadius * math.sin(endRad),
    );
    for (var i = 7; i >= 0; i--) {
      final a = startRad + (endRad - startRad) * i / 8;
      sector.lineTo(
        center.dx + innerRadius * math.cos(a),
        center.dy + innerRadius * math.sin(a),
      );
    }
    sector.close();
    path.addPath(sector, Offset.zero);
  }

  @override
  bool shouldReclip(_ClaudePetalClipper oldClipper) =>
      oldClipper.open != open || oldClipper.partialOnly != partialOnly;
}