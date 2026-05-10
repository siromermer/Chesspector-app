import 'package:audioplayers/audioplayers.dart';

/// Plays short move SFX alongside background music without pausing or ducking
/// the music (Spotify, YouTube Music, etc.).
///
/// Strategy:
/// * One dedicated [AudioPlayer] per sound, **pre-loaded** at startup. This
///   avoids the "first tap silent / later taps delayed" behaviour we had when
///   the same player was reused and/or the source was loaded lazily.
/// * Each player uses the normal media path (so audio actually plays through
///   the device speaker) but requests no audio focus, so other media apps are
///   not told to pause or duck.
///
/// Android: [AndroidUsageType.media] + [AndroidContentType.music] +
/// [AndroidAudioFocus.none]. iOS: [AVAudioSessionCategory.playback] with
/// [AVAudioSessionOptions.mixWithOthers] (no `duckOthers`).
class SoundService {
  SoundService._() {
    // Prewarm asynchronously — do not block callers.
    // ignore: discarded_futures
    _init();
  }

  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;

  // One player per sound keeps consecutive taps responsive.
  final Map<String, AudioPlayer> _players = {};

  static const _paths = <String, String>{
    'normal': 'sounds/chess_move_sound.mp3',
    'castle': 'sounds/castle.mp3',
    'check': 'sounds/move-check.mp3',
    'promote': 'sounds/promote.mp3',
  };

  AudioContext get _mixableContext => AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      );

  Future<void> _init() async {
    try {
      // Apply the global audio context once. This avoids a per-player context
      // switch right before playback, which was causing delays / silent plays.
      await AudioPlayer.global.setAudioContext(_mixableContext);
    } catch (_) {
      // Fall back to platform defaults if the context cannot be applied.
    }

    for (final entry in _paths.entries) {
      final player = AudioPlayer();
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(entry.value));
      } catch (_) {
        // If preloading fails we'll still attempt to play it on demand below.
      }
      _players[entry.key] = player;
    }
  }

  Future<void> _play(String key) async {
    final player = _players[key];
    final path = _paths[key];
    if (player == null || path == null) return;
    try {
      // Restart from the beginning each time so rapid moves aren't swallowed.
      await player.stop();
      await player.play(AssetSource(path));
    } catch (_) {
      // Ignore playback errors to avoid crashing the UI.
    }
  }

  Future<void> playNormal() => _play('normal');
  Future<void> playCastle() => _play('castle');
  Future<void> playCheck() => _play('check');
  Future<void> playPromote() => _play('promote');
}
