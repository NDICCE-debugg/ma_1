import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/theme/app_theme.dart';

@pragma('vm:entry-point')
void inventoryBackgroundCheck() {
  Workmanager().executeTask((task, inputData) async {
    await NotificationService.checkInventoryAlerts();
    return Future.value(true);
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static ValueNotifier<bool> hasCriticalAlerts = ValueNotifier(false);

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);

    Workmanager().initialize(inventoryBackgroundCheck, isInDebugMode: false);
    Workmanager().registerPeriodicTask(
      "inventory_check",
      "inventoryBackgroundCheck",
      frequency: const Duration(hours: 24),
    );
  }

  static Future<void> requestPermission(BuildContext context) async {
    if (kIsWeb) return;
    if (await Permission.notification.isDenied) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.bgDark,
          shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.primary)),
          title: const Text("SYSTEM ALERT ACCESS REQUIRED", style: TextStyle(color: AppTheme.primary, fontFamily: 'Orbitron')),
          content: const Text("Allow this system to send critical inventory and service alerts.", style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text("DENY", style: TextStyle(color: AppTheme.textGrey))
            ),
            GestureDetector(
              onTap: () async {
                Navigator.pop(ctx);
                await Permission.notification.request();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.primary.withOpacity(0.2),
                child: const Text("GRANT ACCESS", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }
  }

  static Future<void> checkInventoryAlerts() async {
    if (kIsWeb) return;
    final parts = await DatabaseHelper.instance.getInventory();
    int criticalCount = 0;

    for (var part in parts) {
      if (part.quantity <= part.reorderThreshold) {
        criticalCount++;
        await _showNotification(
          id: part.id ?? 0,
          title: "⚠ CRITICAL STOCK — ${part.name}",
          body: "Only ${part.quantity} ${part.unit} remaining. Minimum is ${part.reorderThreshold}. Restock immediately.",
          channelId: 'inventory_critical',
          channelName: 'Critical Alerts',
          importance: Importance.high,
        );
      } else if (part.quantity <= part.reorderThreshold * 1.2) {
        await _showNotification(
          id: (part.id ?? 0) + 1000,
          title: "📦 LOW STOCK — ${part.name}",
          body: "${part.quantity} ${part.unit} remaining. Approaching minimum threshold.",
          channelId: 'inventory_warning',
          channelName: 'Warning Alerts',
          importance: Importance.defaultImportance,
        );
      } else {
         await _notifications.cancel(part.id ?? 0);
         await _notifications.cancel((part.id ?? 0) + 1000);
      }
    }

    hasCriticalAlerts.value = criticalCount > 0;
    
    // THE FEATURE IS BACK! Safely updates the red dot on your app icon
    try {
      if (await AppBadgePlus.isSupported()) {
        AppBadgePlus.updateBadge(criticalCount);
      }
    } catch (e) {
      debugPrint("Badge update skipped: $e");
    }
  }

  static Future<void> showRestockConfirmation(String name, int qty) async {
    await _showNotification(
      id: 9999,
      title: "✅ RESTOCK CONFIRMED — $name",
      body: "Stock updated to $qty.",
      channelId: 'confirmations',
      channelName: 'Confirmations',
      importance: Importance.low,
    );
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required Importance importance,
  }) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: Priority.high,
      color: AppTheme.primary,
    );
    NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    await _notifications.show(id, title, body, platformDetails);
  }
}