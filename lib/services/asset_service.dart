import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssetService {
  static final AssetService instance = AssetService._init();
  final _client = Supabase.instance.client;

  AssetService._init();

  Future<void> registerAsset(HospitalAsset asset) async {
    final Map<String, dynamic> payload = {
      'model_name': asset.modelName,
      'serial_number': asset.serialNumber,
      'location': '${asset.hospitalUnit} - ${asset.wardLocation}',
      'status': _mapStatusToSupabase(asset.status),
    };

    try {
      final response =
          await _client.from('machines').insert(payload).select().single();
      final insertedId = response['id'] as int;

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
        imageFileName: asset.imageFileName,
        imageBytes: asset.imageBytes,
      );
      await DatabaseHelper.instance.addCachedAsset(cachedAsset);
    } catch (e) {
      await DatabaseHelper.instance.addCachedAsset(asset);
      await DatabaseHelper.instance.enqueueChange(
        'INSERT',
        'machines',
        asset.serialNumber,
        payload,
      );
    }
  }

  Future<void> updateAsset(HospitalAsset asset) async {
    final Map<String, dynamic> payload = {
      'model_name': asset.modelName,
      'serial_number': asset.serialNumber,
      'location': '${asset.hospitalUnit} - ${asset.wardLocation}',
      'status': _mapStatusToSupabase(asset.status),
    };

    try {
      await _client.from('machines').update(payload).eq('id', asset.id!);
      await DatabaseHelper.instance.updateCachedAsset(asset);
    } catch (e) {
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
    final assets = await getAllAssets();
    final normalizedUnit = unit.trim().toUpperCase();
    return assets.where((asset) {
      return asset.hospitalUnit.trim().toUpperCase() == normalizedUnit;
    }).toList();
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

      final assets = (response as List)
          .map<HospitalAsset>(
              (json) => _assetFromRecord(json as Map<String, dynamic>))
          .toList();

      if (assets.isNotEmpty) {
        await DatabaseHelper.instance.cacheAssets(assets);
      }
      return assets;
    } catch (e) {
      return await DatabaseHelper.instance.getCachedAssets();
    }
  }

  HospitalAsset _assetFromRecord(Map<String, dynamic> json) {
    final modelName =
        (json['model_name'] as String?)?.trim() ?? 'Unknown Model';
    final rawAssetType = (json['asset_type'] as String?)?.trim();
    final resolvedLocation = _resolveLocation(
      location: json['location'] as String?,
      hospitalUnit: json['hospital_unit'] as String?,
      wardLocation: json['ward_location'] as String?,
    );

    return HospitalAsset(
      id: (json['id'] as num?)?.toInt(),
      assetType: _resolveAssetType(rawAssetType, modelName),
      modelName: modelName,
      serialNumber: (json['serial_number'] as String?)?.trim() ?? '',
      hospitalUnit: resolvedLocation.unit,
      wardLocation: resolvedLocation.ward,
      status: _mapStatusToClient((json['status'] as String?)?.trim() ?? ''),
      dateAcquired: (json['date_acquired'] as String?)?.trim() ?? '',
      lastServiceDate: (json['last_service_date'] as String?)?.trim() ?? '',
      serviceInterval: (json['service_interval'] as String?)?.trim() ?? '',
      notes: (json['notes'] as String?)?.trim() ?? '',
      imageFileName: (json['image_file_name'] as String?)?.trim() ?? '',
      imageBytes: json['image_bytes'],
    );
  }

  String _resolveAssetType(String? rawAssetType, String modelName) {
    if (rawAssetType != null && rawAssetType.isNotEmpty) {
      return rawAssetType;
    }

    final normalized = modelName.toLowerCase();
    if (normalized.contains('draeger') ||
        normalized.contains('drager') ||
        normalized.contains('drager') ||
        normalized.contains('mindray') ||
        normalized.contains('wato') ||
        normalized.contains('a5')) {
      return 'anaesthetic_machine';
    }

    return 'ventilator';
  }

  _ResolvedLocation _resolveLocation({
    required String? location,
    required String? hospitalUnit,
    required String? wardLocation,
  }) {
    final normalizedLocation = _normalizeLocationText(location);
    if (normalizedLocation.isNotEmpty) {
      final parts = normalizedLocation.split(' - ');
      return _ResolvedLocation(
        unit: parts.first.trim().isEmpty ? 'Unassigned' : parts.first.trim(),
        ward: parts.skip(1).join(' - ').trim(),
      );
    }

    final normalizedUnit = _normalizeLocationText(hospitalUnit);
    final normalizedWard = _normalizeLocationText(wardLocation);
    if (normalizedUnit.contains(' - ')) {
      final parts = normalizedUnit.split(' - ');
      final inheritedWard = parts.skip(1).join(' - ').trim();
      final ward = [inheritedWard, normalizedWard]
          .where((value) => value.isNotEmpty)
          .join(' - ');
      return _ResolvedLocation(
        unit: parts.first.trim().isEmpty ? 'Unassigned' : parts.first.trim(),
        ward: ward,
      );
    }

    return _ResolvedLocation(
      unit: normalizedUnit.isEmpty ? 'Unassigned' : normalizedUnit,
      ward: normalizedWard,
    );
  }

  String _normalizeLocationText(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }

    return trimmed
        .replaceAll('Ã¢â‚¬Â¢', '-')
        .replaceAll('Â-', '-')
        .replaceAll(RegExp(r'\s*-\s*'), ' - ');
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
      case 'OPERATIONAL':
      case 'MAINTENANCE':
      case 'OFFLINE':
      case 'DECOMMISSIONED':
        return status;
      default:
        return 'OPERATIONAL';
    }
  }
}

class _ResolvedLocation {
  final String unit;
  final String ward;

  const _ResolvedLocation({
    required this.unit,
    required this.ward,
  });
}
