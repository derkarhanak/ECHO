import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundManager {
  // Use a pool logic or simple fire-and-forget
  static Future<void> playExhale() async {
    await _playSound('sounds/exhale.mp3');
  }

  static Future<void> playCatch() async {
    await _playSound('sounds/catch.mp3');
  }
  
  static Future<void> _playSound(String path) async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource(path), mode: PlayerMode.lowLatency);
      // Clean up after play
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      debugPrint('SFX Error: $e');
    }
  }

  static Future<void> init() async {
    // Optional: Preload if needed, but AssetSource is usually fast enough
  }
}
