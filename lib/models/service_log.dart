class ServiceLog {
  final int? id;
  final String machineModel;
  final String errorCode;
  final String notes;
  final String timestamp;
  final int isSynced;

  ServiceLog({
    this.id,
    required this.machineModel,
    required this.errorCode,
    required this.notes,
    required this.timestamp,
    this.isSynced = 0,
  });

  // Convert a ServiceLog into a Map. The keys must correspond to the names of the
  // columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'machine_model': machineModel,
      'error_code': errorCode,
      'notes': notes,
      'timestamp': timestamp,
      'is_synced': isSynced,
    };
  }

  // Convert a Map into a ServiceLog. The keys must correspond to the names of the
  // columns in the database.
  factory ServiceLog.fromMap(Map<String, dynamic> map) {
    return ServiceLog(
      id: map['id'],
      machineModel: map['machine_model'],
      errorCode: map['error_code'],
      notes: map['notes'],
      timestamp: map['timestamp'],
      isSynced: map['is_synced'],
    );
  }
  
  @override
  String toString() {
    return 'ServiceLog{id: $id, machineModel: $machineModel, errorCode: $errorCode, notes: $notes, timestamp: $timestamp, isSynced: $isSynced}';
  }
}
