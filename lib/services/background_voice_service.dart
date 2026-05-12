import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// --- THESE MUST BE OUTSIDE THE CLASS ---
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // SIMULATED LISTENING LOOP
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        debugPrint("Background Service: Mic is active, listening for wake word...");
        // Background logic goes here
      }
    }
  });
}

class BackgroundVoiceService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Create the Notification Channel (Required for Android Foreground Service)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'biomed_voice_channel', // id
      'BioMed Voice Service', // title
      description: 'Listening for voice commands...',
      importance: Importance.low, 
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This is the function that runs in the background
        onStart: onStart,
        autoStart: false, // We want the user to toggle it manually
        isForegroundMode: true,
        notificationChannelId: 'biomed_voice_channel',
        initialNotificationTitle: 'BioMed Assistant',
        initialNotificationContent: 'Listening for "Hey BioMed"...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}