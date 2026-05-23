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
    
    // Dynamic authenticated technician details
    final user = AuthService.instance.currentUser;
    final String name = user?.userMetadata?['name'] as String? ?? "Tadiwanashe M.";
    final String reg = user?.userMetadata?['reg_number'] as String? ?? "REG: 2026-HIT-04";
    final String initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "T";

    return Drawer(
      backgroundColor: isDark ? AppTheme.midnightBlue : Colors.white,
      child: Column(
        children: [
          _buildHeader(context, isDark, name, reg, initial),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerTile(context, Icons.person_outline_rounded, "My Profile", const ProfileEditScreen()),
                _drawerTile(context, Icons.notifications_none_rounded, "Notifications", const NotificationSettingsScreen()),
                _drawerTile(context, Icons.palette_outlined, "Appearance Settings", const AppearanceScreen()),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Divider(height: 1, color: AppTheme.divider),
                ),
                _drawerTile(context, Icons.shield_outlined, "Safety & Privacy Protocols", const SafetyScreen()),
                _drawerTile(context, Icons.help_outline_rounded, "Diagnostic Support", const HelpScreen()),
                _drawerTile(context, Icons.chat_bubble_outline_rounded, "Liaison Desk", const SupportScreen()),
                _drawerTile(context, Icons.info_outline_rounded, "About System", const AboutScreen()),
              ],
            ),
          ),
          _buildFooter(context, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, String name, String reg, String initial) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen())),
      child: Container(
        padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 24),
        decoration: BoxDecoration(
          color: AppTheme.midnightBlue,
          border: Border(
            bottom: BorderSide(color: AppTheme.iceBlue.withValues(alpha: 0.15), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.iceBlue.withValues(alpha: 0.15),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.iceBlue.withValues(alpha: 0.4), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial, 
                  style: const TextStyle(color: AppTheme.iceBlue, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Outfit')
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name, 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit')
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reg, 
                    style: const TextStyle(color: AppTheme.softBlue, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit')
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const Icon(Icons.star_half_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "4.8 Rating", 
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit')
                      ),
                    ],
                  )
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.softBlue),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(BuildContext context, IconData icon, String title, Widget screen) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: Icon(icon, color: AppTheme.secondary, size: 22),
      title: Text(
        title, 
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: 'Outfit')
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.neutral),
      onTap: () {
        Navigator.pop(context); // Close Drawer
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 48,
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
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.error, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text("Sign Out Session", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        ),
      ),
    );
  }
}