import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/system_overview_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final SystemOverviewService _service = SystemOverviewService();

  late Future<Map<String, dynamic>> _fleetSummaryFuture;
  late Future<Map<String, Map<String, int>>> _byHospitalFuture;
  late Future<List<Map<String, dynamic>>> _byModelFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _fleetSummaryFuture = _service.getFleetSummary();
      _byHospitalFuture = _service.getByHospital();
      _byModelFuture = _service.getByModel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        _refreshData();
        await Future.wait([
          _fleetSummaryFuture,
          _byHospitalFuture,
          _byModelFuture,
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HIGH-FIDELITY FLEET CAPACITY METERS
            FutureBuilder<Map<String, dynamic>>(
              future: _fleetSummaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.primary)));
                }
                if (!snapshot.hasData) return const SizedBox.shrink();
                
                final data = snapshot.data!;
                double cap = data['combined_capacity'];
                Color capColor = cap >= 80 ? AppTheme.success : (cap >= 60 ? AppTheme.warning : AppTheme.error);
  
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.iceBlue.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 22),
                                SizedBox(width: 10),
                                Text("System Fleet Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Outfit')),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: capColor.withValues(alpha: 0.08), 
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: capColor.withValues(alpha: 0.2), width: 1),
                              ),
                              child: Text(
                                "${cap.toInt()}% Capacity", 
                                style: TextStyle(color: capColor, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        _buildSummaryRow(Icons.air_outlined, "Operational Ventilators", data['working_vents'], data['total_vents']),
                        const Divider(height: 24, color: AppTheme.divider),
                        _buildSummaryRow(Icons.vaccines_outlined, "Anaesthetic Workstations", data['working_anaes'], data['total_anaes']),
                        
                        const SizedBox(height: 28),
                        const Text("Overall Operating Capacity", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        
                        // Professional Curved Progress Indicator
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: cap / 100,
                            minHeight: 14,
                            backgroundColor: AppTheme.divider,
                            color: capColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fade(duration: 400.ms).scaleY(begin: 0.9, end: 1, curve: Curves.easeOutBack);
              }
            ),
            
            const SizedBox(height: 28),
            const Text("Department Diagnostics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Outfit', letterSpacing: 0.5)),
            const SizedBox(height: 14),
  
            // 2. CLINICAL BREAKDOWN GRID (Ice Blue Border Accents)
            FutureBuilder<Map<String, Map<String, int>>>(
              future: _byHospitalFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                int index = 0;
                return Row(
                  children: snapshot.data!.entries.map((e) {
                    int t = e.value['total']!;
                    int w = e.value['working']!;
                    double pct = t == 0 ? 0 : w / t;
                    final itemIndex = index++;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: itemIndex == snapshot.data!.length - 1 ? 0 : 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.iceBlue.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.key, 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis, 
                                style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit')
                              ),
                              const SizedBox(height: 8),
                              Text("$w / $t Active", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct, 
                                  minHeight: 5, 
                                  backgroundColor: AppTheme.divider, 
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate(delay: (itemIndex * 100).ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
                    );
                  }).toList(),
                );
              }
            ),
            
            const SizedBox(height: 32),
            const Text("Active Equipment Manifest", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Outfit', letterSpacing: 0.5)),
            const SizedBox(height: 16),
  
            // 3. STATELY MANIFEST CHIPS
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _byModelFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.primary)));
                }
                if (!snapshot.hasData) return const SizedBox.shrink();
                if (snapshot.data!.isEmpty) return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Text("No equipment found in database.", style: TextStyle(color: AppTheme.textSecondary))));
  
                return Column(
                  children: snapshot.data!.map((modelData) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.iceBlue.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9), // Slate 100
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                              border: Border(bottom: BorderSide(color: AppTheme.divider)),
                            ),
                            child: Text(
                              modelData['model'], 
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit')
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _buildClinicalBarRow(Icons.check_circle_outline, "Operational", modelData['working'], modelData['total'], AppTheme.success),
                                const SizedBox(height: 12),
                                _buildClinicalBarRow(Icons.settings_suggest_outlined, "In Maintenance", modelData['maintenance'], modelData['total'], AppTheme.warning),
                                const SizedBox(height: 12),
                                _buildClinicalBarRow(Icons.error_outline_outlined, "Out of Service", modelData['offline'], modelData['total'], AppTheme.error),
                              ],
                            ),
                          )
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
                  }).toList(),
                );
              }
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, int working, int total) {
    double pct = total == 0 ? 0 : (working / total * 100);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.softBlue, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
            children: [
              TextSpan(text: "$working/$total ", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              TextSpan(text: "(${pct.toInt()}%)", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClinicalBarRow(IconData icon, String label, int value, int total, Color color) {
    double pct = total == 0 ? 0 : value / total;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: AppTheme.divider, color: color),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 70, 
          child: Text(
            "$value units", 
            textAlign: TextAlign.right, 
            style: GoogleFonts.outfit(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold)
          )
        ),
      ],
    );
  }
}