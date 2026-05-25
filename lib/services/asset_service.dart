import 'package:ma_1/models/hospital_asset.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssetService {
  static final AssetService instance = AssetService._init();
  static const String _imageBucket = 'inventory-images';
  final _client = Supabase.instance.client;

  AssetService._init();

  Future<HospitalAsset> registerAsset(HospitalAsset asset) async {
    final imageReference = await _prepareAssetImageReference(asset);
    final assetToSave = asset.copyWith(imageFileName: imageReference);
    final payload = _toSupabasePayload(assetToSave);

    try {
      final response =
          await _client.from('machines').insert(payload).select().single();
      final cachedAsset = assetToSave.copyWith(
        id: (response['id'] as num?)?.toInt(),
      );
      await DatabaseHelper.instance.addCachedAsset(cachedAsset);
      return cachedAsset;
    } catch (_) {
      await DatabaseHelper.instance.addCachedAsset(assetToSave);
      await DatabaseHelper.instance.enqueueChange(
        'INSERT',
        'machines',
        assetToSave.serialNumber,
        payload,
      );
      return assetToSave;
    }
  }

  Future<HospitalAsset> updateAsset(HospitalAsset asset) async {
    final imageReference = await _prepareAssetImageReference(asset);
    final assetToSave = asset.copyWith(imageFileName: imageReference);
    final payload = _toSupabasePayload(assetToSave);

    try {
      if (assetToSave.id != null) {
        await _client.from('machines').update(payload).eq('id', assetToSave.id!);
      } else {
        await _client
            .from('machines')
            .update(payload)
            .eq('serial_number', assetToSave.serialNumber);
      }
      await DatabaseHelper.instance.updateCachedAsset(assetToSave);
      return assetToSave;
    } catch (_) {
      await DatabaseHelper.instance.updateCachedAsset(assetToSave);
      await DatabaseHelper.instance.enqueueChange(
        'UPDATE',
        'machines',
        (assetToSave.id ?? assetToSave.serialNumber).toString(),
        payload,
      );
      return assetToSave;
    }
  }

  Future<void> retireAsset(HospitalAsset asset) async {
    await updateAsset(asset.copyWith(status: 'DECOMMISSIONED'));
  }

  Future<void> deleteAsset(HospitalAsset asset) async {
    try {
      if (asset.id != null) {
        await _client.from('machines').delete().eq('id', asset.id!);
      } else {
        await _client
            .from('machines')
            .delete()
            .eq('serial_number', asset.serialNumber);
      }
      await _deleteStoredImage(asset.imageFileName);
      await DatabaseHelper.instance.deleteCachedAsset(asset);
    } catch (_) {
      await DatabaseHelper.instance.deleteCachedAsset(asset);
      await DatabaseHelper.instance.enqueueChange(
        'DELETE',
        'machines',
        (asset.id ?? asset.serialNumber).toString(),
        _toSupabasePayload(asset),
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
        if (cached.isNotEmpty) return cached;
      }

      final assets = (response as List)
          .map<HospitalAsset>(
              (json) => _assetFromRecord(json as Map<String, dynamic>))
          .toList();
      final displayAssets = await _attachSignedImageUrls(assets);

      if (displayAssets.isNotEmpty) {
        await DatabaseHelper.instance.cacheAssets(displayAssets);
      }
      return displayAssets;
    } catch (_) {
      return DatabaseHelper.instance.getCachedAssets();
    }
  }

  Map<String, dynamic> _toSupabasePayload(HospitalAsset asset) {
    return {
      'asset_type': asset.assetType,
      'model_name': asset.modelName,
      'serial_number': asset.serialNumber,
      'location': '${asset.hospitalUnit} - ${asset.wardLocation}',
      'hospital_unit': asset.hospitalUnit,
      'ward_location': asset.wardLocation,
      'status': _mapStatusToSupabase(asset.status),
      'date_acquired': asset.dateAcquired,
      'last_service_date': asset.lastServiceDate,
      'service_interval': asset.serviceInterval,
      'notes': asset.notes,
      'image_file_name': asset.imageFileName,
    };
  }

  Future<List<HospitalAsset>> _attachSignedImageUrls(
      List<HospitalAsset> assets) async {
    return Future.wait(assets.map((asset) async {
      final ref = asset.imageFileName.trim();
      if (ref.isEmpty || ref.startsWith('http')) {
        return ref.startsWith('http') ? asset.copyWith(imageUrl: ref) : asset;
      }
      try {
        final signedUrl =
            await _client.storage.from(_imageBucket).createSignedUrl(ref, 3600);
        return asset.copyWith(imageUrl: signedUrl);
      } catch (_) {
        return asset;
      }
    }));
  }

  Future<String> _prepareAssetImageReference(HospitalAsset asset) async {
    final currentReference = asset.imageFileName.trim();
    final hasNewLocalImage =
        asset.imageBytes != null && !_isStorageImageReference(currentReference);
    if (!hasNewLocalImage) return currentReference;

    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return currentReference;

    final fileName = _safeStorageFileName(
      currentReference.isEmpty
          ? '${asset.serialNumber}_${asset.modelName}.jpg'
          : currentReference,
    );
    final storagePath =
        '$userId/equipment/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from(_imageBucket).uploadBinary(
          storagePath,
          asset.imageBytes!,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _imageContentType(fileName),
            cacheControl: '3600',
          ),
        );
    return storagePath;
  }

  Future<void> _deleteStoredImage(String imageReference) async {
    if (!_isStorageImageReference(imageReference)) return;
    try {
      await _client.storage.from(_imageBucket).remove([imageReference]);
    } catch (_) {}
  }

  bool _isStorageImageReference(String value) =>
      value.isNotEmpty && !value.startsWith('http') && value.contains('/');

  String _safeStorageFileName(String value) {
    final safe = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return safe.isEmpty ? 'equipment.jpg' : safe;
  }

  String _imageContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
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
    if (rawAssetType != null && rawAssetType.isNotEmpty) return rawAssetType;

    final normalized = modelName.toLowerCase();
    if (normalized.contains('draeger') ||
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
    if (trimmed.isEmpty) return '';

    return trimmed
        .replaceAll('ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢', '-')
        .replaceAll('Ã‚-', '-')
        .replaceAll(RegExp(r'\s*-\s*'), ' - ');
  }

  String _mapStatusToSupabase(String status) {
    return switch (status) {
      'OPERATIONAL' => 'Operational',
      'MAINTENANCE' => 'Needs Maintenance',
      'OFFLINE' => 'Out of Order',
      'DECOMMISSIONED' => 'Decommissioned',
      _ => 'Operational',
    };
  }

  String _mapStatusToClient(String status) {
    return switch (status) {
      'Operational' => 'OPERATIONAL',
      'Needs Maintenance' => 'MAINTENANCE',
      'Out of Order' => 'OFFLINE',
      'Decommissioned' => 'DECOMMISSIONED',
      'OPERATIONAL' || 'MAINTENANCE' || 'OFFLINE' || 'DECOMMISSIONED' => status,
      _ => 'OPERATIONAL',
    };
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
