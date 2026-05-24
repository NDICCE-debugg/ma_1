import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/services/system_overview_service.dart';
import 'package:ma_1/theme/app_theme.dart';

enum _AssetFilter { all, attention, operational, maintenance, offline }

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final SystemOverviewService _service = SystemOverviewService();
  late Future<SystemOverviewSnapshot> _snapshotFuture;
  _AssetFilter _filter = _AssetFilter.all;
  String _query = '';

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
    final filteredAssets = _filteredAssets(data.assets);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        _buildCommandHeader(data),
        const SizedBox(height: 16),
        _buildPriorityQueue(data),
        const SizedBox(height: 16),
        _buildDepartmentCards(data),
        const SizedBox(height: 16),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: _buildStatusPanel(data)),
              const SizedBox(width: 14),
              Expanded(flex: 5, child: _buildModelPanel(data)),
            ],
          )
        else ...[
          _buildStatusPanel(data),
          const SizedBox(height: 14),
          _buildModelPanel(data),
        ],
        const SizedBox(height: 16),
        _buildAssetPanel(filteredAssets),
      ],
    );
  }

  Widget _buildCommandHeader(SystemOverviewSnapshot data) {
    final cap = (data.capacity * 100).round();
    final statusText = cap >= 80
        ? 'Fleet ready'
        : cap >= 60
            ? 'Service pressure'
            : 'High risk';
    final statusColor = cap >= 80
        ? AppTheme.success
        : cap >= 60
            ? AppTheme.warning
            : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Clinical Equipment Command Center',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${data.totalAssets} assets tracked across ${data.unitStats.length} unit(s)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 13,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          );

          final statusBlock = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                Text(
                  '$statusText • $cap% capacity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 14), statusBlock],
            );
          }

          return Row(
            children: [
              Expanded(child: titleBlock),
              statusBlock,
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Refresh dashboard',
                onPressed: _refreshData,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh),
              ),
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.03, end: 0);
  }

  Widget _buildPriorityQueue(SystemOverviewSnapshot data) {
    final attention = data.attentionAssets.take(5).toList();
    final message = attention.isEmpty
        ? 'No machines are currently flagged for maintenance.'
        : '${attention.length} priority machine${attention.length == 1 ? '' : 's'} need technician review.';
    final color = data.offline > 0
        ? AppTheme.error
        : data.maintenance > 0
            ? AppTheme.warning
            : AppTheme.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.priority_high_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What needs attention now',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _filter = _AssetFilter.attention),
                icon: const Icon(Icons.assignment_outlined, size: 16),
                label: const Text('Review queue'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          if (attention.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...attention.map(_priorityRow),
          ],
        ],
      ),
    );
  }

  Widget _priorityRow(HospitalAsset asset) {
    final color = _statusColor(asset.status);
    final action = asset.status == 'OFFLINE'
        ? 'Restore coverage or move standby unit'
        : asset.status == 'MAINTENANCE'
            ? 'Schedule service and confirm parts'
            : 'Verify status';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_assetIcon(asset.assetType), color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.modelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${asset.hospitalUnit} • ${asset.wardLocation} • $action',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _statusBadge(asset.status),
        ],
      ),
    );
  }

  Widget _buildStatusPanel(SystemOverviewSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Fleet Health', Icons.monitor_heart_outlined),
          const SizedBox(height: 18),
          SizedBox(
            height: 176,
            child: Row(
              children: [
                Expanded(
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
                            '${(data.capacity * 100).round()}%',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const Text(
                            'ready',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendRow(
                          'Operational', data.operational, AppTheme.success),
                      _legendRow(
                          'Maintenance', data.maintenance, AppTheme.warning),
                      _legendRow('Offline', data.offline, AppTheme.error),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCards(SystemOverviewSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Departments', Icons.business_outlined),
          const SizedBox(height: 6),
          const Text(
            'Tap a department for a quick maintenance snapshot.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 620
                      ? 3
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.unitStats.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: columns == 1 ? 3.1 : 1.55,
                ),
                itemBuilder: (context, index) {
                  final unit = data.unitStats[index];
                  return _departmentCard(data, unit);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _departmentCard(SystemOverviewSnapshot data, UnitFleetStats unit) {
    final pct = unit.capacity;
    final color = pct >= 0.8
        ? AppTheme.success
        : pct >= 0.6
            ? AppTheme.warning
            : AppTheme.error;
    final status = pct >= 0.8
        ? 'Stable'
        : pct >= 0.6
            ? 'Watch'
            : 'At risk';

    return InkWell(
      onTap: () => _showDepartmentPopup(data, unit),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    unit.unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${unit.operational}/${unit.total} ready',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: pct,
                color: color,
                backgroundColor: AppTheme.divider,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _smallStatus('Svc', unit.maintenance, AppTheme.warning),
                const SizedBox(width: 8),
                _smallStatus('Off', unit.offline, AppTheme.error),
                const Spacer(),
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStatus(String label, int value, Color color) {
    return Text(
      '$label $value',
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        fontFamily: 'Outfit',
      ),
    );
  }

  void _showDepartmentPopup(
    SystemOverviewSnapshot data,
    UnitFleetStats unit,
  ) {
    final assets =
        data.assets.where((asset) => asset.hospitalUnit == unit.unit).toList();
    final attention = assets.where((a) => a.status != 'OPERATIONAL').toList()
      ..sort((a, b) =>
          _statusPriority(a.status).compareTo(_statusPriority(b.status)));
    final operational = assets.where((a) => a.status == 'OPERATIONAL').length;
    final maintenance = assets.where((a) => a.status == 'MAINTENANCE').length;
    final offline = assets
        .where((a) => a.status == 'OFFLINE' || a.status == 'DECOMMISSIONED')
        .length;
    final capacity = assets.isEmpty ? 0.0 : operational / assets.length;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_hospital_outlined,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.unit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(capacity * 100).round()}% ready • ${attention.length} priority',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _departmentBrief(
                    assets.length,
                    operational,
                    maintenance,
                    offline,
                    capacity,
                  ),
                  const SizedBox(height: 12),
                  _departmentFleetGrid(assets),
                  const SizedBox(height: 12),
                  _departmentAttentionList(attention, limit: 3),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          setState(() {
                            _filter = _AssetFilter.attention;
                            _query = unit.unit;
                          });
                        },
                        icon: const Icon(Icons.filter_alt_outlined, size: 16),
                        label: const Text('Queue'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
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
      },
    );
  }

  Widget _departmentBrief(
    int total,
    int operational,
    int maintenance,
    int offline,
    double capacity,
  ) {
    final pressure = offline > 0
        ? 'Immediate coverage risk'
        : maintenance > 0
            ? 'Preventive service queue'
            : 'Stable operating posture';
    final color = offline > 0
        ? AppTheme.error
        : maintenance > 0
            ? AppTheme.warning
            : AppTheme.success;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pressure,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('Assets', total.toString(), AppTheme.primary),
              _miniStat('Ready', operational.toString(), AppTheme.success),
              _miniStat('Service', maintenance.toString(), AppTheme.warning),
              _miniStat('Offline', offline.toString(), AppTheme.error),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${(capacity * 100).round()}% department capacity',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: capacity,
              minHeight: 8,
              color: color,
              backgroundColor: AppTheme.divider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _departmentFleetGrid(List<HospitalAsset> assets) {
    final visibleAssets = assets.take(12).toList();
    final overflow = assets.length - visibleAssets.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Machine field map',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (visibleAssets.isEmpty)
                const Text(
                  'No machines recorded.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
              ...visibleAssets.map((asset) {
                final color = _statusColor(asset.status);
                return Tooltip(
                  message:
                      '${asset.modelName}\n${asset.serialNumber}\n${_statusLabel(asset.status)}',
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _assetIcon(asset.assetType),
                      color: color,
                      size: 20,
                    ),
                  ),
                );
              }),
              if (overflow > 0)
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.iceBlue.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$overflow',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _departmentAttentionList(
    List<HospitalAsset> attention, {
    int limit = 5,
  }) {
    if (attention.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No open maintenance pressure.',
          style: TextStyle(
            color: AppTheme.success,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority machines',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        ...attention.take(limit).map(_assetRow),
      ],
    );
  }

  Widget _buildModelPanel(SystemOverviewSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Fleet by Model', Icons.stacked_bar_chart),
          const SizedBox(height: 12),
          for (final model in data.modelStats.take(8)) _modelRow(model),
        ],
      ),
    );
  }

  Widget _modelRow(ModelFleetStats model) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              model.model,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Row(
                children: [
                  _stackSegment(
                      model.operational, model.total, AppTheme.success),
                  _stackSegment(
                      model.maintenance, model.total, AppTheme.warning),
                  _stackSegment(model.offline, model.total, AppTheme.error),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text(
              '${model.total} units',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stackSegment(int value, int total, Color color) {
    final flex = total == 0 ? 1 : math.max(value, 0);
    return Expanded(
      flex: flex == 0 ? 1 : flex,
      child: Container(
        height: 9,
        color: value == 0 ? AppTheme.divider : color,
      ),
    );
  }

  Widget _buildAssetPanel(List<HospitalAsset> assets) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Full Work Queue', Icons.assignment_outlined),
          const SizedBox(height: 12),
          _buildFilters(),
          const SizedBox(height: 12),
          if (assets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No assets match the current filters.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontFamily: 'Outfit',
                ),
              ),
            )
          else
            ...assets.take(12).map(_assetRow),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final filter in _AssetFilter.values)
          ChoiceChip(
            selected: _filter == filter,
            label: Text(_filterLabel(filter)),
            onSelected: (_) => setState(() => _filter = filter),
            selectedColor: AppTheme.primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppTheme.divider),
            labelStyle: TextStyle(
              color: _filter == filter ? Colors.white : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        SizedBox(
          width: 220,
          height: 38,
          child: TextField(
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search serial/model',
              prefixIcon: const Icon(Icons.search, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _assetRow(HospitalAsset asset) {
    final color = _statusColor(asset.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_assetIcon(asset.assetType), color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.modelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${asset.serialNumber} • ${asset.hospitalUnit} ${asset.wardLocation}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(asset.status),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  List<HospitalAsset> _filteredAssets(List<HospitalAsset> assets) {
    final query = _query.toLowerCase();
    return assets.where((asset) {
      final statusMatch = switch (_filter) {
        _AssetFilter.all => true,
        _AssetFilter.attention => asset.status != 'OPERATIONAL',
        _AssetFilter.operational => asset.status == 'OPERATIONAL',
        _AssetFilter.maintenance => asset.status == 'MAINTENANCE',
        _AssetFilter.offline =>
          asset.status == 'OFFLINE' || asset.status == 'DECOMMISSIONED',
      };
      final queryMatch = query.isEmpty ||
          asset.modelName.toLowerCase().contains(query) ||
          asset.serialNumber.toLowerCase().contains(query) ||
          asset.hospitalUnit.toLowerCase().contains(query);
      return statusMatch && queryMatch;
    }).toList();
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

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.primary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.divider),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 6),
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

  String _filterLabel(_AssetFilter filter) {
    return switch (filter) {
      _AssetFilter.all => 'All',
      _AssetFilter.attention => 'Attention',
      _AssetFilter.operational => 'Operational',
      _AssetFilter.maintenance => 'Maintenance',
      _AssetFilter.offline => 'Offline',
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'OPERATIONAL' => AppTheme.success,
      'MAINTENANCE' => AppTheme.warning,
      'OFFLINE' || 'DECOMMISSIONED' => AppTheme.error,
      _ => AppTheme.textSecondary,
    };
  }

  int _statusPriority(String status) {
    return switch (status) {
      'OFFLINE' => 0,
      'DECOMMISSIONED' => 1,
      'MAINTENANCE' => 2,
      _ => 3,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'OPERATIONAL' => 'Operational',
      'MAINTENANCE' => 'Maintenance',
      'OFFLINE' => 'Offline',
      'DECOMMISSIONED' => 'Decommissioned',
      _ => status,
    };
  }

  IconData _assetIcon(String type) {
    return type == 'ventilator' ? Icons.air_outlined : Icons.vaccines_outlined;
  }
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
