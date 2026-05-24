import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/services/asset_service.dart';

class UnitFleetStats {
  final String unit;
  final int total;
  final int operational;
  final int maintenance;
  final int offline;

  const UnitFleetStats({
    required this.unit,
    required this.total,
    required this.operational,
    required this.maintenance,
    required this.offline,
  });

  double get capacity => total == 0 ? 0 : operational / total;
}

class ModelFleetStats {
  final String model;
  final int total;
  final int operational;
  final int maintenance;
  final int offline;

  const ModelFleetStats({
    required this.model,
    required this.total,
    required this.operational,
    required this.maintenance,
    required this.offline,
  });

  double get capacity => total == 0 ? 0 : operational / total;
}

class SystemOverviewSnapshot {
  final List<HospitalAsset> assets;
  final List<UnitFleetStats> unitStats;
  final List<ModelFleetStats> modelStats;

  const SystemOverviewSnapshot({
    required this.assets,
    required this.unitStats,
    required this.modelStats,
  });

  int get totalAssets => assets.length;
  int get operational => assets.where((a) => a.status == 'OPERATIONAL').length;
  int get maintenance => assets.where((a) => a.status == 'MAINTENANCE').length;
  int get offline => assets
      .where((a) => a.status == 'OFFLINE' || a.status == 'DECOMMISSIONED')
      .length;
  int get ventilators =>
      assets.where((a) => a.assetType == 'ventilator').length;
  int get anaestheticMachines =>
      assets.where((a) => a.assetType != 'ventilator').length;
  double get capacity => totalAssets == 0 ? 0 : operational / totalAssets;

  List<HospitalAsset> get attentionAssets => assets
      .where((a) => a.status != 'OPERATIONAL')
      .toList()
    ..sort((a, b) => _statusRank(a.status).compareTo(_statusRank(b.status)));

  static int _statusRank(String status) {
    return switch (status) {
      'OFFLINE' => 0,
      'DECOMMISSIONED' => 1,
      'MAINTENANCE' => 2,
      _ => 3,
    };
  }
}

class SystemOverviewService {
  Future<SystemOverviewSnapshot> getSnapshot() async {
    final assets = await AssetService.instance.getAllAssets();
    return SystemOverviewSnapshot(
      assets: assets,
      unitStats: _buildUnitStats(assets),
      modelStats: _buildModelStats(assets),
    );
  }

  Future<Map<String, dynamic>> getFleetSummary() async {
    final snapshot = await getSnapshot();
    return {
      'total_vents': snapshot.ventilators,
      'working_vents': snapshot.assets
          .where(
              (a) => a.assetType == 'ventilator' && a.status == 'OPERATIONAL')
          .length,
      'total_anaes': snapshot.anaestheticMachines,
      'working_anaes': snapshot.assets
          .where(
              (a) => a.assetType != 'ventilator' && a.status == 'OPERATIONAL')
          .length,
      'combined_capacity': snapshot.capacity * 100,
    };
  }

  Future<Map<String, Map<String, int>>> getByHospital() async {
    final snapshot = await getSnapshot();
    return {
      for (final unit in snapshot.unitStats)
        unit.unit: {'total': unit.total, 'working': unit.operational},
    };
  }

  Future<List<Map<String, dynamic>>> getByModel() async {
    final snapshot = await getSnapshot();
    return snapshot.modelStats
        .map((model) => {
              'model': model.model,
              'total': model.total,
              'working': model.operational,
              'maintenance': model.maintenance,
              'offline': model.offline,
            })
        .toList();
  }

  List<UnitFleetStats> _buildUnitStats(List<HospitalAsset> assets) {
    final grouped = <String, List<HospitalAsset>>{};
    for (final asset in assets) {
      final unit = asset.hospitalUnit.trim().isEmpty
          ? 'Unassigned'
          : asset.hospitalUnit.trim();
      grouped.putIfAbsent(unit, () => []).add(asset);
    }

    final stats = grouped.entries.map((entry) {
      final items = entry.value;
      return UnitFleetStats(
        unit: entry.key,
        total: items.length,
        operational: items.where((a) => a.status == 'OPERATIONAL').length,
        maintenance: items.where((a) => a.status == 'MAINTENANCE').length,
        offline: items
            .where((a) => a.status == 'OFFLINE' || a.status == 'DECOMMISSIONED')
            .length,
      );
    }).toList();

    stats.sort((a, b) => b.total.compareTo(a.total));
    return stats;
  }

  List<ModelFleetStats> _buildModelStats(List<HospitalAsset> assets) {
    final grouped = <String, List<HospitalAsset>>{};
    for (final asset in assets) {
      grouped.putIfAbsent(asset.modelName, () => []).add(asset);
    }

    final stats = grouped.entries.map((entry) {
      final items = entry.value;
      return ModelFleetStats(
        model: entry.key,
        total: items.length,
        operational: items.where((a) => a.status == 'OPERATIONAL').length,
        maintenance: items.where((a) => a.status == 'MAINTENANCE').length,
        offline: items
            .where((a) => a.status == 'OFFLINE' || a.status == 'DECOMMISSIONED')
            .length,
      );
    }).toList();

    stats.sort((a, b) => b.total.compareTo(a.total));
    return stats;
  }
}

