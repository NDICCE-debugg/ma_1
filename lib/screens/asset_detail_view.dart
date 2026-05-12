import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/utils/animation_helper.dart';
import 'package:ma_1/services/database_helper.dart';

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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: HudBrackets(
          child: Container(
            padding: const EdgeInsets.all(20),
            color: AppTheme.bgDark.withOpacity(0.9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("ASSET IDENTIFICATION CODE", style: TextStyle(color: AppTheme.primary, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppTheme.primary, width: 3)),
                  child: QrImageView(
                    data: qrJson,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(color: AppTheme.primary.withOpacity(0.2), duration: 2.seconds),
                const SizedBox(height: 20),
                Text(widget.assetData['model_name'].toUpperCase(), style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontSize: 18)),
                Text(widget.assetData['serial_number'], style: const TextStyle(color: AppTheme.warning, fontFamily: 'Share Tech Mono')),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), border: Border.all(color: AppTheme.primary)),
                    child: const Text("CLOSE HUD", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      )
    );
  }

  void _showLogFaultSheet() {
    final descCtrl = TextEditingController();
    String severity = 'critical';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgDark,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("LOG SYSTEM FAULT", style: TextStyle(color: AppTheme.error, fontSize: 18, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              const Text("> FAULT DESCRIPTION", style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                child: TextField(controller: descCtrl, maxLines: 3, style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'), decoration: const InputDecoration(border: InputBorder.none)),
              ),
              const SizedBox(height: 15),

              const Text("> SEVERITY LEVEL", style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
              const SizedBox(height: 5),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                  child: DropdownButton<String>(
                    value: severity, dropdownColor: AppTheme.bgLight, isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'),
                    items: ['critical', 'moderate', 'minor'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: TextStyle(color: s == 'critical' ? AppTheme.error : AppTheme.warning)))).toList(),
                    onChanged: (v) => setSheetState(() => severity = v!),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () async {
                  final db = await DatabaseHelper.instance.database;
                  await db.insert('fault_log', {
                    'asset_id': widget.assetData['id'] ?? widget.assetData['asset_id'],
                    'fault_description': descCtrl.text,
                    'severity': severity,
                    'logged_by': 'TECH-01', // Should pull from auth
                    'logged_date': DateTime.now().toIso8601String(),
                    'is_synced': 0
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppTheme.error, content: Text("FAULT LOGGED SECURELY", style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold))));
                },
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.2), border: Border.all(color: AppTheme.error)),
                  child: const Text("TRANSMIT FAULT", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String type = (widget.assetData['asset_type'] ?? "UNKNOWN").toString().toUpperCase();
    String status = (widget.assetData['status'] ?? "OPERATIONAL").toString().toUpperCase();
    Color statusColor = status == 'OPERATIONAL' ? AppTheme.accent : (status == 'OFFLINE' ? AppTheme.error : AppTheme.warning);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.primary), onPressed: () => Navigator.pop(context)),
        title: const Text("ASSET DOSSIER", style: TextStyle(fontFamily: 'Orbitron', color: AppTheme.primary, letterSpacing: 2)),
      ),
      body: ScanlineWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER CARD
              HudBrackets(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("[$type]", style: const TextStyle(color: AppTheme.textGrey, fontSize: 12, fontFamily: 'Share Tech Mono')),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(border: Border.all(color: statusColor)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(widget.assetData['model_name'] ?? "UNKNOWN MODEL", style: const TextStyle(color: Colors.white, fontSize: 24, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, shadows: [Shadow(color: AppTheme.primary, blurRadius: 15)])),
                    Text(widget.assetData['serial_number'] ?? "SN-UNKNOWN", style: const TextStyle(color: AppTheme.warning, fontSize: 14, fontFamily: 'Share Tech Mono')),
                    const Divider(color: Colors.white24, height: 30),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 5),
                        Text("${widget.assetData['hospital_unit']} — ${widget.assetData['ward_location']}", style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.build, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 5),
                        Text("LAST SVC: ${widget.assetData['last_service_date']}", style: const TextStyle(color: Colors.white54, fontFamily: 'Share Tech Mono')),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),

              // ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showLogFaultSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.2), border: Border.all(color: AppTheme.error)),
                        child: const Column(children: [Icon(Icons.warning_amber, color: AppTheme.error), SizedBox(height: 5), Text("LOG FAULT", style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.bold))]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showQrDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), border: Border.all(color: AppTheme.primary)),
                        child: const Column(children: [Icon(Icons.qr_code, color: AppTheme.primary), SizedBox(height: 5), Text("SHOW QR", style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold))]),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}