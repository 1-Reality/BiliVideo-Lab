import 'package:media_kit/media_kit.dart';

// mpv 变速时自动插入的 scaletempo2 用默认 min-speed=0.25、max-speed=8，
// 超出这个区间直接输出静音。--af 里显式放一个 scaletempo2 会接管变速、
// 自动的那个不再插入，所以只在区间外换上两端都不限的实例，区间内仍交给
// mpv 自动管理。
bool _outsideDefaultTempo(double rate) => rate < 0.25 || rate > 8.0;

extension TempoRate on Player {
  Future<void> setTempoRate(double rate) async {
    final wasOutside = _outsideDefaultTempo(state.rate);
    final outside = _outsideDefaultTempo(rate);
    if (outside && !wasOutside) {
      await command(const [
        'set',
        'af',
        'scaletempo2=min-speed=0:max-speed=0',
      ]);
    }
    await setRate(rate);
    if (wasOutside && !outside) {
      await command(const ['set', 'af', '']);
    }
  }
}
