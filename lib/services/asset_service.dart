import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_1/models/hospital_asset.dart';

class AssetService {
  static final AssetService instance = AssetService._init();
  final _client = Supabase.instance.client;

  AssetService._init();

  Future<void> registerAsset(HospitalAsset asset) async {
    // Map HospitalAsset model to 'machines' table in Supabase schema
    await _client.from('machines').insert({
      'model_name': asset.modelName,
      'serial_number': asset.serialNumber,
      'location': '${asset.hospitalUnit} • ${asset.wardLocation}',
      'status': _mapStatusToSupabase(asset.status),
    });
  }

  Future<void> updateAsset(HospitalAsset asset) async {
    await _client.from('machines').update({
      'model_name': asset.modelName,
      'serial_number': asset.serialNumber,
      'location': '${asset.hospitalUnit} • ${asset.wardLocation}',
      'status': _mapStatusToSupabase(asset.status),
    }).eq('id', asset.id);
  }

  Future<List<HospitalAsset>> getAssetsByUnit(String unit) async {
    try {
      final response = await _client
          .from('machines')
          .select()
          .like('location', '$unit%');
      
      return response.map<HospitalAsset>((json) {
        final locParts = (json['location'] as String).split(' • ');
        final hospUnit = locParts.isNotEmpty ? locParts[0] : unit;
        final wardLoc = locParts.length > 1 ? locParts[1] : '';
        
        return HospitalAsset(
          id: json['id'],
          assetType: (json['model_name'] as String).toLowerCase().contains('dräger') || 
                     (json['model_name'] as String).toLowerCase().contains('mindray') 
                     ? 'anaesthetic_machine' : 'ventilator',
          modelName: json['model_name'],
          serialNumber: json['serial_number'],
          hospitalUnit: hospUnit,
          wardLocation: wardLoc,
          status: _mapStatusToClient(json['status']),
          dateAcquired: '2024-01-01',
          lastServiceDate: '2024-01-01',
          serviceInterval: '6 Months',
          notes: '',
        );
      }).toList();
    } catch (e) {
      // Fallback empty list on error (e.g. database not seeded or offline)
      return [];
    }
  }

  Future<List<HospitalAsset>> getAllAssets() async {
    try {
      final response = await _client.from('machines').select();
      
      return response.map<HospitalAsset>((json) {
        final locParts = (json['location'] as String).split(' • ');
        final hospUnit = locParts.isNotEmpty ? locParts[0] : 'MAIN';
        final wardLoc = locParts.length > 1 ? locParts[1] : '';
        
        return HospitalAsset(
          id: json['id'],
          assetType: (json['model_name'] as String).toLowerCase().contains('dräger') || 
                     (json['model_name'] as String).toLowerCase().contains('mindray') 
                     ? 'anaesthetic_machine' : 'ventilator',
          modelName: json['model_name'],
          serialNumber: json['serial_number'],
          hospitalUnit: hospUnit,
          wardLocation: wardLoc,
          status: _mapStatusToClient(json['status']),
          dateAcquired: '2024-01-01',
          lastServiceDate: '2024-01-01',
          serviceInterval: '6 Months',
          notes: '',
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  String _mapStatusToSupabase(String status) {
    switch (status) {
      case 'OPERATIONAL':
        return 'Operational';
      case 'MAINTENANCE':
        return 'Needs Maintenance';
      case 'OFFLINE':
        return 'Out of Order';
      case 'DECOMMISSIONED':
        return 'Decommissioned';
      default:
        return 'Operational';
    }
  }

  String _mapStatusToClient(String status) {
    switch (status) {
      case 'Operational':
        return 'OPERATIONAL';
      case 'Needs Maintenance':
        return 'MAINTENANCE';
      case 'Out of Order':
        return 'OFFLINE';
      case 'Decommissioned':
        return 'DECOMMISSIONED';
      default:
        return 'OPERATIONAL';
    }
  }
}