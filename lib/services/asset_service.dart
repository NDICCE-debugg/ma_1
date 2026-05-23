import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/services/database_helper.dart';

class AssetService {
  static final AssetService instance = AssetService._init();
  final _client = Supabase.instance.client;

  AssetService._init();

  Future<void> registerAsset(HospitalAsset asset) async {
    final Map<String, dynamic> payload = {
      'model_name': asset.modelName,
      'serial_number': asset.serialNumber,
      'location': '${asset.hospitalUnit} • ${asset.wardLocation}',
      'status': _mapStatusToSupabase(asset.status),
    };

    try {
      final response = await _client.from('machines').insert(payload).select().single();
      final insertedId = response['id'] as int;
      
      // Update local SQLite cache with remote ID
      final cachedAsset = HospitalAsset(
        id: insertedId,
        assetType: asset.assetType,
        modelName: asset.modelName,
        serialNumber: asset.serialNumber,
        hospitalUnit: asset.hospitalUnit,
        wardLocation: asset.wardLocation,
        status: asset.status,
        dateAcquired: asset.dateAcquired,
        lastServiceDate: asset.lastServiceDate,
        serviceInterval: asset.serviceInterval,
        notes: asset.notes,
      );
      await DatabaseHelper.instance.addCachedAsset(cachedAsset);
    } catch (e) {
      // Offline fallback: Write to SQLite with mock negative ID or sync ID, then enqueue
      await DatabaseHelper.instance.addCachedAsset(asset);
      await DatabaseHelper.instance.enqueueChange(
        'INSERT',
        'machines',
        asset.serialNumber, // Use serial_number as identifier for insert matching
        payload,
      );
    }
  }

  Future<void> updateAsset(HospitalAsset asset) async {
    final Map<String, dynamic> payload = {
      'model_name': asset.modelName,
      'serial_number': asset.serialNumber,
      'location': '${asset.hospitalUnit} • ${asset.wardLocation}',
      'status': _mapStatusToSupabase(asset.status),
    };

    try {
      await _client.from('machines').update(payload).eq('id', asset.id!);
      await DatabaseHelper.instance.updateCachedAsset(asset);
    } catch (e) {
      // Offline fallback: Write to SQLite cache, then enqueue transaction
      await DatabaseHelper.instance.updateCachedAsset(asset);
      await DatabaseHelper.instance.enqueueChange(
        'UPDATE',
        'machines',
        asset.id.toString(),
        payload,
      );
    }
  }

  Future<List<HospitalAsset>> getAssetsByUnit(String unit) async {
    try {
      final response = await _client
          .from('machines')
          .select()
          .like('location', '$unit%');
      
      if (response.isEmpty) {
        final cached = await DatabaseHelper.instance.getCachedAssets();
        final filtered = cached.where((asset) => asset.hospitalUnit.toUpperCase() == unit.toUpperCase()).toList();
        if (filtered.isNotEmpty) {
          return filtered;
        }
      }

      final assets = response.map<HospitalAsset>((json) {
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

      // Bulk update local SQLite cache on successful fetch using upsert so we don't delete other units!
      if (assets.isNotEmpty) {
        await DatabaseHelper.instance.upsertCachedAssets(assets);
      }
      return assets;
    } catch (e) {
      // Offline fallback: Query SQLite cache and filter by hospital unit
      final cached = await DatabaseHelper.instance.getCachedAssets();
      return cached.where((asset) => asset.hospitalUnit.toUpperCase() == unit.toUpperCase()).toList();
    }
  }

  Future<List<HospitalAsset>> getAllAssets() async {
    try {
      final response = await _client.from('machines').select();
      
      if (response.isEmpty) {
        final cached = await DatabaseHelper.instance.getCachedAssets();
        if (cached.isNotEmpty) {
          return cached;
        }
      }

      final assets = response.map<HospitalAsset>((json) {
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

      // Cache all fetched assets locally if we got non-empty data
      if (assets.isNotEmpty) {
        await DatabaseHelper.instance.cacheAssets(assets);
      }
      return assets;
    } catch (e) {
      // Offline fallback
      return await DatabaseHelper.instance.getCachedAssets();
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