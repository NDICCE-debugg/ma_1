import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/models/spare_part.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/services/gemini_service.dart';

class PredictiveMaintenanceService {
  static final PredictiveMaintenanceService instance =
      PredictiveMaintenanceService._init();
  PredictiveMaintenanceService._init();

  /// Calculates dynamic health scores, simulated telemetry, and wear metrics for an asset.
  Future<Map<String, dynamic>> getPrognostics(HospitalAsset asset) async {
    final dateAcquired =
        DateTime.tryParse(asset.dateAcquired) ?? DateTime(2024, 1, 1);
    final ageDays = DateTime.now().difference(dateAcquired).inDays;

    final lastService =
        DateTime.tryParse(asset.lastServiceDate) ?? DateTime(2024, 4, 1);
    final daysSinceService = DateTime.now().difference(lastService).inDays;

    // Ensure a highly consistent and stable telemetry hash based on device serial number
    final int hash = asset.serialNumber.hashCode.abs();
    final bool isVent = asset.assetType == 'ventilator';

    final Map<String, dynamic> telemetry = {};
    double wearPct = 0.0;
    String warningMessage = 'All sensor telemetry stable.';

    if (isVent) {
      // Simulate real ICU Ventilator telemetry
      final int turbineHours = (hash % 15000) + 3000;
      final double o2Drift = (hash % 30) / 10.0;
      final double pressureVar = (hash % 20) / 10.0;
      final int batteryCycles = (hash % 350) + 60;

      telemetry['turbineHours'] = turbineHours;
      telemetry['o2Drift'] = o2Drift;
      telemetry['pressureVar'] = pressureVar;
      telemetry['batteryCycles'] = batteryCycles;

      // Wear percentage logic
      final double turbineWear = (turbineHours / 18000) * 100;
      final double o2Wear = (o2Drift / 3.0) * 100;
      wearPct = math.max(turbineWear, o2Wear);

      if (turbineHours > 13000) {
        warningMessage =
            'High ventilator turbine usage hours detected (${turbineHours} hrs).';
      } else if (o2Drift > 2.4) {
        warningMessage =
            'Oxygen sensor calibration drift is elevated (+${o2Drift} mV).';
      }
    } else {
      // Simulate Operating Theatre Anesthetic Workstation telemetry
      final double gasDrift = (hash % 25) / 10.0;
      final double sodalimeSat = (hash % 80) + 12.0;
      final int compHours = (hash % 16000) + 2000;

      telemetry['gasDrift'] = gasDrift;
      telemetry['sodalimeSat'] = sodalimeSat;
      telemetry['compHours'] = compHours;

      final double compWear = (compHours / 20000) * 100;
      final double sodaWear = sodalimeSat;
      wearPct = math.max(compWear, sodaWear);

      if (sodalimeSat > 72.0) {
        warningMessage =
            'CO2 absorbent canister is nearing saturation (${sodalimeSat.toStringAsFixed(1)}%).';
      } else if (gasDrift > 2.0) {
        warningMessage =
            'Anesthetic vaporizer output calibration drift detected (+${gasDrift}%).';
      }
    }

    // Health Score computational formula
    double healthScore = 100.0;

    // 1. Service delay penalty
    if (daysSinceService > 180) {
      healthScore -= math.min(25.0, (daysSinceService - 180) * 0.08);
    }
    if (daysSinceService > 365) {
      healthScore -= 15.0; // Cumulative penalty
    }

    // 2. Physical telemetry wear penalty
    healthScore -= (wearPct * 0.38);

    // 3. Status overrides
    if (asset.status == 'OFFLINE') {
      healthScore = math.min(24.0, healthScore);
    } else if (asset.status == 'MAINTENANCE') {
      healthScore = math.min(62.0, healthScore);
    } else if (asset.status == 'DECOMMISSIONED') {
      healthScore = 0.0;
    }

    healthScore = healthScore.clamp(0.0, 100.0);

    // Risk classification
    String riskLevel = 'LOW';
    if (healthScore < 50.0) {
      riskLevel = 'HIGH';
    } else if (healthScore < 80.0) {
      riskLevel = 'MEDIUM';
    }

    // Days until next failure projection
    int remainingLifeDays = ((healthScore / 100.0) * 365).round();
    if (asset.status == 'OFFLINE') {
      remainingLifeDays = 0;
    } else if (asset.status == 'MAINTENANCE') {
      remainingLifeDays = math.min(10, remainingLifeDays);
    }

    return {
      'asset': asset,
      'healthScore': healthScore,
      'wearPct': wearPct,
      'riskLevel': riskLevel,
      'warningMessage': warningMessage,
      'remainingLifeDays': remainingLifeDays,
      'telemetry': telemetry,
      'daysSinceService': daysSinceService,
      'ageDays': ageDays,
    };
  }

  /// Queries SQLite spare parts database to find compatible inventory currently on hand.
  Future<List<SparePart>> getMatchingParts(String modelName) async {
    try {
      final list = await DatabaseHelper.instance.getInventory();
      final query = modelName.toLowerCase().trim();
      return list.where((p) {
        final comp = p.compatibleModel.toLowerCase();
        return comp.contains(query) || query.contains(comp);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Streams diagnostic instructions from Gemini, providing structured checklists.
  Stream<String> streamAiDiagnosticReport(
    Map<String, dynamic> prog,
    List<SparePart> compatibleParts,
  ) {
    final HospitalAsset asset = prog['asset'] as HospitalAsset;
    final double healthScore = prog['healthScore'] as double;
    final String riskLevel = prog['riskLevel'] as String;
    final String warningMessage = prog['warningMessage'] as String;
    final int remainingLifeDays = prog['remainingLifeDays'] as int;
    final Map<String, dynamic> telemetry =
        prog['telemetry'] as Map<String, dynamic>;

    final bool isVent = asset.assetType == 'ventilator';

    // Format simulated telemetry log text
    final telemetryLogs = isVent
        ? '  - Turbine Hours: ${telemetry['turbineHours']} hrs (Max Rated: 18,000 hrs)\n'
            '  - O2 Sensor Output: ${telemetry['o2Drift']} mV drift\n'
            '  - Expiratory Pressure Variance: ${telemetry['pressureVar']} cmH2O\n'
            '  - Battery Cycles: ${telemetry['batteryCycles']}/500 cycles'
        : '  - Anesthetic gas concentration output drift: +${telemetry['gasDrift']}%\n'
            '  - Sodalime canister saturation: ${telemetry['sodalimeSat']}%\n'
            '  - Compressor motor runtime: ${telemetry['compHours']} hrs (Max Rated: 20,000 hrs)';

    // Format available local stock parts
    final partsStockText = compatibleParts.isEmpty
        ? '  * No compatible spare parts currently logged in stock.'
        : compatibleParts.map((p) {
            return '  * Name: ${p.name}\n'
                '    - Available Qty: ${p.quantity} ${p.unit}\n'
                '    - Storage Bin Location: ${p.location}\n'
                '    - Reorder Alert Threshold: ${p.reorderThreshold}';
          }).join('\n');

    final String diagnosticPrompt = '''
Please execute a complete predictive maintenance and clinical risk audit for this medical asset:

[DEVICE IDENTITY]
- Model: ${asset.modelName}
- Serial Number: ${asset.serialNumber}
- Hospital Department: ${asset.hospitalUnit} (Room/Ward: ${asset.wardLocation})
- Current SQLite Status: ${asset.status}
- Last Serviced: ${asset.lastServiceDate} (Service Interval: ${asset.serviceInterval})
- Dynamic Health Score: ${healthScore.toStringAsFixed(1)}% (Risk Level: $riskLevel)

[ACTIVE SENSOR TELEMETRY]
$telemetryLogs
- Primary Assessment Signal: $warningMessage

[LOCAL SPARE PARTS INVENTORY]
$partsStockText

Please generate a professional, structured Biomedical Engineering Prognostic Report inside markdown format. Include the following precise sections:
1. **Audited Risk Analysis**: Diagnose the primary failure threat (e.g. pressure drops, sensor outages, or carbon dioxide bypass risks) based on the telemetry and age. State if failure is imminent (prognosticated remaining life: $remainingLifeDays days).
2. **Proactive Mitigation Guidelines**: Step-by-step technical directions to recalibrate or service the specific component showing wear.
3. **Spare Parts Recommendation**: Direct the technician on what spare parts are available in our local storage bins (Shelf B2, battery stores, etc.) based on our local inventory listing above. If a part is low or unavailable, explicitly advise them to log a reorder request.
4. **Safety & Verification Protocols**: List standard electrical safety and calibrating checks (e.g., pressure leak test, alarm limits audit, backup battery discharge cycle validation) that MUST be performed after the service is completed before clinical redeployment in Zimbabwean hospitals (aligned with local clinical regulatory policies).
''';

    return GeminiService.instance.streamMessage(diagnosticPrompt);
  }
}
