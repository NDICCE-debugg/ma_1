import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';

/// Central utility for showing styled, floating popup feedback messages.
///
/// Usage:
///   AppSnackBar.success(context, 'Asset registered successfully.');
///   AppSnackBar.error(context, 'Failed to delete. Try again.');
///   AppSnackBar.warning(context, 'Saved locally. Cloud sync pending.');
///   AppSnackBar.info(context, 'Sensor values updated.');
class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, _Type.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _Type.error);

  static void warning(BuildContext context, String message) =>
      _show(context, message, _Type.warning);

  static void info(BuildContext context, String message) =>
      _show(context, message, _Type.info);

  static void _show(BuildContext context, String message, _Type type) {
    if (!context.mounted) return;

    final (Color bg, Color fg, IconData icon) = switch (type) {
      _Type.success => (AppTheme.success, Colors.white, Icons.check_circle_rounded),
      _Type.error   => (AppTheme.error,   Colors.white, Icons.error_rounded),
      _Type.warning => (AppTheme.warning, Colors.white, Icons.warning_amber_rounded),
      _Type.info    => (AppTheme.primary, Colors.white, Icons.info_rounded),
    };

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bg,
          // Appear quickly, dismiss quickly — don't block the user
          duration: const Duration(milliseconds: 2800),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
          content: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

enum _Type { success, error, warning, info }
