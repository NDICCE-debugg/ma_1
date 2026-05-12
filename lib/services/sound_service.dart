import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService instance = SoundService._init();
  final AudioPlayer _player = AudioPlayer();
  
  SoundService._init();
  
  Future<void> _play(String path) async {
    try {
      // In production, uncomment this once files are in assets/sounds/
      // await _player.play(AssetSource(path));
      debugPrint("🔊 SOUND TRIGGERED: $path");
    } catch (e) {
      debugPrint("Sound error: $e");
    }
  }
  
  void playTabSwitch() => _play('sounds/tab_switch.mp3');
  void playBoot() => _play('sounds/boot.mp3');
  void playButtonPress() => _play('sounds/click_zap.mp3');
  void playError() => _play('sounds/error_alarm.mp3');
  void playSuccess() => _play('sounds/success_chime.mp3');
  void playTransmit() => _play('sounds/transmit.mp3');
}