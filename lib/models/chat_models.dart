class Contact {
  final int? id;
  final String name;
  final String regNumber;
  final String createdAt;

  Contact({this.id, required this.name, required this.regNumber, required this.createdAt});

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'reg_number': regNumber, 'created_at': createdAt,
  };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
    id: map['id'], name: map['name'], regNumber: map['reg_number'], createdAt: map['created_at'],
  );
}

class ChatMessage {
  final int? id;
  final int contactId;
  final String messageText;
  final int isSent;
  final String timestamp;
  final String syncStatus;

  ChatMessage({
    this.id, required this.contactId, required this.messageText, 
    required this.isSent, required this.timestamp, required this.syncStatus
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'contact_id': contactId, 'message_text': messageText,
    'is_sent': isSent, 'timestamp': timestamp, 'sync_status': syncStatus,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'], contactId: map['contact_id'], messageText: map['message_text'],
    isSent: map['is_sent'], timestamp: map['timestamp'], syncStatus: map['sync_status'],
  );
}