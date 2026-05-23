import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/database_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // ValueNotifier for the UI (the red dot on tabs)
  static ValueNotifier<bool> hasCriticalAlerts = ValueNotifier<bool>(false);

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings, 
      iOS: DarwinInitializationSettings()
    );
    await _notificationsPlugin.initialize(initSettings);
  }

  // FIX: Added the missing requestPermission method for HomeScreen with Web checks
  static Future<void> requestPermission(BuildContext context) async {
    if (kIsWeb) return;
    final bool? granted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    if (granted == false) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.warning,
          content: Text("Alerts disabled. Some critical updates might be missed."),
        ),
      );
    }
  }

  static Future<void> checkInventoryAlerts() async {
    if (kIsWeb) return;
    final parts = await DatabaseHelper.instance.getInventory();
    bool lowStock = parts.any((p) => p.quantity <= p.reorderThreshold);
    hasCriticalAlerts.value = lowStock;
  }

  static void showStatusSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppTheme.error : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
      ),
    );
  }
}