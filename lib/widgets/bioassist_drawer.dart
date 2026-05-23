import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/screens/profile_edit_screen.dart';
import 'package:ma_1/screens/settings_screens.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/screens/login_screen.dart';
import 'package:ma_1/services/database_helper.dart';

class BioAssistDrawer extends StatefulWidget {
  const BioAssistDrawer({super.key});

  @override
  State<BioAssistDrawer> createState() => _BioAssistDrawerState();
}

class _BioAssistDrawerState extends State<BioAssistDrawer> {
  // Dialog upload states
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _attachedFileName;

  void _showUploadManualDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    String selectedModel = "Aeonmed VG70";
    String selectedCategory = "Service Manual";
    _attachedFileName = null;
    _isUploading = false;
    _uploadProgress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: !_isUploading,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.upload_file_outlined, color: AppTheme.primary, size: 24),
              SizedBox(width: 10),
              Text(
                "Upload Technical Manual",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryDark, fontFamily: 'Outfit'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Provision standard PDF manuals to expand AI Diagnostic Help RAG indexing.",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 20),
                
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: "Manual Title / Document Identifier",
                    hintText: "e.g. VG70 Expiratory Valve Calibration Guide",
                  ),
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  initialValue: selectedModel,
                  style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: "Compatible Machine Model"),
                  items: ["Aeonmed VG70", "Dräger Evita V500", "Mindray A5", "WATO EX-35"]
                      .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedModel = val!),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  style: const TextStyle(fontFamily: 'Outfit', color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: "Manual Category"),
                  items: ["Operation Manual", "Service Manual", "Calibration Guide", "Schematic / Drawing"]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 20),
                
                const Text(
                  "Document Upload Attachment",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary, fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 8),

                // Interactive upload area
                InkWell(
                  onTap: _isUploading
                      ? null
                      : () {
                          // Simulate PDF file selection
                          setDialogState(() {
                            _attachedFileName = "${selectedModel.toLowerCase().replaceAll(' ', '_')}_${selectedCategory.toLowerCase().replaceAll(' ', '_')}.pdf";
                          });
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.background.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _attachedFileName != null ? AppTheme.success : AppTheme.border,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _attachedFileName != null ? Icons.picture_as_pdf : Icons.cloud_upload_outlined,
                          size: 32,
                          color: _attachedFileName != null ? AppTheme.success : AppTheme.neutral,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _attachedFileName ?? "Attach PDF Document File",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _attachedFileName != null ? AppTheme.success : AppTheme.textSecondary,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        if (_attachedFileName == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "Click to provision standard file selector",
                              style: TextStyle(fontSize: 10, color: AppTheme.neutral, fontFamily: 'Outfit'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                if (_isUploading) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Indexing Manual & Scanning for RAG...",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary, fontFamily: 'Outfit'),
                      ),
                      Text(
                        "${(_uploadProgress * 100).toInt()}%",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Outfit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 6,
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.divider,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isUploading ? null : () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: (_isUploading || _attachedFileName == null || titleCtrl.text.trim().isEmpty)
                  ? null
                  : () {
                      setDialogState(() {
                        _isUploading = true;
                        _uploadProgress = 0.0;
                      });

                      // Animate high fidelity upload progress
                      Timer.periodic(const Duration(milliseconds: 150), (timer) async {
                        if (_uploadProgress < 1.0) {
                          setDialogState(() {
                            _uploadProgress = (_uploadProgress + 0.1).clamp(0.0, 1.0);
                          });
                        } else {
                          timer.cancel();
                          
                          // Save to local manual_entries database
                          await DatabaseHelper.instance.addManualEntry({
                            'machine_model': selectedModel,
                            'category': selectedCategory,
                            'title': titleCtrl.text.trim(),
                            'content': "Indexed PDF File: $_attachedFileName. Provisioned in local RAG memory storage successfully."
                          });

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppTheme.success,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Technical manual '${titleCtrl.text}' successfully uploaded and indexed for diagnostics!",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }
                      });
                    },
              child: const Text("Index Manual", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            ),
          ],
        ),
      ),
    );
  }

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
                
                // --- CUSTOM FILE UPLOAD TRIGGER ---
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                  leading: const Icon(Icons.upload_file_outlined, color: AppTheme.secondary, size: 22),
                  title: const Text(
                    "Upload Technical Manual", 
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: 'Outfit')
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.neutral),
                  onTap: () {
                    Navigator.pop(context); // Close Drawer
                    _showUploadManualDialog(context); // Trigger beautiful custom popup
                  },
                ),
                
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