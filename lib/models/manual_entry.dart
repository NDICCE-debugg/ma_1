class ManualEntry {
  final int? id;
  final String machineModel;
  final String category; // e.g., "Error Code", "Maintenance"
  final String title;
  final String content;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final List<int>? fileBytes;
  final String? uploadedAt;

  ManualEntry({
    this.id,
    required this.machineModel,
    required this.category,
    required this.title,
    required this.content,
    this.fileName,
    this.fileType,
    this.fileSize,
    this.fileBytes,
    this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'machine_model': machineModel,
      'category': category,
      'title': title,
      'content': content,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'file_bytes': fileBytes,
      'uploaded_at': uploadedAt,
    };
  }

  factory ManualEntry.fromMap(Map<String, dynamic> map) {
    return ManualEntry(
      id: map['id'],
      machineModel: map['machine_model'] ?? '',
      category: map['category'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      fileName: map['file_name'],
      fileType: map['file_type'],
      fileSize: map['file_size'],
      fileBytes: map['file_bytes'],
      uploadedAt: map['uploaded_at'],
    );
  }
}
