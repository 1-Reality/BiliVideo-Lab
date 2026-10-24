import 'dart:math' as math;

import 'package:PiliBro/plugin/pl_player/controller.dart';
import 'package:material_ui/material_ui.dart';

/// 百分位整数直接拼倍速文字：150 → 1.5，105 → 1.05，200 → 2
String formatCenti(int centi) {
  final r = centi % 100;
  return r == 0
      ? '${centi ~/ 100}'
      : r % 10 == 0
      ? '${centi ~/ 100}.${r ~/ 10}'
      : r < 10
      ? '${centi ~/ 100}.0$r'
      : '${centi ~/ 100}.$r';
}

/// 倍速面板。面板内倍速全程是百分位整数，列数、滑杆范围和宽度都由设置页算好，
/// 打开时只读字段。外层套固定宽度，弹出菜单的 IntrinsicWidth 不再往下测量
class SpeedPanel extends PopupMenuEntry<double> {
  const SpeedPanel(
    this.controller, {
    required this.mode,
    required this.cols,
    required this.width,
    required this.rowHeight,
    super.key,
  });

  final PlPlayerController controller;
  // 位 1 矩阵、位 2 全范围滑杆；两者都有时位 0 表示滑杆在上、矩阵在下
  final int mode;
  final int cols;
  // 设置页算好的最终宽度和矩阵行高
  final double width;
  final double rowHeight;

  @override
  double get height => 0;

  @override
  bool represents(double? value) => false;

  @override
  State<SpeedPanel> createState() => _SpeedPanelState();
}

class _SpeedPanelState extends State<SpeedPanel> {
  static const _cellStyle = TextStyle(color: Colors.white, fontSize: 14);
  static const _labelStyle = TextStyle(color: Colors.white70, fontSize: 11);
  // − < 数字 > +：大调 0.5，微调 0.05
  static final _stepStyle = OutlinedButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    foregroundColor: Colors.white,
    side: const BorderSide(color: Colors.white38),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    textStyle: const TextStyle(fontSize: 16),
  );

  late final PlPlayerController c = widget.controller;
  late final bool _grid = widget.mode & 2 != 0;
  // 没勾滑杆时用矩阵下方 1.5 倍宽的小窗口
  late final bool _full = widget.mode & 4 != 0;
  late int _centi;
  // 打开面板时的倍速，关闭时若变了就成为下次点中间数字要切回的倍速
  late int _start;
  // 1.5 倍窗口左端，两端落在 0.5 的整数倍上；拖动期间不动
  late int _left;
  int _dragFrom = 0;
  late double _width;
  late double _cellWidth;
  int _labelStep = 50;
  // 矩阵格子只建一次，重建时同一个实例原样复用，框架直接跳过
  List<Widget> _cells = const [];
  late final List<Widget> _minus = [
    _stepButton('−', -50),
    _stepButton('<', -5),
  ];
  late final List<Widget> _plus = [
    _stepButton('>', 5),
    _stepButton('+', 50),
  ];

  @override
  void initState() {
    super.initState();
    _centi = _start = (c.playbackSpeed * 100).round();
    _left = (_centi * 2 - 100) ~/ 100 * 50;
  }

  // 宽度由设置页算好，这里只按屏宽封顶；矩阵再切格子，滑杆再看刻度字放得下几个
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _width = math.min(widget.width, MediaQuery.sizeOf(context).width - 16);
    if (_grid) {
      _cellWidth = _width / widget.cols;
      final list = c.speedList;
      _cells = [
        for (var i = list.length - 1; i >= 0; i--) _cell(list[i], _cellStyle),
      ];
    }
    if (!_full) return;
    final span = c.speedSliderMax - c.speedSliderMin;
    final fit = (_width - 8) ~/ 32;
    _labelStep = span % 50 == 0 && span ~/ 50 < fit
        ? 50
        : span % 100 == 0 && span ~/ 100 < fit
        ? 100
        : span;
  }

  @override
  void dispose() {
    if (_centi != _start) c.toggleSpeedCenti = _start;
    super.dispose();
  }

  Widget _cell(double speed, TextStyle style) {
    final centi = (speed * 100).round();
    return SizedBox(
      width: _cellWidth,
      height: widget.rowHeight,
      child: InkWell(
        onTap: () {
          _centi = centi;
          c.setPlaybackSpeed(speed);
          Navigator.pop(context);
        },
        child: Center(
          child: Text(
            speed % 1 == 0 ? '${speed.toInt()}x' : '${speed}x',
            style: style,
          ),
        ),
      ),
    );
  }

  Widget _stepButton(String label, int delta) => SizedBox(
    width: 40,
    height: 30,
    child: OutlinedButton(
      style: _stepStyle,
      onPressed: () => _commit(_centi + delta),
      child: Text(label),
    ),
  );

  void _commit(int centi) {
    if (centi <= 0) return;
    setState(() {
      _centi = centi;
      _left = (centi * 2 - 100) ~/ 100 * 50;
    });
    c.setPlaybackSpeed(centi / 100);
  }

  void _toggle() {
    final target = c.toggleSpeedCenti;
    c.toggleSpeedCenti = _centi;
    _start = target;
    _commit(target);
  }

  @override
  Widget build(BuildContext context) {
    final primary = ColorScheme.of(context).primary;
    final full = _full;
    final min = full ? c.speedSliderMin : _left;
    final max = full ? c.speedSliderMax : _left + 150;
    final n = _cells.length;
    final selected = _grid ? n - 1 - c.speedList.indexOf(_centi / 100) : -1;
    final rows = [
      for (var i = 0; i < n; i += widget.cols)
        Row(
          children: [
            for (var j = i; j < n && j < i + widget.cols; j++)
              j == selected
                  ? _cell(
                      c.speedList[n - 1 - j],
                      TextStyle(
                        color: primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : _cells[j],
          ],
        ),
    ];
    const divider = Divider(height: 9, color: Colors.white24);
    final controls = [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          spacing: 4,
          children: [
            ..._minus,
            Expanded(
              child: InkWell(
                onTap: _toggle,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                child: SizedBox(
                  height: 36,
                  child: Center(
                    child: Text(
                      '${formatCenti(_centi)}×',
                      style: TextStyle(
                        color: primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ..._plus,
          ],
        ),
      ),
      const Text(
        '点中间数字与上次倍速互切',
        style: TextStyle(color: Colors.white54, fontSize: 11),
      ),
    ];
    final slider = [
      SizedBox(
        height: 36,
        child: Slider(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          value: _centi.clamp(min, max).toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: full ? c.speedSliderDivisions : 15,
          onChangeStart: (_) => _dragFrom = _centi,
          onChanged: (value) {
            final centi = value.round();
            if (centi > 0) {
              setState(() => _centi = centi);
              c.setPlaybackSpeed(centi / 100, recordSelection: false);
            }
          },
          onChangeEnd: (_) {
            if (_centi != _dragFrom) {
              c.setPlaybackSpeed(_centi / 100, forceRecordSelection: true);
            }
          },
        ),
      ),
      // 刻度字宽 32、两侧各 4，字的中心正好落在滑杆两端内缩 20 的刻度上
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var v = min; v <= max; v += _labelStep)
              SizedBox(
                width: 32,
                child: Text(
                  '${formatCenti(v)}x',
                  textAlign: TextAlign.center,
                  style: _labelStyle,
                ),
              ),
          ],
        ),
      ),
    ];
    return SizedBox(
      width: _width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // 三位全开即矩阵与滑杆共存且对调：滑杆在上、矩阵在下
        children: widget.mode == 7
            ? [...slider, ...controls, divider, ...rows]
            : [...rows, if (_grid) divider, ...controls, ...slider],
      ),
    );
  }
}