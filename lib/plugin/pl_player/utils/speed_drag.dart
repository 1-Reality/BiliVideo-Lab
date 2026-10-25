/// 倍速手势一侧：[stops] 是到达各软挡要走的档数（升序），[hits] 是对应的落点；
/// [end] 是这一侧最多走几档，[endHit] 是尽头的落点
typedef SpeedDragSide = ({
  List<double> stops,
  List<int> hits,
  double end,
  int? endHit,
});

/// 手指位移换算成档数。软挡处多走 [_hold] 档才放行；拖过尽头时起手点跟着手指走，
/// 往回拖立刻生效。横滑的档是分度值，竖滑的档是倍速列表的一项
class SpeedDrag {
  SpeedDrag(this._anchor, this._unitsPerPx, this._hold, this._up, this._down);

  double _anchor;
  final double _unitsPerPx;
  final double _hold;
  final SpeedDragSide _up;
  final SpeedDragSide _down;

  /// 停在软挡或尽头时的落点，否则为 null
  int? hit;

  /// 离起手点走了几档，正为加速
  double units(double pos) {
    hit = null;
    final d = (pos - _anchor) * _unitsPerPx;
    final up = d >= 0;
    final side = up ? _up : _down;
    var u = up ? d : -d;
    for (var i = 0; i < side.stops.length; i++) {
      final s = side.stops[i];
      if (u < s) break;
      if (u < s + _hold) {
        hit = side.hits[i];
        return up ? s : -s;
      }
      u -= _hold;
    }
    if (u >= side.end) {
      final over = (u - side.end) / _unitsPerPx;
      _anchor += up ? over : -over;
      u = side.end;
      hit = side.endHit;
    }
    return up ? u : -u;
  }
}