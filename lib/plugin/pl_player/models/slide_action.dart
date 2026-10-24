/// 竖滑手势：列数占低 2 位，之后每列动作占 3 位
enum VerticalSlide {
  none('无'),
  brightness('亮度'),
  volume('音量'),
  speed('倍速'),
  fullscreen('全屏');

  final String label;
  const VerticalSlide(this.label);
}

/// 横滑手势：左上、右上、左下、右下各占 2 位，第 8、9 位是上下分界线档位
enum HorizontalSlide {
  none('无'),
  seek('进度'),
  speed('倍速');

  final String label;
  const HorizontalSlide(this.label);
}

/// 上下分界线距顶部的比例，按档位取
const slideSplitRatios = [0.3333333333333333, 0.5, 0.6666666666666666];

const slideSplitLabels = ['上 1/3', '一半', '上 2/3'];