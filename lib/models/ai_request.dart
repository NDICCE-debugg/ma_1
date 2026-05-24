class AiRequest {
  final int? id;
  final String inputText;
  final String inputType; // 'text', 'voice', 'image'
  final String? imagePath;
  final String timestamp;
  final String status;

  AiRequest({
    this.id,
    required this.inputText,
    required this.inputType,
    this.imagePath,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'input_text': inputText,
      'input_type': inputType,
      'image_path': imagePath,
      'timestamp': timestamp,
      'status': status,
    };
  }

  factory AiRequest.fromMap(Map<String, dynamic> map) {
    return AiRequest(
      id: map['id'],
      inputText: map['input_text'],
      inputType: map['input_type'],
      imagePath: map['image_path'],
      timestamp: map['timestamp'],
      status: map['status'],
    );
  }
}
