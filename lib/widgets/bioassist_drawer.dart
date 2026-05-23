import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/screens/profile_edit_screen.dart';
import 'package:ma_1/screens/settings_screens.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/screens/login_screen.dart';

class BioAssistDrawer extends StatelessWidget {
  const BioAssistDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: Column(
        children: [
          _buildHeader(context, isDark),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerTile(context, Icons.person_outline, "My Profile", const ProfileEditScreen()),
                _drawerTile(context, Icons.notifications_none, "Notifications", const NotificationSettingsScreen()),
                _drawerTile(context, Icons.palette_outlined, "Appearance", const AppearanceScreen()),
                const Divider(height: 32, indent: 20, endIndent: 20),
                _drawerTile(context, Icons.shield_outlined, "Safety and Privacy", const SafetyScreen()),
                _drawerTile(context, Icons.help_outline, "Help", const HelpScreen()),
                _drawerTile(context, Icons.chat_bubble_outline, "Support", const SupportScreen()),
                _drawerTile(context, Icons.info_outline, "About", const AboutScreen()),
              ],
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen())),
      child: Container(
        padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
        color: isDark ? const Color(0xFF162032) : AppTheme.primaryDark,
        child: const Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primary,
              child: Text("TM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tadiwanashe M.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("REG: 2026-HIT-04", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 14),
                      Icon(Icons.star, color: Colors.amber, size: 14),
                      Icon(Icons.star, color: Colors.amber, size: 14),
                      Icon(Icons.star, color: Colors.amber, size: 14),
                      Icon(Icons.star_half, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text("4.5", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(BuildContext context, IconData icon, String title, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.neutral, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: OutlinedButton.icon(
        onPressed: () async {
          await AuthService.instance.signOut();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text("Sign Out", style: TextStyle(color: Colors.red)),
      ),
    );
  }
}