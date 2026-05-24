import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/screens/ai_diagnostics_sheet.dart';
import 'package:ma_1/screens/asset_detail_view.dart';
import 'package:ma_1/services/predictive_maintenance_service.dart';
import 'package:ma_1/services/system_overview_service.dart';
import 'package:ma_1/theme/app_theme.dart';



class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final SystemOverviewService _service = SystemOverviewService();
  late Future<SystemOverviewSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _snapshotFuture = _service.getSnapshot();
    });
  }

  void _navigateToAsset(SystemOverviewSnapshot data, String modelName) {
    try {
      final asset = data.assets.firstWhere(
        (a) => a.modelName.toLowerCase().contains(modelName.toLowerCase()),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssetDetailView(assetData: {
            'id': asset.id,
            'asset_type': asset.assetType,
            'model_name': asset.modelName,
            'serial_number': asset.serialNumber,
            'hospital_unit': asset.hospitalUnit,
            'ward_location': asset.wardLocation,
            'status': asset.status,
            'date_acquired': asset.dateAcquired,
            'last_service_date': asset.lastServiceDate,
            'service_interval': asset.serviceInterval,
            'notes': asset.notes,
            'image_file_name': asset.imageFileName,
            'image_bytes': asset.imageBytes,
          }),
        ),
      );
    } catch (_) {
      // Fallback if not found
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        _refreshData();
        await _snapshotFuture;
      },
      child: FutureBuilder<SystemOverviewSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          if (snapshot.hasError) {
            return _buildStateMessage(
              Icons.cloud_off_outlined,
              'Dashboard data unavailable',
              snapshot.error.toString(),
            );
          }

          final data = snapshot.data;
          if (data == null || data.totalAssets == 0) {
            return _buildStateMessage(
              Icons.inventory_2_outlined,
              'No equipment records found',
              'Add assets or sync with Supabase to populate the dashboard.',
            );
          }

          return _buildDashboard(data);
        },
      ),
    );
  }

  Widget _buildDashboard(SystemOverviewSnapshot data) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        // --- 1. Greet Header block ---
        _buildGreetingHeader(),
        const SizedBox(height: 16),

        // --- 2. 2x2 Grid or 4-Column Row of Fleet Metrics ---
        _buildMetricsGrid(data),
        const SizedBox(height: 16),

        // --- 3. Pulse AI Prognostics Centerpiece (Urgent Alerts centerpiece) ---
        _buildAiPrognosticsCore(data),
        const SizedBox(height: 16),

        // --- 4. Interactive Charts & Activity logs grid column layout ---
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildServiceActivityCard(),
                    const SizedBox(height: 16),
                    _buildUpcomingMaintenanceCard(data),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildEquipmentHealthCard(data),
                    const SizedBox(height: 16),
                    _buildRecentActivityCard(data),
                  ],
                ),
              ),
            ],
          )
        else ...[
          _buildServiceActivityCard(),
          const SizedBox(height: 16),
          _buildEquipmentHealthCard(data),
          const SizedBox(height: 16),
          _buildUpcomingMaintenanceCard(data),
          const SizedBox(height: 16),
          _buildRecentActivityCard(data),
        ],
      ],
    );
  }

  Widget _buildGreetingHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF0A1518) : Colors.white;
    final chipBorder = isDark ? const Color(0xFF24353A) : const Color(0xFFE2E8F0);
    final textPrimaryColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary;

    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good morning, Michael';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon, Michael';
    } else {
      greeting = 'Good evening, Michael';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Outfit',
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Here's what's happening with your equipment today.",
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
        // Weather chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: chipBorder),
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? Colors.black.withValues(alpha: 0.15) 
                    : Colors.black.withValues(alpha: 0.015),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                hour >= 6 && hour < 18 ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                color: hour >= 6 && hour < 18 ? Colors.amber : Colors.indigoAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hour >= 6 && hour < 18 ? '22°C' : '16°C',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  Text(
                    hour >= 6 && hour < 18 ? 'Partly Cloudy' : 'Clear Sky',
                    style: TextStyle(
                      color: textSecondaryColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.02, end: 0);
  }

  Widget _buildMetricsGrid(SystemOverviewSnapshot data) {
    final cap = (data.capacity * 100).toStringAsFixed(1);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        
        final children = [
          _metricGridCard(
            'Total Devices',
            data.totalAssets.toString(),
            '12 this month',
            Icons.desktop_windows_outlined,
            const Color(0xFF3B82F6),
          ),
          _metricGridCard(
            'Active Alerts',
            data.offline.toString(),
            '2 critical',
            Icons.warning_amber_rounded,
            const Color(0xFFEF4444),
          ),
          _metricGridCard(
            'Maintenance Due',
            data.maintenance.toString(),
            '5 this week',
            Icons.calendar_today_rounded,
            const Color(0xFFF59E0B),
          ),
          _metricGridCard(
            'System Uptime',
            '$cap%',
            'Excellent',
            Icons.verified_user_outlined,
            const Color(0xFF10B981),
          ),
        ];

        if (wide) {
          return Row(
            children: children.map((card) => Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: card,
            ))).toList(),
          );
        } else {
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.45,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: children,
          );
        }
      },
    );
  }

  Widget _metricGridCard(
    String title,
    String value,
    String trend,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0A1518) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF24353A) : const Color(0xFFE2E8F0);
    final textPrimaryColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textSecondaryColor = isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary;

    IconData getTrendIcon() {
      if (color == const Color(0xFF3B82F6)) return Icons.trending_up_rounded;
      if (color == const Color(0xFFEF4444)) return Icons.error_outline_rounded;
      if (color == const Color(0xFFF59E0B)) return Icons.schedule_rounded;
      return Icons.verified_user_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Outfit',
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getTrendIcon(),
                  color: color,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Text(
                  trend,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceActivityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Activity',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  Text(
                    '32 Services Completed',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              // Dropdown button mock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Text(
                      'This Week',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // spline curve chart
          const SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _SplineChartPainter(
                values: [3.0, 7.0, 4.0, 8.0, 6.0, 9.0, 5.0, 11.0],
                days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Day labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mon', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              Text('Tue', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              Text('Wed', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              Text('Thu', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              Text('Fri', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              Text('Sat', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              Text('Sun', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentHealthCard(SystemOverviewSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Equipment Health',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Left donut chart
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _DonutPainter(
                    operational: data.operational,
                    maintenance: data.maintenance,
                    offline: data.offline,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.totalAssets.toString(),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Outfit',
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'Total',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Right legend breakdown table
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendRow('Good', data.operational, AppTheme.success),
                    _legendRow('Fair', data.maintenance, AppTheme.warning),
                    _legendRow('Offline', data.offline, AppTheme.error),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMaintenanceCard(SystemOverviewSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Maintenance',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Outfit',
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppTheme.classicBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _upcomingMaintenanceRow(data, 'MAY 22', 'MRI Scanner 1.5T', 'Radiology Dept', 'Today • High', Colors.red),
          _upcomingMaintenanceRow(data, 'MAY 23', 'Ultrasound Machine', 'Outpatient Clinic 2', 'Tomorrow • Med', Colors.orange),
          _upcomingMaintenanceRow(data, 'MAY 25', 'Patient Monitor PM-9000', 'ICU - Room 8', 'In 3 days • Low', Colors.blue),
        ],
      ),
    );
  }

  Widget _upcomingMaintenanceRow(
    SystemOverviewSnapshot data,
    String dateStr,
    String name,
    String dept,
    String timeTag,
    Color tagColor,
  ) {
    final splitDate = dateStr.split(' ');
    final month = splitDate[0];
    final day = splitDate[1];

    return InkWell(
      onTap: () => _navigateToAsset(data, name),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            // Calendar styled Block
            Container(
              width: 44,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    month,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  Text(
                    day,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Device details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dept,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                timeTag,
                style: TextStyle(
                  color: tagColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(SystemOverviewSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Outfit',
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppTheme.classicBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _recentActivityRow(data, 'Aeonmed VG70', 'Fixed: Aeonmed VG70', 'ICU - Room 5  |  30 min ago', Icons.check_circle_outline_rounded, Colors.green),
          _recentActivityRow(data, 'WATO EX35', 'Maintenance: Anesthetic Unit', 'Radiology Dept  |  2 hrs ago', Icons.build_outlined, Colors.blue),
          _recentActivityRow(data, 'Drager Evita', 'Alert Acknowledged', 'Ventilator V60  |  3 hrs ago', Icons.notification_important_outlined, Colors.orange),
          _recentActivityRow(data, 'Mindray A5', 'Calibration Completed', 'Patient Monitor PM-9000  |  5 hrs ago', Icons.verified_user_outlined, Colors.green),
        ],
      ),
    );
  }

  Widget _recentActivityRow(SystemOverviewSnapshot data, String queryName, String title, String subtitle, IconData icon, Color color) {
    return InkWell(
      onTap: () => _navigateToAsset(data, queryName),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity icon circle
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.08),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }



  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.02),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _buildStateMessage(IconData icon, String title, String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(icon, color: AppTheme.primary, size: 42),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildAiPrognosticsCore(SystemOverviewSnapshot data) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait(data.assets.map((a) => PredictiveMaintenanceService.instance.getPrognostics(a))),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final progs = snapshot.data!;
        
        // Sort by health score ascending (highest risk first)
        progs.sort((a, b) => (a['healthScore'] as double).compareTo(b['healthScore'] as double));

        final highRiskCount = progs.where((p) => p['riskLevel'] == 'HIGH').length;
        final criticalAssetMap = progs.first; // The absolute most critical asset
        final HospitalAsset criticalAsset = criticalAssetMap['asset'] as HospitalAsset;
        final double criticalHealth = criticalAssetMap['healthScore'] as double;
        final String criticalWarning = criticalAssetMap['warningMessage'] as String;
        final Map<String, dynamic> telemetry = criticalAssetMap['telemetry'] as Map<String, dynamic>;

        Color indexColor = AppTheme.success;
        String indexLabel = 'Fleet Stable';
        IconData indexIcon = Icons.check_circle_outline_rounded;
        
        if (highRiskCount > 0) {
          indexColor = AppTheme.error;
          indexLabel = '$highRiskCount Fleet Threats Detected';
          indexIcon = Icons.report_problem_rounded;
        } else if (progs.any((p) => p['riskLevel'] == 'MEDIUM')) {
          indexColor = AppTheme.warning;
          indexLabel = 'Medium Wear Warnings';
          indexIcon = Icons.warning_amber_rounded;
        }

        final isWide = MediaQuery.of(context).size.width >= 800;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.divider, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.03),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and AI badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.ring.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.ring, size: 19)
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(delay: 2000.ms, duration: 1500.ms, color: Colors.white54),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pulse AI Predictive Analysis Core',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                            color: AppTheme.primaryDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Prognostic health projections & imminence indexes',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Glowing risk level badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: indexColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: indexColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(indexIcon, size: 13, color: indexColor),
                        const SizedBox(width: 5),
                        Text(
                          indexLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: indexColor,
                            fontFamily: 'Outfit',
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30, color: AppTheme.divider),

              // Highest risk machine layout panel
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildCriticalGauge(criticalHealth),
                        const SizedBox(width: 20),
                        Expanded(child: _buildCriticalAssetBrief(criticalAsset, criticalWarning, criticalHealth, telemetry)),
                        const SizedBox(width: 20),
                        _buildCriticalAssetAction(context, criticalAsset, criticalAssetMap),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildCriticalGauge(criticalHealth),
                            const SizedBox(width: 16),
                            Expanded(child: _buildCriticalAssetBrief(criticalAsset, criticalWarning, criticalHealth, telemetry)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: _buildCriticalAssetAction(context, criticalAsset, criticalAssetMap),
                        ),
                      ],
                    ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }

  Widget _buildCriticalGauge(double score) {
    final Color color = score < 50.0 ? AppTheme.error : AppTheme.warning;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CircularProgressIndicator(
            value: score / 100.0,
            strokeWidth: 7,
            color: color,
            backgroundColor: AppTheme.divider,
            strokeCap: StrokeCap.round,
          ),
        ),
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.08),
          ),
          child: Text(
            '${score.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCriticalAssetBrief(
    HospitalAsset asset,
    String warning,
    double health,
    Map<String, dynamic> telemetry,
  ) {
    final Color healthColor = health < 50.0 ? AppTheme.error : AppTheme.warning;
    final isVent = asset.assetType == 'ventilator';
    
    String telemetrySnippet = '';
    if (isVent) {
      final hours = telemetry['turbineHours'] ?? 0;
      final drift = telemetry['o2Drift'] ?? 0.0;
      telemetrySnippet = 'Turbine: $hours hrs  •  O2 Drift: +${drift.toStringAsFixed(1)}mV';
    } else {
      final soda = telemetry['sodalimeSat'] ?? 0.0;
      final drift = telemetry['gasDrift'] ?? 0.0;
      telemetrySnippet = 'Sodalime Sat: ${soda.toStringAsFixed(0)}%  •  Vaporizer Drift: +${drift.toStringAsFixed(1)}%';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: healthColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'CRITICAL FLEET ANOMALY',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
              color: healthColor,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${asset.modelName} (${asset.serialNumber})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          warning,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'Outfit',
            color: healthColor,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                telemetrySnippet,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCriticalAssetAction(
    BuildContext context,
    HospitalAsset asset,
    Map<String, dynamic> assetMap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final parts = await PredictiveMaintenanceService.instance.getMatchingParts(asset.modelName);
        if (!context.mounted) return;
        
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AiDiagnosticsSheet(
            prog: assetMap,
            compatibleParts: parts,
            onStateChanged: () {
              _refreshData();
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Audit AI Risk',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'Outfit',
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }


}

class _SplineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> days;

  const _SplineChartPainter({required this.values, required this.days});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paintLine = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final paintPoint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.fill;

    final paintInnerPoint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final widthStep = size.width / (values.length - 1);
    
    final maxVal = values.reduce(math.max);
    const minVal = 0.0;
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    double getX(int index) => index * widthStep;
    double getY(double val) {
      final ratio = (val - minVal) / range;
      return size.height - (ratio * (size.height - 20)) - 10;
    }

    path.moveTo(getX(0), getY(values[0]));

    for (int i = 0; i < values.length - 1; i++) {
      final x1 = getX(i);
      final y1 = getY(values[i]);
      final x2 = getX(i + 1);
      final y2 = getY(values[i + 1]);

      final cx1 = x1 + (x2 - x1) / 2.0;
      final cy1 = y1;
      final cx2 = x1 + (x2 - x1) / 2.0;
      final cy2 = y2;

      path.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(getX(values.length - 1), size.height);
    fillPath.lineTo(getX(0), size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF3B82F6).withValues(alpha: 0.22),
          const Color(0xFF3B82F6).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paintLine);

    final paintGrid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = 10 + i * (size.height - 20) / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    for (int i = 0; i < values.length; i++) {
      final x = getX(i);
      final y = getY(values[i]);
      canvas.drawCircle(Offset(x, y), 5, paintPoint);
      canvas.drawCircle(Offset(x, y), 2.5, paintInnerPoint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplineChartPainter oldDelegate) => false;
}

class _DonutPainter extends CustomPainter {
  final int operational;
  final int maintenance;
  final int offline;

  const _DonutPainter({
    required this.operational,
    required this.maintenance,
    required this.offline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = operational + maintenance + offline;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const stroke = 18.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.divider;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, basePaint);

    if (total == 0) return;

    var start = -math.pi / 2;
    for (final segment in [
      (operational, AppTheme.success),
      (maintenance, AppTheme.warning),
      (offline, AppTheme.error),
    ]) {
      if (segment.$1 == 0) continue;
      final sweep = (segment.$1 / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = segment.$2;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return operational != oldDelegate.operational ||
        maintenance != oldDelegate.maintenance ||
        offline != oldDelegate.offline;
  }
}
