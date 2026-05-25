import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/screens/profile_edit_screen.dart';
import 'package:ma_1/screens/settings_screens.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/screens/login_screen.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/rag_api_service.dart';

class PulseAccountDrawer extends StatefulWidget {
  const PulseAccountDrawer({super.key});

  @override
  State<PulseAccountDrawer> createState() => _PulseAccountDrawerState();
}

class _PulseAccountDrawerState extends State<PulseAccountDrawer> {
  // Dialog upload states
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _attachedFileName;
  String? _attachedFileType;
  int? _attachedFileSize;
  Uint8List? _attachedFileBytes;

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _manualIcon(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_outlined;
      case 'txt':
      case 'csv':
        return Icons.description_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  String _manualContentSummary(
      Uint8List bytes, String? extension, String fileName) {
    final normalized = (extension ?? '').toLowerCase();
    if (normalized == 'txt' || normalized == 'csv') {
      try {
        final text = utf8.decode(bytes, allowMalformed: true).trim();
        if (text.isNotEmpty) {
          return text.length > 40000 ? text.substring(0, 40000) : text;
        }
      } catch (_) {
        // Fall through to metadata summary when the document is not text-decodable.
      }
    }
    return 'Uploaded manual file: $fileName (${_formatFileSize(bytes.length)}). Stored locally for technician reference and AI diagnostic context.';
  }

  Future<void> _pickManualFile(
      void Function(void Function()) setDialogState) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    setDialogState(() {
      _attachedFileName = file.name;
      _attachedFileType = file.extension;
      _attachedFileSize = file.size;
      _attachedFileBytes = bytes;
    });
  }

  void _showUploadManualDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    String selectedModel = "Aeonmed VG70";
    String selectedCategory = "Service Manual";
    _attachedFileName = null;
    _attachedFileType = null;
    _attachedFileSize = null;
    _attachedFileBytes = null;
    _isUploading = false;
    _uploadProgress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: !_isUploading,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.upload_file_outlined,
                  color: AppTheme.primary, size: 24),
              SizedBox(width: 10),
              Text(
                "Upload Technical Manual",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark,
                    fontFamily: 'Outfit'),
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
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: titleCtrl,
                  onChanged: (_) => setDialogState(() {}),
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: "Manual Title / Document Identifier",
                    hintText: "e.g. VG70 Expiratory Valve Calibration Guide",
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedModel,
                  style: const TextStyle(
                      fontFamily: 'Outfit', color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                      labelText: "Compatible Machine Model"),
                  items: [
                    "Aeonmed VG70",
                    "Drager Evita V500",
                    "Mindray A5",
                    "WATO EX-35"
                  ]
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedModel = val!),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  style: const TextStyle(
                      fontFamily: 'Outfit', color: AppTheme.textPrimary),
                  decoration:
                      const InputDecoration(labelText: "Manual Category"),
                  items: [
                    "Operation Manual",
                    "Service Manual",
                    "Calibration Guide",
                    "Schematic / Drawing"
                  ]
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 20),

                const Text(
                  "Document Upload Attachment",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 8),

                // Interactive upload area
                InkWell(
                  onTap: _isUploading
                      ? null
                      : () => _pickManualFile(setDialogState),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.background.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _attachedFileName != null
                            ? AppTheme.success
                            : AppTheme.border,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _attachedFileName != null
                              ? _manualIcon(_attachedFileType)
                              : Icons.cloud_upload_outlined,
                          size: 32,
                          color: _attachedFileName != null
                              ? AppTheme.success
                              : AppTheme.neutral,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _attachedFileName ?? "Attach PDF Document File",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _attachedFileName != null
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        if (_attachedFileName != null &&
                            _attachedFileSize != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatFileSize(_attachedFileSize),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.neutral,
                                  fontFamily: 'Outfit'),
                            ),
                          ),
                        if (_attachedFileName == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "PDF service manuals only",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.neutral,
                                  fontFamily: 'Outfit'),
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
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                            fontFamily: 'Outfit'),
                      ),
                      Text(
                        "${(_uploadProgress * 100).toInt()}%",
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                            fontFamily: 'Outfit'),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: (_isUploading ||
                      _attachedFileName == null ||
                      _attachedFileBytes == null ||
                      titleCtrl.text.trim().isEmpty)
                  ? null
                  : () async {
                      setDialogState(() {
                        _isUploading = true;
                        _uploadProgress = 0.0;
                      });

                      final progressTimer = Timer.periodic(
                          const Duration(milliseconds: 220), (_) {
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          _uploadProgress =
                              (_uploadProgress + 0.08).clamp(0.0, 0.92);
                        });
                      });

                      final bytes = _attachedFileBytes!;
                      try {
                        await DatabaseHelper.instance.addManualEntry({
                          'machine_model': selectedModel,
                          'category': selectedCategory,
                          'title': titleCtrl.text.trim(),
                          'content': _manualContentSummary(
                              bytes, _attachedFileType, _attachedFileName!),
                          'file_name': _attachedFileName,
                          'file_type': _attachedFileType,
                          'file_size': bytes.length,
                          'file_bytes': bytes,
                          'uploaded_at':
                              DateTime.now().toUtc().toIso8601String(),
                        });

                        final result =
                            await RagApiService.instance.uploadAndIndexManual(
                          title: titleCtrl.text.trim(),
                          machineModel: selectedModel,
                          category: selectedCategory,
                          fileName: _attachedFileName!,
                          fileType: _attachedFileType,
                          bytes: bytes,
                        );

                        progressTimer.cancel();
                        if (!ctx.mounted) return;
                        setDialogState(() => _uploadProgress = 1.0);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTheme.success,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Indexed '${titleCtrl.text}' with ${result.chunks} searchable manual chunks.",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Outfit',
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } catch (e) {
                        progressTimer.cancel();
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          _isUploading = false;
                          _uploadProgress = 0.0;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTheme.warning,
                            content: Text(
                              'Saved locally, but cloud RAG indexing failed: $e',
                              style: const TextStyle(fontFamily: 'Outfit'),
                            ),
                          ),
                        );
                      }
                    },
              child: const Text("Index Manual",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
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
    final String name =
        user?.userMetadata?['name'] as String? ?? "Tadiwanashe M.";
    final String reg =
        user?.userMetadata?['reg_number'] as String? ?? "REG: 2026-HIT-04";
    final String initial =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "T";

    return Drawer(
      backgroundColor: isDark ? AppTheme.midnightBlue : AppTheme.surface,
      child: Column(
        children: [
          _buildHeader(context, isDark, name, reg, initial),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerTile(context, Icons.account_circle_outlined,
                    "My Profile", const ProfileEditScreen()),

                // --- CUSTOM FILE UPLOAD TRIGGER ---
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                  leading: _drawerIcon(Icons.post_add_rounded),
                  title: const Text("Upload Technical Manual",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Outfit')),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppTheme.neutral),
                  onTap: () {
                    Navigator.pop(context); // Close Drawer
                    _showUploadManualDialog(
                        context); // Trigger beautiful custom popup
                  },
                ),

                _drawerTile(context, Icons.notifications_active_outlined,
                    "Notifications", const NotificationSettingsScreen()),
                _drawerTile(context, Icons.tune_rounded, "Appearance Settings",
                    const AppearanceScreen()),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Divider(height: 1, color: AppTheme.divider),
                ),
                _drawerTile(context, Icons.admin_panel_settings_outlined,
                    "Safety & Privacy Protocols", const SafetyScreen()),
                _drawerTile(context, Icons.support_agent_rounded,
                    "Diagnostic Support", const HelpScreen()),
                _drawerTile(context, Icons.forum_outlined, "Liaison Desk",
                    const SupportScreen()),
                _drawerTile(context, Icons.info_rounded, "About System",
                    const AboutScreen()),
              ],
            ),
          ),
          _buildFooter(context, isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, String name,
      String reg, String initial) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ProfileEditScreen())),
      child: Container(
        padding:
            const EdgeInsets.only(top: 56, left: 18, right: 18, bottom: 18),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(bottom: BorderSide(color: AppTheme.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      fontFamily: 'Outfit')),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          fontFamily: 'Outfit')),
                  const SizedBox(height: 3),
                  Text(reg,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit')),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.muted,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: const Text("Clinical engineer",
                        style: TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Outfit')),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
      BuildContext context, IconData icon, String title, Widget screen) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: _drawerIcon(icon),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontFamily: 'Outfit')),
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 18, color: AppTheme.neutral),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text("Sign Out Session",
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        ),
      ),
    );
  }

  Widget _drawerIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.divider),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: AppTheme.secondary, size: 20),
    );
  }
}
