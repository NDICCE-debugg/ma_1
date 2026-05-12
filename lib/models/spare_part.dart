class SparePart {
  final int? id;
  final String name;
  final String compatibleModel;
  final int quantity;
  final int reorderThreshold;
  final String location;
  final String unit;
  final String lastRestocked;
  final String notes;

  SparePart({
    this.id,
    required this.name,
    required this.compatibleModel,
    required this.quantity,
    required this.reorderThreshold,
    required this.location,
    this.unit = 'units',
    this.lastRestocked = 'UNKNOWN',
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'compatible_model': compatibleModel,
      'quantity': quantity,
      'reorder_threshold': reorderThreshold,
      'location': location,
      'unit': unit,
      'last_restocked': lastRestocked,
      'notes': notes,
    };
  }

  factory SparePart.fromMap(Map<String, dynamic> map) {
    return SparePart(
      id: map['id'],
      name: map['name'],
      compatibleModel: map['compatible_model'],
      quantity: map['quantity'],
      reorderThreshold: map['reorder_threshold'],
      location: map['location'],
      unit: map['unit'] ?? 'units',
      lastRestocked: map['last_restocked'] ?? 'UNKNOWN',
      notes: map['notes'] ?? '',
    );
  }
}