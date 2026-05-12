class ManualEntry {
  final int? id;
  final String machineModel;
  final String category; // e.g., "Error Code", "Maintenance"
  final String title;
  final String content;
  
  ManualEntry({
    this.id,
    required this.machineModel,
    required this.category,
    required this.title,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'machine_model': machineModel,
      'category': category,
      'title': title,
      'content': content,
    };
  }

  factory ManualEntry.fromMap(Map<String, dynamic> map) {
    return ManualEntry(
      id: map['id'],
      machineModel: map['machine_model'],
      category: map['category'],
      title: map['title'],
      content: map['content'],
    );
  }
}