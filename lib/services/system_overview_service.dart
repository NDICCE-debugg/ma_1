import 'package:ma_1/services/asset_service.dart';

class SystemOverviewService {
  Future<Map<String, dynamic>> getFleetSummary() async {
    final assets = await AssetService.instance.getAllAssets();
    int totalVents = 0, workingVents = 0;
    int totalAnaes = 0, workingAnaes = 0;

    for (var asset in assets) {
      bool isWorking = asset.status == 'OPERATIONAL';
      if (asset.assetType == 'ventilator') {
        totalVents++;
        if (isWorking) workingVents++;
      } else {
        totalAnaes++;
        if (isWorking) workingAnaes++;
      }
    }

    int totalAssets = totalVents + totalAnaes;
    int totalWorking = workingVents + workingAnaes;
    double combinedCapacity = totalAssets == 0 ? 0 : (totalWorking / totalAssets) * 100;

    return {
      'total_vents': totalVents, 'working_vents': workingVents,
      'total_anaes': totalAnaes, 'working_anaes': workingAnaes,
      'combined_capacity': combinedCapacity
    };
  }

  Future<Map<String, Map<String, int>>> getByHospital() async {
    final assets = await AssetService.instance.getAllAssets();
    Map<String, Map<String, int>> data = {
      'PAEDIATRIC': {'total': 0, 'working': 0},
      'MATERNITY': {'total': 0, 'working': 0},
      'MAIN': {'total': 0, 'working': 0},
    };

    for (var a in assets) {
      if (data.containsKey(a.hospitalUnit)) {
        data[a.hospitalUnit]!['total'] = data[a.hospitalUnit]!['total']! + 1;
        if (a.status == 'OPERATIONAL') {
          data[a.hospitalUnit]!['working'] = data[a.hospitalUnit]!['working']! + 1;
        }
      }
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getByModel() async {
    final assets = await AssetService.instance.getAllAssets();
    Map<String, Map<String, int>> modelData = {};

    for (var a in assets) {
      if (!modelData.containsKey(a.modelName)) {
        modelData[a.modelName] = {'total': 0, 'working': 0, 'maintenance': 0, 'offline': 0};
      }
      modelData[a.modelName]!['total'] = modelData[a.modelName]!['total']! + 1;
      if (a.status == 'OPERATIONAL') {
        modelData[a.modelName]!['working'] = modelData[a.modelName]!['working']! + 1;
      } else if (a.status == 'MAINTENANCE') {
        modelData[a.modelName]!['maintenance'] = modelData[a.modelName]!['maintenance']! + 1;
      } else if (a.status == 'OFFLINE' || a.status == 'DECOMMISSIONED') {
        modelData[a.modelName]!['offline'] = modelData[a.modelName]!['offline']! + 1;
      }
    }

    return modelData.entries.map((e) => {'model': e.key, ...e.value}).toList();
  }
}