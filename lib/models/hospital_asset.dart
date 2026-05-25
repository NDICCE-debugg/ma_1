import 'dart:typed_data';

class HospitalAsset {
  final int? id;
  final String assetType; // 'ventilator' or 'anaesthetic_machine'
  final String modelName;
  final String serialNumber;
  final String hospitalUnit; // 'PAEDIATRIC', 'MATERNITY', 'MAIN'
  final String wardLocation;
  final String
      status; // 'OPERATIONAL', 'MAINTENANCE', 'OFFLINE', 'DECOMMISSIONED'
  final String dateAcquired;
  final String lastServiceDate;
  final String serviceInterval;
  final String notes;
  final String imageFileName;
  final String imageUrl;
  final Uint8List? imageBytes;

  HospitalAsset({
    this.id,
    required this.assetType,
    required this.modelName,
    required this.serialNumber,
    required this.hospitalUnit,
    required this.wardLocation,
    required this.status,
    required this.dateAcquired,
    required this.lastServiceDate,
    required this.serviceInterval,
    required this.notes,
    this.imageFileName = '',
    this.imageUrl = '',
    this.imageBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'asset_type': assetType,
      'model_name': modelName,
      'serial_number': serialNumber,
      'hospital_unit': hospitalUnit,
      'ward_location': wardLocation,
      'status': status,
      'date_acquired': dateAcquired,
      'last_service_date': lastServiceDate,
      'service_interval': serviceInterval,
      'notes': notes,
      'image_file_name': imageFileName,
      'image_url': imageUrl,
      'image_bytes': imageBytes,
    };
  }

  HospitalAsset copyWith({
    int? id,
    String? assetType,
    String? modelName,
    String? serialNumber,
    String? hospitalUnit,
    String? wardLocation,
    String? status,
    String? dateAcquired,
    String? lastServiceDate,
    String? serviceInterval,
    String? notes,
    String? imageFileName,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    return HospitalAsset(
      id: id ?? this.id,
      assetType: assetType ?? this.assetType,
      modelName: modelName ?? this.modelName,
      serialNumber: serialNumber ?? this.serialNumber,
      hospitalUnit: hospitalUnit ?? this.hospitalUnit,
      wardLocation: wardLocation ?? this.wardLocation,
      status: status ?? this.status,
      dateAcquired: dateAcquired ?? this.dateAcquired,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      serviceInterval: serviceInterval ?? this.serviceInterval,
      notes: notes ?? this.notes,
      imageFileName: imageFileName ?? this.imageFileName,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  factory HospitalAsset.fromMap(Map<String, dynamic> map) {
    final imageReference =
        (map['image_file_name'] ?? map['image_url'] ?? '').toString();
    return HospitalAsset(
      id: (map['id'] as num?)?.toInt(),
      assetType: map['asset_type']?.toString() ?? '',
      modelName: map['model_name']?.toString() ?? '',
      serialNumber: map['serial_number']?.toString() ?? '',
      hospitalUnit: map['hospital_unit']?.toString() ?? '',
      wardLocation: map['ward_location']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      dateAcquired: map['date_acquired']?.toString() ?? '',
      lastServiceDate: map['last_service_date']?.toString() ?? '',
      serviceInterval: map['service_interval']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      imageFileName: imageReference.startsWith('http') ? '' : imageReference,
      imageUrl: (map['image_url']?.toString() ?? '').isNotEmpty
          ? map['image_url'].toString()
          : (imageReference.startsWith('http') ? imageReference : ''),
      imageBytes: map['image_bytes'] as Uint8List?,
    );
  }
}

