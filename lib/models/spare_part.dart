import 'dart:typed_data';

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
  final String imageFileName;
  final String imageUrl;
  final Uint8List? imageBytes;

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
    this.imageFileName = '',
    this.imageUrl = '',
    this.imageBytes,
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
      'image_file_name': imageFileName,
      'image_url': imageUrl,
      'image_bytes': imageBytes,
    };
  }

  SparePart copyWith({
    int? id,
    String? name,
    String? compatibleModel,
    int? quantity,
    int? reorderThreshold,
    String? location,
    String? unit,
    String? lastRestocked,
    String? notes,
    String? imageFileName,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    return SparePart(
      id: id ?? this.id,
      name: name ?? this.name,
      compatibleModel: compatibleModel ?? this.compatibleModel,
      quantity: quantity ?? this.quantity,
      reorderThreshold: reorderThreshold ?? this.reorderThreshold,
      location: location ?? this.location,
      unit: unit ?? this.unit,
      lastRestocked: lastRestocked ?? this.lastRestocked,
      notes: notes ?? this.notes,
      imageFileName: imageFileName ?? this.imageFileName,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  factory SparePart.fromMap(Map<String, dynamic> map) {
    final imageReference =
        (map['image_file_name'] ?? map['image_url'] ?? '').toString();
    return SparePart(
      id: map['id'],
      name: map['name'] ?? '',
      compatibleModel: map['compatible_model'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      reorderThreshold: (map['reorder_threshold'] as num?)?.toInt() ?? 1,
      location: map['location'] ?? 'General Store',
      unit: map['unit'] ?? 'units',
      lastRestocked: map['last_restocked'] ?? 'UNKNOWN',
      notes: map['notes'] ?? '',
      imageFileName: imageReference,
      imageUrl: imageReference.startsWith('http') ? imageReference : '',
      imageBytes: map['image_bytes'] as Uint8List?,
    );
  }
}
