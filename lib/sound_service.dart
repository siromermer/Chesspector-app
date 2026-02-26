import 'package:audioplayers/audioplayers.dart';

/// Simple singleton service to play UI sounds.
class SoundService {
  SoundService._();
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;

  final AudioPlayer _player = AudioPlayer();

  Future<void> _playAsset(String path) async {
    try {
      await _player.play(AssetSource(path));
    } catch (_) {
      // Ignore playback errors to avoid crashing the UI
    }
  }

  Future<void> playNormal() => _playAsset('sounds/chess_move_sound.mp3');
  Future<void> playCastle() => _playAsset('sounds/castle.mp3');
  Future<void> playCheck() => _playAsset('sounds/move-check.mp3');
  Future<void> playPromote() => _playAsset('sounds/promote.mp3');
}

