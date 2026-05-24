import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService instance = SoundService._init();
  final AudioPlayer _player = AudioPlayer();

  SoundService._init();

  // Internal helper to handle audio playback
  Future<void> _play(String path, {double volume = 0.5}) async {
    try {
      await _player.setVolume(volume);
      await _player.play(AssetSource(path));
      debugPrint("Clinical audio: $path");
    } catch (e) {
      debugPrint("Audio Playback Error: $e");
    }
  }

  // --- MODERN CLINICAL SOUND BANK ---

  /// Subtle click for tab navigation
  void playTabSwitch() => _play('sounds/nav_subtle_click.mp3', volume: 0.3);

  /// Soft chime when the system is ready
  void playSystemReady() => _play('sounds/clinical_ready.mp3');

  /// Discrete ping for successful data transmission or identification
  void playSuccess() => _play('sounds/success_ping.mp3');

  /// Soft alert for warnings or low stock (non-startling)
  void playAlert() => _play('sounds/soft_alert.mp3', volume: 0.4);

  /// Minimalist interaction sound for buttons
  void playInteraction() => _play('sounds/interaction_tap.mp3', volume: 0.2);

  // --- LEGACY ALIASES (Kept to prevent breaking screen code) ---

  void playBoot() => playSystemReady();
  void playButtonPress() => playInteraction();
  void playError() => playAlert();
  void playTransmit() => playSuccess();
}

