import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. OPERATING CAPACITY CARD
          FutureBuilder<Map<String, dynamic>>(
            future: _service.getFleetSummary(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              
              final data = snapshot.data!;
              double cap = data['combined_capacity'];
              Color capColor = cap >= 80 ? AppTheme.success : (cap >= 60 ? AppTheme.warning : AppTheme.error);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Fleet Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: capColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                            child: Text("${cap.toInt()}% Capacity", style: TextStyle(color: capColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      _buildSummaryRow("Ventilators", data['working_vents'], data['total_vents']),
                      const SizedBox(height: 12),
                      _buildSummaryRow("Anaesthetic Machines", data['working_anaes'], data['total_anaes']),
                      
                      const SizedBox(height: 24),
                      const Text("Operating Capacity", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      
                      // Clean Medical Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: cap / 100,
                          minHeight: 12,
                          backgroundColor: AppTheme.background,
                          color: capColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          ),
          
          const SizedBox(height: 24),
          const Text("Department Breakdown", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),

          // 2. DEPARTMENT BREAKDOWN GRID
          FutureBuilder<Map<String, Map<String, int>>>(
            future: _service.getByHospital(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return Row(
                children: snapshot.data!.entries.map((e) {
                  int t = e.value['total']!;
                  int w = e.value['working']!;
                  double pct = t == 0 ? 0 : w / t;
                  return Expanded(
                    child: Card(
                      margin: const EdgeInsets.only(right: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text("$w / $t Active", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: AppTheme.background, color: AppTheme.primary),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }
          ),
          
          const SizedBox(height: 32),
          const Text("Equipment by Model", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),

          // 3. EQUIPMENT MANIFEST BY MODEL
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _service.getByModel(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty) return const Center(child: Text("No equipment found in database.", style: TextStyle(color: AppTheme.textSecondary)));

              return Column(
                children: snapshot.data!.map((modelData) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                            border: Border(bottom: BorderSide(color: AppTheme.border)),
                          ),
                          child: Text(modelData['model'], style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildClinicalBarRow("Operational", modelData['working'], modelData['total'], AppTheme.success),
                              const SizedBox(height: 12),
                              _buildClinicalBarRow("In Maintenance", modelData['maintenance'], modelData['total'], AppTheme.warning),
                              const SizedBox(height: 12),
                              _buildClinicalBarRow("Out of Service", modelData['offline'], modelData['total'], AppTheme.error),
                            ],
                          ),
                        )
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1, end: 0);
                }).toList(),
              );
            }
          )
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, int working, int total) {
    double pct = total == 0 ? 0 : (working / total * 100);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        RichText(
          text: TextSpan(
            style: GoogleFonts.robotoMono(fontSize: 14, color: AppTheme.textPrimary),
            children: [
              TextSpan(text: "$working/$total ", style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: "(${pct.toInt()}%)", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClinicalBarRow(String label, int value, int total, Color color) {
    double pct = total == 0 ? 0 : value / total;
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: AppTheme.background, color: color),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60, 
          child: Text(
            "$value units", 
            textAlign: TextAlign.right, 
            style: GoogleFonts.robotoMono(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)
          )
        ),
      ],
    );
  }
}