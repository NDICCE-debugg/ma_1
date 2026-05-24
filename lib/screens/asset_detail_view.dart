import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/models/manual_entry.dart';
import 'package:ma_1/screens/repair_cockpit_screen.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/google_chat_service.dart';

class AssetDetailView extends StatefulWidget {
  final Map<String, dynamic> assetData;
  const AssetDetailView({super.key, required this.assetData});

  @override
  State<AssetDetailView> createState() => _AssetDetailViewState();
}

class _AssetDetailViewState extends State<AssetDetailView> {
  void _showQrDialog() {
    final String qrJson = jsonEncode({
      "asset_id": widget.assetData['id'] ?? widget.assetData['asset_id'],
      "asset_type": widget.assetData['asset_type'] ?? "ventilator",
      "model_name": widget.assetData['model_name'],
      "serial_number": widget.assetData['serial_number']
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Equipment QR Code",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: QrImageView(
                data: qrJson,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
              ),
            ),
            const SizedBox(height: 20),
            Text(
                widget.assetData['model_name']?.toString().toUpperCase() ??
                    "MODEL",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.assetData['serial_number'] ?? "",
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontFamily: 'RobotoMono')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showLogFaultSheet() {
    final descCtrl = TextEditingController();
    String severity = 'moderate';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Report Equipment Issue",
                  style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Document the fault details for the technical team.",
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              const Text("Issue Description",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: "Describe the observed fault..."),
              ),
              const SizedBox(height: 20),
              const Text("Severity Level",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(),
                items: ['critical', 'moderate', 'minor']
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.toUpperCase(),
                            style: TextStyle(
                                color: s == 'critical'
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w600))))
                    .toList(),
                onChanged: (v) => setSheetState(() => severity = v!),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                  onPressed: () async {
                    final int assetId = widget.assetData['id'] ??
                        widget.assetData['asset_id'] ??
                        1;
                    await DatabaseHelper.instance.logFault(
                      assetId: assetId,
                      description: descCtrl.text,
                      severity: severity,
                    );

                    final sentToGoogleChat =
                        await GoogleChatService.instance.sendEmergencyPageCard(
                      assetModel:
                          widget.assetData['model_name'] ?? 'Medical Asset',
                      serialNumber:
                          widget.assetData['serial_number'] ?? 'SN-N/A',
                      wardLocation: widget.assetData['ward_location'] ??
                          'Hospital ICU Ward',
                      faultDescription: descCtrl.text,
                      severity: severity,
                      loggedBy: 'Clinical Maintenance Staff',
                    );

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: AppTheme.error,
                        content: Text(sentToGoogleChat
                            ? "Issue logged and sent to Google Chat."
                            : "Issue logged. Google Chat is not configured.")));
                  },
                  child: const Text("Submit Report"),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showManualsSheet() async {
    final modelName = (widget.assetData['model_name'] ?? '').toString();
    final manuals =
        (await DatabaseHelper.instance.getManualEntriesForModel(modelName))
            .map((entry) => ManualEntry.fromMap(entry))
            .toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.38,
        maxChildSize: 0.88,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_book_outlined,
                        color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Technical Manuals',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDark),
                        ),
                        Text(
                          modelName.isEmpty
                              ? 'Uploaded local documents'
                              : modelName,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: manuals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_off_outlined,
                                size: 42,
                                color: AppTheme.neutral.withValues(alpha: 0.7)),
                            const SizedBox(height: 12),
                            const Text(
                              'No manuals uploaded for this model yet',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Use the drawer upload action to attach service PDFs, schematics, or calibration notes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: manuals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final manual = manuals[index];
                          final fileLabel = [
                            if ((manual.fileName ?? '').isNotEmpty)
                              manual.fileName,
                            if (manual.fileSize != null)
                              _formatManualSize(manual.fileSize!),
                          ].join(' | ');

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppTheme.iceBlue
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_manualIcon(manual.fileType),
                                      color: AppTheme.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        manual.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${manual.category}${fileLabel.isEmpty ? '' : ' | $fileLabel'}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        manual.content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.35,
                                            color: AppTheme.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatManualSize(int bytes) {
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

  void _openRepairCockpit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RepairCockpitScreen(assetData: widget.assetData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String type = (widget.assetData['asset_type'] ?? "Equipment").toString();
    String status = (widget.assetData['status'] ?? "Operational").toString();
    Color statusColor = status.toUpperCase() == 'OPERATIONAL'
        ? AppTheme.success
        : (status.toUpperCase() == 'OFFLINE'
            ? AppTheme.error
            : AppTheme.warning);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Equipment Details"),
        actions: [
          IconButton(
              onPressed: _showQrDialog,
              icon:
                  const Icon(Icons.qr_code_2_rounded, color: AppTheme.primary)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PRIMARY INFORMATION CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(type.toUpperCase(),
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(status,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(widget.assetData['model_name'] ?? "Unknown Model",
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text("SN: ${widget.assetData['serial_number'] ?? "N/A"}",
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                            fontFamily: 'RobotoMono')),
                    const Divider(height: 32),
                    _buildInfoRow(Icons.business_rounded, "Department",
                        widget.assetData['hospital_unit'] ?? "N/A"),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.location_on_outlined, "Location",
                        widget.assetData['ward_location'] ?? "N/A"),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.calendar_today_outlined, "Last Service",
                        widget.assetData['last_service_date'] ?? "N/A"),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 24),
            const Text("Repair Workflow",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit')),
            const SizedBox(height: 12),

            _buildCockpitBanner(),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: _buildActionButton(
                      "Repair Cockpit",
                      Icons.construction_rounded,
                      AppTheme.secondary,
                      _openRepairCockpit),
                ),
                SizedBox(
                  width: 180,
                  child: _buildActionButton(
                      "Report Issue",
                      Icons.report_problem_outlined,
                      AppTheme.error,
                      _showLogFaultSheet),
                ),
                SizedBox(
                  width: 180,
                  child: _buildActionButton(
                      "View Manuals",
                      Icons.menu_book_outlined,
                      AppTheme.primary,
                      _showManualsSheet),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCockpitBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fault-to-fix guided workflow',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Capture the fault, run triage, follow calibration checks, verify readings, and prepare a service report.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
            ),
            onPressed: _openRepairCockpit,
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

