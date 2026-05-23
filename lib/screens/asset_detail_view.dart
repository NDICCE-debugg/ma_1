import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
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
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Equipment QR Code", 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
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
            Text(widget.assetData['model_name']?.toString().toUpperCase() ?? "MODEL", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.assetData['serial_number'] ?? "", 
              style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'RobotoMono')),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Report Equipment Issue", 
                style: TextStyle(color: AppTheme.error, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Document the fault details for the technical team.", 
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              
              const Text("Issue Description", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl, 
                maxLines: 3, 
                decoration: const InputDecoration(hintText: "Describe the observed fault..."),
              ),
              const SizedBox(height: 20),

              const Text("Severity Level", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: severity,
                decoration: const InputDecoration(),
                items: ['critical', 'moderate', 'minor'].map((s) => DropdownMenuItem(
                  value: s, 
                  child: Text(s.toUpperCase(), 
                  style: TextStyle(color: s == 'critical' ? AppTheme.error : AppTheme.textPrimary, fontWeight: FontWeight.w600))
                )).toList(),
                onChanged: (v) => setSheetState(() => severity = v!),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                  onPressed: () async {
                    final int assetId = widget.assetData['id'] ?? widget.assetData['asset_id'] ?? 1;
                    await DatabaseHelper.instance.logFault(
                      assetId: assetId,
                      description: descCtrl.text,
                      severity: severity,
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: AppTheme.error, content: Text("Issue logged successfully"))
                    );
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

  @override
  Widget build(BuildContext context) {
    String type = (widget.assetData['asset_type'] ?? "Equipment").toString();
    String status = (widget.assetData['status'] ?? "Operational").toString();
    Color statusColor = status.toUpperCase() == 'OPERATIONAL' ? AppTheme.success : (status.toUpperCase() == 'OFFLINE' ? AppTheme.error : AppTheme.warning);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Equipment Details"),
        actions: [
          IconButton(onPressed: _showQrDialog, icon: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primary)),
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
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(widget.assetData['model_name'] ?? "Unknown Model", 
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text("SN: ${widget.assetData['serial_number'] ?? "N/A"}", 
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontFamily: 'RobotoMono')),
                    const Divider(height: 32),
                    
                    _buildInfoRow(Icons.business_rounded, "Department", widget.assetData['hospital_unit'] ?? "N/A"),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.location_on_outlined, "Location", widget.assetData['ward_location'] ?? "N/A"),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.calendar_today_outlined, "Last Service", widget.assetData['last_service_date'] ?? "N/A"),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
            
            const SizedBox(height: 24),
            const Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    "Report Issue", 
                    Icons.report_problem_outlined, 
                    AppTheme.error, 
                    _showLogFaultSheet
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    "View Manuals", 
                    Icons.menu_book_outlined, 
                    AppTheme.primary, 
                    () {}
                  ),
                ),
              ],
            ),
          ],
        ),
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
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}