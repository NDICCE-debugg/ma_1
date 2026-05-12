class HospitalAsset {
  final int? id;
  final String assetType; // 'ventilator' or 'anaesthetic_machine'
  final String modelName;
  final String serialNumber;
  final String hospitalUnit; // 'PAEDIATRIC', 'MATERNITY', 'MAIN'
  final String wardLocation;
  final String status; // 'OPERATIONAL', 'MAINTENANCE', 'OFFLINE', 'DECOMMISSIONED'
  final String dateAcquired;
  final String lastServiceDate;
  final String serviceInterval;
  final String notes;

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
    };
  }

  factory HospitalAsset.fromMap(Map<String, dynamic> map) {
    return HospitalAsset(
      id: map['id'],
      assetType: map['asset_type'],
      modelName: map['model_name'],
      serialNumber: map['serial_number'],
      hospitalUnit: map['hospital_unit'],
      wardLocation: map['ward_location'],
      status: map['status'],
      dateAcquired: map['date_acquired'],
      lastServiceDate: map['last_service_date'],
      serviceInterval: map['service_interval'],
      notes: map['notes'],
    );
  }
}