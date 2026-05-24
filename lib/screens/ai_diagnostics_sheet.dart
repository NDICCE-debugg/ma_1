import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/models/spare_part.dart';
import 'package:ma_1/services/asset_service.dart';
import 'package:ma_1/services/predictive_maintenance_service.dart';
import 'package:ma_1/theme/app_theme.dart';

class AiDiagnosticsSheet extends StatefulWidget {
  final Map<String, dynamic> prog;
  final List<SparePart> compatibleParts;
  final VoidCallback onStateChanged;

  const AiDiagnosticsSheet({
    super.key,
    required this.prog,
    required this.compatibleParts,
    required this.onStateChanged,
  });

  @override
  State<AiDiagnosticsSheet> createState() => _AiDiagnosticsSheetState();
}

class _AiDiagnosticsSheetState extends State<AiDiagnosticsSheet> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _sub;

  String _diagnosticOutput = '';
  bool _isStreaming = true;
  bool _isActionExecuting = false;

  @override
  void initState() {
    super.initState();
    _startAiAudit();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAiAudit() {
    setState(() {
      _diagnosticOutput = 'Initializing clinical diagnostic telemetry...';
      _isStreaming = true;
    });

    try {
      final stream = PredictiveMaintenanceService.instance
          .streamAiDiagnosticReport(widget.prog, widget.compatibleParts);

      _sub = stream.listen(
        (chunk) {
          if (!mounted) return;
          setState(() {
            if (_diagnosticOutput.startsWith('Initializing') ||
                _diagnosticOutput.startsWith('An error')) {
              _diagnosticOutput = '';
            }
            _diagnosticOutput += chunk;
          });
          // Autoscroll to bottom as diagnostic text streams in
          _scrollToBottom();
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _diagnosticOutput =
                'An error occurred while compiling AI diagnostics: $err';
            _isStreaming = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isStreaming = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _diagnosticOutput =
            'Predictive engine failure. Ensure Gemini API key is configured in settings.\nError: $e';
        _isStreaming = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _scheduleService() async {
    final HospitalAsset asset = widget.prog['asset'] as HospitalAsset;
    setState(() => _isActionExecuting = true);

    final updatedAsset = HospitalAsset(
      id: asset.id,
      assetType: asset.assetType,
      modelName: asset.modelName,
      serialNumber: asset.serialNumber,
      hospitalUnit: asset.hospitalUnit,
      wardLocation: asset.wardLocation,
      status: 'MAINTENANCE',
      dateAcquired: asset.dateAcquired,
      lastServiceDate: DateTime.now().toIso8601String().split('T').first,
      serviceInterval: asset.serviceInterval,
      notes: 'AI Prognostics flagged high risk: ${widget.prog['warningMessage']}',
      imageFileName: asset.imageFileName,
      imageBytes: asset.imageBytes,
    );

    await AssetService.instance.updateAsset(updatedAsset);
    widget.onStateChanged();

    if (!mounted) return;
    setState(() => _isActionExecuting = false);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.warning,
        content: Text(
          'Machine successfully scheduled for maintenance. Bio-mechanical ticket logged.',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: Colors.white),
        ),
      ),
    );
  }

  void _reserveParts() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.success,
        content: Text(
          widget.compatibleParts.isNotEmpty
              ? 'Required parts successfully reserved in storage bins.'
              : 'Spare parts requisition order dispatched to procurement.',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final HospitalAsset asset = widget.prog['asset'] as HospitalAsset;
    final double healthScore = widget.prog['healthScore'] as double;
    final String riskLevel = widget.prog['riskLevel'] as String;
    final String warning = widget.prog['warningMessage'] as String;
    final Map<String, dynamic> telemetry =
        widget.prog['telemetry'] as Map<String, dynamic>;

    final bool isVent = asset.assetType == 'ventilator';

    final Color statusColor = riskLevel == 'HIGH'
        ? AppTheme.error
        : riskLevel == 'MEDIUM'
            ? AppTheme.warning
            : AppTheme.success;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Diagnostics Dashboard',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    Text(
                      '${asset.modelName} • ${asset.serialNumber}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.divider),

          // Core Body Content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Health circular stats display
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withValues(alpha: 0.08),
                        ),
                        child: Text(
                          '${healthScore.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Risk Index: $riskLevel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                color: statusColor,
                              ),
                            ),
                            Text(
                              warning,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Simulated Telemetry Sensors panel
                  const Text(
                    'Live Sensor Telemetry Log',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isVent)
                    _buildVentTelemetry(telemetry)
                  else
                    _buildAnesTelemetry(telemetry),

                  const SizedBox(height: 24),

                  // streaming AI diagnostic audit text
                  Row(
                    children: [
                      const Text(
                        'Gemini Diagnostic Prognostic Audit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      if (_isStreaming) ...[
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _buildMarkdown(_diagnosticOutput),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isActionExecuting ? null : _reserveParts,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18, color: AppTheme.primary),
                  label: Text(
                    widget.compatibleParts.isNotEmpty ? 'Reserve Parts' : 'Order Parts',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isActionExecuting || asset.status == 'MAINTENANCE'
                      ? null
                      : _scheduleService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isActionExecuting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.build_rounded, size: 18),
                  label: const Text(
                    'Schedule Service',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVentTelemetry(Map<String, dynamic> tel) {
    final int hours = tel['turbineHours'] as int;
    final double o2 = tel['o2Drift'] as double;
    final double pressure = tel['pressureVar'] as double;
    final int batt = tel['batteryCycles'] as int;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _telemetryMeter('Turbine Usage', '$hours hrs', hours / 18000,
            hours > 13000 ? AppTheme.warning : AppTheme.primary),
        _telemetryMeter('O2 Sensor Output', '+${o2.toStringAsFixed(1)} mV',
            o2 / 3.0, o2 > 2.4 ? AppTheme.error : AppTheme.primary),
        _telemetryMeter('Pres. Variance', '${pressure.toStringAsFixed(1)} cmH2O',
            pressure / 2.0, pressure > 1.5 ? AppTheme.warning : AppTheme.primary),
        _telemetryMeter('Battery cycles', '$batt/500', batt / 500,
            batt > 380 ? AppTheme.warning : AppTheme.primary),
      ],
    );
  }

  Widget _buildAnesTelemetry(Map<String, dynamic> tel) {
    final double gas = tel['gasDrift'] as double;
    final double soda = tel['sodalimeSat'] as double;
    final int comp = tel['compHours'] as int;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _telemetryMeter('Vaporizer Output', '+${gas.toStringAsFixed(1)}%',
            gas / 3.0, gas > 2.0 ? AppTheme.error : AppTheme.primary),
        _telemetryMeter('Sodalime Saturation', '${soda.toStringAsFixed(1)}%',
            soda / 100, soda > 72.0 ? AppTheme.warning : AppTheme.primary),
        _telemetryMeter('Compressor usage', '$comp hrs', comp / 20000,
            comp > 15000 ? AppTheme.warning : AppTheme.primary),
        _telemetryMeter('System Calib.', 'Good', 0.9, AppTheme.success),
      ],
    );
  }

  Widget _telemetryMeter(String label, String value, double ratio, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 4,
              color: color,
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdown(String text) {
    final baseStyle = const TextStyle(
      color: Color(0xFF334155),
      fontSize: 13,
      height: 1.55,
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w500,
    );

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w800, color: AppTheme.primaryDark),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        h1: baseStyle.copyWith(
          color: AppTheme.primary,
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w800,
        ),
        h2: baseStyle.copyWith(
          color: AppTheme.primary,
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
        h3: baseStyle.copyWith(
          color: AppTheme.primary,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
