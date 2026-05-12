import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/utils/animation_helper.dart';
import 'package:ma_1/services/system_overview_service.dart';
import 'package:ma_1/widgets/hud_segmented_bar.dart';

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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. GLOBAL FLEET SUMMARY
          FutureBuilder<Map<String, dynamic>>(
            future: _service.getFleetSummary(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              final data = snapshot.data!;
              double cap = data['combined_capacity'];
              Color capColor = cap >= 80 ? AppTheme.accent : (cap >= 60 ? AppTheme.warning : AppTheme.error);

              return HudBrackets(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("FLEET STATUS — ALL UNITS", style: TextStyle(color: AppTheme.primary, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 10),
                    
                    Text("VENTILATORS", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    Row(
                      children: [
                        Expanded(child: Text("Total Fleet: ${data['total_vents']}", style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'))),
                        Expanded(child: Text("Working: ${data['working_vents']} (${data['total_vents']==0 ? 0 : (data['working_vents']/data['total_vents']*100).toInt()}%)", style: const TextStyle(color: AppTheme.accent, fontFamily: 'Share Tech Mono'))),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    Text("ANAESTHETIC MACHINES", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    Row(
                      children: [
                        Expanded(child: Text("Total Fleet: ${data['total_anaes']}", style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'))),
                        Expanded(child: Text("Working: ${data['working_anaes']} (${data['total_anaes']==0 ? 0 : (data['working_anaes']/data['total_anaes']*100).toInt()}%)", style: const TextStyle(color: AppTheme.accent, fontFamily: 'Share Tech Mono'))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("COMBINED WORKING CAPACITY:", style: TextStyle(color: Colors.white, fontSize: 12)),
                        Text("${cap.toInt()}%", style: TextStyle(color: capColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    HudSegmentedBar(percentage: cap / 100, color: capColor, segments: 24),
                  ],
                ),
              );
            }
          ),
          const SizedBox(height: 20),

          // 2. HOSPITAL BREAKDOWN
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
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.white10), color: AppTheme.bgLight),
                      child: Column(
                        children: [
                          Text(e.key.substring(0, math.min(e.key.length, 9)), style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("Working: $w/$t", style: const TextStyle(color: Colors.white, fontSize: 9)),
                          const SizedBox(height: 5),
                          HudSegmentedBar(percentage: pct, color: AppTheme.accent, segments: 8),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            }
          ),
          const SizedBox(height: 30),

          // 3. PER-MODEL BREAKDOWN
          const Text("ASSET MANIFEST BY MODEL", style: TextStyle(color: AppTheme.textGrey, letterSpacing: 2, fontSize: 12)),
          const SizedBox(height: 15),
          
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _service.getByModel(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              if (snapshot.data!.isEmpty) return const Text("NO ASSETS REGISTERED IN DATABASE.", style: TextStyle(color: AppTheme.primary));

              return Column(
                children: snapshot.data!.map((modelData) {
                  int total = modelData['total'];
                  int work = modelData['working'];
                  int maint = modelData['maintenance'];
                  int fault = modelData['offline'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(8), color: AppTheme.bgLight,
                          child: Text(modelData['model'], style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              _buildModelBarRow("WORKING", work, total, AppTheme.accent),
                              const SizedBox(height: 8),
                              _buildModelBarRow("UNDER MAINT", maint, total, AppTheme.warning),
                              const SizedBox(height: 8),
                              _buildModelBarRow("FAULTY/OFF", fault, total, AppTheme.error),
                            ],
                          ),
                        )
                      ],
                    ),
                  ).animate().slideX();
                }).toList(),
              );
            }
          )
        ],
      ),
    );
  }

  Widget _buildModelBarRow(String label, int value, int total, Color color) {
    double pct = total == 0 ? 0 : value / total;
    return Row(
      children: [
        SizedBox(width: 80, child: Text("$label:", style: const TextStyle(color: AppTheme.textGrey, fontSize: 10))),
        SizedBox(width: 25, child: Text("[$value]", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
        const SizedBox(width: 10),
        Expanded(child: HudSegmentedBar(percentage: pct, color: color, segments: 15)),
        const SizedBox(width: 10),
        SizedBox(width: 35, child: Text("${(pct * 100).toInt()}%", textAlign: TextAlign.right, style: TextStyle(color: color, fontFamily: 'Share Tech Mono', fontSize: 12))),
      ],
    );
  }
}