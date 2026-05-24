import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color glassBg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.93) // Tailwind slate-900 glass
        : const Color(0xFFF8FAFC).withValues(alpha: 0.94); // Tailwind slate-50 glass
    final Color borderCol = isDark
        ? const Color(0xFF334155).withValues(alpha: 0.8)
        : const Color(0xFFE2E8F0);

    final Color buttonPrimaryColor = isDark ? AppTheme.iceBlue : AppTheme.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.92,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(
            color: glassBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: borderCol, width: 1.5),
              left: BorderSide(color: borderCol.withValues(alpha: 0.4)),
              right: BorderSide(color: borderCol.withValues(alpha: 0.4)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HUD Cybernetic Header Bar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.classicBlue.withValues(alpha: 0.25),
                          AppTheme.classicBlue.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.classicBlue.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.classicBlue.withValues(alpha: 0.15),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: AppTheme.ring, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'PULSE AI PROGNOSTICS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                letterSpacing: 1.5,
                                color: isDark ? AppTheme.iceBlue : AppTheme.classicBlue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                'LIVE RUNTIME',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Diagnostics Command Panel',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Outfit',
                            color: isDark ? Colors.white : AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${asset.modelName} • Serial: ${asset.serialNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Outfit',
                            color: isDark ? Colors.white70 : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : AppTheme.primary, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: borderCol),

              // Core Body Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cybernetic Risk Analyzer Card
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    statusColor.withValues(alpha: 0.15),
                                    const Color(0xFF0F172A).withValues(alpha: 0.4),
                                  ]
                                : [
                                    statusColor.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0.8),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            // Radial glow indicator
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 62,
                                  height: 62,
                                  child: CircularProgressIndicator(
                                    value: healthScore / 100.0,
                                    strokeWidth: 5,
                                    color: statusColor,
                                    backgroundColor: isDark
                                        ? Colors.white10
                                        : Colors.black.withValues(alpha: 0.06),
                                  ),
                                ),
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusColor.withValues(alpha: 0.12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${healthScore.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Outfit',
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: statusColor, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'RISK INDEX: $riskLevel',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Outfit',
                                          letterSpacing: 1.0,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    warning,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Outfit',
                                      color: isDark ? Colors.white70 : AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Cyber pulse visual bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      height: 6,
                                      width: double.infinity,
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: healthScore / 100.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                statusColor,
                                                statusColor.withValues(alpha: 0.6),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Simulated Telemetry Sensors panel
                      Row(
                        children: [
                          Icon(Icons.query_stats_rounded, color: isDark ? Colors.white70 : AppTheme.textSecondary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Live Device Sensor Channels',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (isVent)
                        _buildVentTelemetry(telemetry)
                      else
                        _buildAnesTelemetry(telemetry),

                      const SizedBox(height: 24),

                      // Streaming AI Diagnostic Title Bar
                      Row(
                        children: [
                          Icon(
                            Icons.terminal_rounded,
                            color: isDark ? AppTheme.iceBlue : AppTheme.classicBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI SYSTEM AUDIT TERMINAL',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              letterSpacing: 1.2,
                              color: isDark ? AppTheme.iceBlue : AppTheme.primaryDark,
                            ),
                          ),
                          const Spacer(),
                          if (_isStreaming) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.ring.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.ring.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 8,
                                    height: 8,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppTheme.ring,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'STREAMING...',
                                    style: TextStyle(
                                      color: isDark ? AppTheme.iceBlue : AppTheme.primary,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'AUDIT COMPLETED',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Cyberpunk Terminal Glass Container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF030712), // Deep pitch dark console
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isStreaming ? AppTheme.ring.withValues(alpha: 0.4) : const Color(0xFF1E293B),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isStreaming
                                  ? AppTheme.ring.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Console header visual
                            Row(
                              children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent)),
                                const SizedBox(width: 4),
                                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amberAccent)),
                                const SizedBox(width: 4),
                                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent)),
                                const SizedBox(width: 12),
                                const Text(
                                  'pulse-ai-prognostics.sh',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, color: Color(0xFF1E293B)),
                            _buildMarkdown(_diagnosticOutput),
                          ],
                        ),
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
                        side: BorderSide(color: buttonPrimaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.inventory_2_outlined, size: 18, color: buttonPrimaryColor),
                      label: Text(
                        widget.compatibleParts.isNotEmpty ? 'Reserve Parts' : 'Order Parts',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                          color: buttonPrimaryColor,
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
        ),
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
      childAspectRatio: 2.2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _telemetryMeter('Turbine Usage', '$hours hrs', hours / 18000,
            hours > 13000 ? AppTheme.warning : AppTheme.classicBlue),
        _telemetryMeter('O2 Sensor Output', '+${o2.toStringAsFixed(1)} mV',
            o2 / 3.0, o2 > 2.4 ? AppTheme.error : AppTheme.classicBlue),
        _telemetryMeter('Pres. Variance', '${pressure.toStringAsFixed(1)} cmH2O',
            pressure / 2.0, pressure > 1.5 ? AppTheme.warning : AppTheme.classicBlue),
        _telemetryMeter('Battery cycles', '$batt/500', batt / 500,
            batt > 380 ? AppTheme.warning : AppTheme.classicBlue),
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
      childAspectRatio: 2.2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _telemetryMeter('Vaporizer Output', '+${gas.toStringAsFixed(1)}%',
            gas / 3.0, gas > 2.0 ? AppTheme.error : AppTheme.classicBlue),
        _telemetryMeter('Sodalime Saturation', '${soda.toStringAsFixed(1)}%',
            soda / 100, soda > 72.0 ? AppTheme.warning : AppTheme.classicBlue),
        _telemetryMeter('Compressor usage', '$comp hrs', comp / 20000,
            comp > 15000 ? AppTheme.warning : AppTheme.classicBlue),
        _telemetryMeter('System Calib.', 'Good', 0.9, AppTheme.success),
      ],
    );
  }

  Widget _telemetryMeter(String label, String value, double ratio, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.85);
    final borderCol = isDark
        ? const Color(0xFF334155).withValues(alpha: 0.8)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white60 : AppTheme.textSecondary,
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                ),
              )
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 5,
              color: color,
              backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdown(String text) {
    final bool hasError = text.contains('error') || text.contains('Exception') || text.contains('failure');

    final baseStyle = TextStyle(
      color: hasError ? const Color(0xFFFDA4AF) : const Color(0xFFD1D5DB), // Rose-pink for errors, light gray for text
      fontSize: 13,
      height: 1.6,
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w500,
    );

    final highlightColor = hasError ? const Color(0xFFEF4444) : AppTheme.ring; // Glowing primary/alert color

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        strong: baseStyle.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic, color: highlightColor),
        h1: baseStyle.copyWith(
          color: highlightColor,
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w900,
        ),
        h2: baseStyle.copyWith(
          color: highlightColor,
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
        h3: baseStyle.copyWith(
          color: highlightColor,
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
        code: const TextStyle(
          color: Color(0xFF34D399), // Matrix Emerald Green
          fontFamily: 'monospace',
          fontSize: 12,
          backgroundColor: Colors.transparent,
        ),
        blockquote: baseStyle.copyWith(
          color: const Color(0xFF94A3B8),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
