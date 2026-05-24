import 'dart:convert';
import 'dart:typed_data';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Equipment QR Code",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                color: AppTheme.primaryDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
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
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'Outfit')),
            const SizedBox(height: 4),
            Text(widget.assetData['serial_number'] ?? "",
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'RobotoMono')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Outfit'),
            ),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.report_problem_outlined, color: AppTheme.error, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text("Report Equipment Issue",
                      style: TextStyle(
                          color: AppTheme.error,
                          fontSize: 18,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              const Text("Document the fault details for the technical team.",
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              const Text("Issue Description",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Outfit')),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                decoration: const InputDecoration(
                    hintText: "Describe the observed fault..."),
              ),
              const SizedBox(height: 18),
              const Text("Severity Level",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Outfit')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: ['critical', 'moderate', 'minor']
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.toUpperCase(),
                            style: TextStyle(
                                color: s == 'critical'
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                                fontSize: 12.5,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w800))))
                    .toList(),
                onChanged: (v) => setSheetState(() => severity = v!),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
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
              const SizedBox(height: 28),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Outfit',
                              color: AppTheme.primaryDark),
                        ),
                        Text(
                          modelName.isEmpty
                              ? 'Uploaded local documents'
                              : modelName,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
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
                                size: 48,
                                color: AppTheme.neutral.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text(
                              'No manuals uploaded for this model yet',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Outfit',
                                  fontSize: 15,
                                  color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Use the drawer upload action to attach service PDFs, schematics, or calibration notes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: manuals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.08),
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
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Outfit',
                                            fontSize: 14,
                                            color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${manual.category}${fileLabel.isEmpty ? '' : ' | $fileLabel'}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'Outfit',
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        manual.content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.4,
                                            fontFamily: 'Outfit',
                                            fontWeight: FontWeight.w500,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimaryColor = isDark ? Colors.white : AppTheme.textPrimary;

    String cleanVal(dynamic val, String fallback) {
      if (val == null) return fallback;
      final s = val.toString().trim();
      return s.isEmpty ? fallback : s;
    }

    final String type = cleanVal(widget.assetData['asset_type'] ?? widget.assetData['assetType'], "Equipment");
    final String status = cleanVal(widget.assetData['status'], "Operational");
    final String model = cleanVal(widget.assetData['model_name'] ?? widget.assetData['modelName'], "Unknown Model");
    final String serial = cleanVal(widget.assetData['serial_number'] ?? widget.assetData['serialNumber'], "N/A");
    final String unit = cleanVal(widget.assetData['hospital_unit'] ?? widget.assetData['hospitalUnit'], "N/A");
    final String ward = cleanVal(widget.assetData['ward_location'] ?? widget.assetData['wardLocation'], "N/A");
    final String lastService = cleanVal(widget.assetData['last_service_date'] ?? widget.assetData['lastServiceDate'], "N/A");
    final String acquired = cleanVal(widget.assetData['date_acquired'] ?? widget.assetData['dateAcquired'], "N/A");
    final String interval = cleanVal(widget.assetData['service_interval'] ?? widget.assetData['serviceInterval'], "180");
    final String notes = cleanVal(widget.assetData['notes'], "None logged");

    final String intervalDisplay = interval == "N/A" ? "N/A" : "$interval Days";

    final Color statusColor = status.toUpperCase() == 'OPERATIONAL'
        ? AppTheme.success
        : (status.toUpperCase() == 'OFFLINE'
            ? AppTheme.error
            : AppTheme.warning);

    final rawBytes = widget.assetData['image_bytes'] ?? widget.assetData['imageBytes'];
    final Uint8List? imageBytes = rawBytes != null
        ? (rawBytes is String ? base64Decode(rawBytes) : Uint8List.fromList(List<int>.from(rawBytes)))
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Asset Dossier"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              tooltip: 'Equipment QR Identity tag',
              onPressed: _showQrDialog,
              icon: Icon(Icons.qr_code_2_rounded, color: isDark ? Colors.white : AppTheme.primary, size: 24)),
        ],
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // --- 1. Immersive Hero Product Showcase Banner ---
          _buildHeroHeader(type, model, serial, status, statusColor, imageBytes)
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 18),

          // --- 2. Futuristic Specifications Grid (Dashboard-style specification chips) ---
          Text(
            "Hardware Specifications",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.1,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _buildSpecTile(Icons.business_rounded, "Clinical Unit", unit, const Color(0xFF3B82F6)),
              _buildSpecTile(Icons.location_on_outlined, "Location Room", ward, const Color(0xFF8B5CF6)),
              _buildSpecTile(Icons.history_toggle_off_rounded, "Last Service", lastService, const Color(0xFFF59E0B)),
              _buildSpecTile(Icons.verified_outlined, "Service Interval", intervalDisplay, const Color(0xFF10B981)),
              _buildSpecTile(Icons.shopping_bag_outlined, "Acquisition Date", acquired, const Color(0xFF64748B)),
              _buildSpecTile(Icons.notes_outlined, "Notes Profile", notes, const Color(0xFF0F766E)),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          const SizedBox(height: 24),

          // --- 3. Fault-to-Fix Interactive Holographic Banner ---
          Text(
            "Guided Repair Workflows",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildCockpitBanner()
              .animate()
              .fadeIn(duration: 400.ms, delay: 150.ms)
              .scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1), curve: Curves.easeOutCubic),
          const SizedBox(height: 18),

          // --- 4. Responsive Action List Blades (Polished touch gestures) ---
          Column(
            children: [
              _buildActionTile(
                "Diagnostic Repair Cockpit",
                "Execute active triage calibrations & checklist safety",
                Icons.construction_rounded,
                AppTheme.secondary,
                _openRepairCockpit,
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                "Log Urgent Equipment Issue",
                "Log anomalies & dispatch alert to Google Chat",
                Icons.report_problem_outlined,
                AppTheme.error,
                _showLogFaultSheet,
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                "View Technical Manuals",
                "Read service guides, operational PDFs, & schematics",
                Icons.menu_book_outlined,
                AppTheme.primary,
                _showManualsSheet,
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(
    String type,
    String model,
    String serial,
    String status,
    Color statusColor,
    Uint8List? imageBytes,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0A1518) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF24353A) : const Color(0xFFE2E8F0);
    final textPrimaryColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary;
    
    final headerGradientStart = isDark ? const Color(0xFF111F23) : const Color(0xFFF8FAFC);
    final headerGradientEnd = isDark ? const Color(0xFF0A1518) : const Color(0xFFE2E8F0);
    final innerIconContainerBg = isDark ? const Color(0xFF0A1518) : Colors.white.withValues(alpha: 0.8);
    final iconColor = isDark ? AppTheme.secondary : AppTheme.primary;
    final typeBadgeBg = isDark ? AppTheme.secondary.withValues(alpha: 0.15) : AppTheme.primary.withValues(alpha: 0.08);
    final typeBadgeText = isDark ? AppTheme.secondary : AppTheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.015),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cybernetic visual frame gradient header
          Container(
            height: 190,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  headerGradientStart,
                  headerGradientEnd,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: imageBytes != null
                ? Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                  )
                : Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: innerIconContainerBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Icon(
                        type.toLowerCase() == 'ventilator'
                            ? Icons.air_outlined
                            : Icons.vaccines_outlined,
                        color: iconColor,
                        size: 48,
                      ),
                    ),
                  ),
          ),
          // Details block
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeBadgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: typeBadgeText,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Outfit',
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    // Pulsing beacon status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ).animate(onPlay: (c) => c.repeat(reverse: true))
                           .scale(begin: const Offset(1, 1), end: const Offset(1.4, 1.4), duration: 800.ms),
                          const SizedBox(width: 6),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  model,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.fingerprint_rounded, size: 14, color: textSecondaryColor),
                    const SizedBox(width: 6),
                    Text(
                      'SN: $serial',
                      style: TextStyle(
                        color: textSecondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'RobotoMono',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecTile(IconData icon, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0A1518) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF24353A) : const Color(0xFFE8EEF1);
    final textPrimaryColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCockpitBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Capture the fault, run triage, follow calibration checks, and prepare service reports.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'Outfit'),
            ),
            onPressed: _openRepairCockpit,
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0A1518) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF24353A) : const Color(0xFFE2E8F0);
    final textSecondaryColor = isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isDark && color == AppTheme.primary ? Colors.white : color,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: textSecondaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
