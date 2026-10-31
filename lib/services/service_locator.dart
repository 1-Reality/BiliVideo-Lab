import 'package:PiliBro/services/audio_handler.dart';
import 'package:PiliBro/services/audio_session.dart';
import 'package:PiliBro/services/playback_focus.dart';

VideoPlayerServiceHandler? videoPlayerServiceHandler;
AudioSessionHandler? audioSessionHandler;

Future<void> setupServiceLocator() async {
  final audio = await initAudioService();
  videoPlayerServiceHandler = audio;
  audioSessionHandler = AudioSessionHandler();
  PlaybackFocus.init();
}
