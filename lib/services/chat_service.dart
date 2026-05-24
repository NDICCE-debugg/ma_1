import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final ChatService instance = ChatService._init();
  final _client = Supabase.instance.client;

  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<Map<String, dynamic>?> incomingMessage =
      ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> typingIndicator =
      ValueNotifier(null);

  // Dynamic getters to ensure synchronisation with live Supabase session
  String? get currentUserId => _client.auth.currentUser?.id;
  String? get currentUserName {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return (user.userMetadata?['name'] as String?) ?? user.email;
  }

  RealtimeChannel? _msgChannel;
  RealtimeChannel? _typingChannel;
  RealtimeChannel? _presenceChannel;

  ChatService._init();

  List<Map<String, dynamic>> get fallbackContacts => [
        {
          'id': 'dr-chipo-moyo',
          'name': 'Dr. Chipo Moyo',
          'reg_number': 'CONSULT-ICU',
          'phone': '+263772123456',
          'online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
          'role': 'ICU Consultant',
        },
        {
          'id': 'farai-gumbo',
          'name': 'Farai Gumbo',
          'reg_number': 'TECH-VENT',
          'phone': '+263773456789',
          'online': false,
          'last_seen': DateTime.now()
              .subtract(const Duration(hours: 3))
              .toUtc()
              .toIso8601String(),
          'role': 'Ventilator Technician',
        },
        {
          'id': 'tendai-chidi',
          'name': 'Tendai Chidi',
          'reg_number': 'PLANT-OXY',
          'phone': '+263774567890',
          'online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
          'role': 'Medical Gas Technician',
        },
      ];

  List<Map<String, dynamic>> get fallbackConversations => [
        {
          'id': 'dr-chipo-moyo',
          'name': 'Dr. Chipo Moyo',
          'last_message':
              "Urgent: ICU Aeonmed VG70 has a constant Low O2 Pressure fault alarm.",
          'last_message_time': DateTime.now()
              .subtract(const Duration(minutes: 11))
              .toUtc()
              .toIso8601String(),
          'unread': 2,
          'online': true,
          'role': 'ICU Consultant',
        },
        {
          'id': 'farai-gumbo',
          'name': 'Farai Gumbo',
          'last_message':
              "Evita V500 PEEP valve calibration test complete. Ready to redeploy.",
          'last_message_time': DateTime.now()
              .subtract(const Duration(days: 1, hours: 2))
              .toUtc()
              .toIso8601String(),
          'unread': 0,
          'online': false,
          'role': 'Ventilator Technician',
        },
        {
          'id': 'tendai-chidi',
          'name': 'Tendai Chidi',
          'last_message':
              "Central oxygen plant manifold pressure is dropping below 4.2 bar.",
          'last_message_time': DateTime.now()
              .subtract(const Duration(days: 1, hours: 7))
              .toUtc()
              .toIso8601String(),
          'unread': 1,
          'online': true,
          'role': 'Medical Gas Technician',
        },
      ];

  // --- GET REGISTERED TECHNICIANS FROM SUPABASE ---
  Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      final response = await _client
          .from('users')
          .select('id, name, reg_number, online, last_seen')
          .order('name');
      final contacts = List<Map<String, dynamic>>.from(response).map((row) {
        final fallback = _fallbackContactFor(row['id']?.toString());
        return {
          ...row,
          'phone': fallback?['phone'] ?? '',
          'role': fallback?['role'] ?? row['reg_number'] ?? 'Technician',
        };
      }).toList();
      return contacts.isEmpty ? fallbackContacts : contacts;
    } catch (e) {
      debugPrint("Error fetching contacts from Supabase: $e");
      return fallbackContacts;
    }
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final response = await _client
          .from('conversations')
          .select('id, group_name, last_message, last_message_time, is_group')
          .order('last_message_time', ascending: false);
      final conversations =
          List<Map<String, dynamic>>.from(response).map((row) {
        final id = row['id']?.toString() ?? '';
        final contact = fallbackContacts.firstWhere(
          (c) => c['id'] == id,
          orElse: () => {
            'name': row['group_name'] ?? 'Clinical Conversation',
            'online': false,
            'role': row['is_group'] == true ? 'Group' : 'Technician',
          },
        );
        return {
          'id': id,
          'name': row['group_name'] ?? contact['name'],
          'last_message': row['last_message'] ?? 'Conversation started',
          'last_message_time': row['last_message_time'],
          'unread': 0,
          'online': contact['online'] == true || contact['online'] == 1,
          'role': contact['role'] ?? contact['reg_number'] ?? 'Technician',
          'phone': contact['phone'] ?? '',
        };
      }).toList();
      return conversations.isEmpty ? fallbackConversations : conversations;
    } catch (e) {
      debugPrint("Error fetching conversations from Supabase: $e");
      return fallbackConversations;
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    try {
      final response = await _client
          .from('messages')
          .select(
              'id, conversation_id, sender_id, message_text, message_type, timestamp')
          .eq('conversation_id', conversationId)
          .order('timestamp');
      final messages = List<Map<String, dynamic>>.from(response)
          .map(_withSenderDisplayName)
          .toList();
      if (messages.isNotEmpty) return messages;
    } catch (e) {
      debugPrint("Error fetching messages from Supabase: $e");
    }

    final now = DateTime.now();
    return [
      {
        'id': 'seed-1-$conversationId',
        'conversation_id': conversationId,
        'sender_id': conversationId,
        'sender_name': fallbackConversations.firstWhere(
          (c) => c['id'] == conversationId,
          orElse: () => {'name': 'Clinical Team'},
        )['name'],
        'message_text':
            'Can you check this equipment case and confirm the next maintenance action?',
        'message_type': 'text',
        'timestamp':
            now.subtract(const Duration(minutes: 18)).toUtc().toIso8601String(),
      },
      {
        'id': 'seed-2-$conversationId',
        'conversation_id': conversationId,
        'sender_id': currentUserId ?? 'local-technician',
        'sender_name': currentUserName ?? 'Technician',
        'message_text':
            'I am reviewing the service logs and will update you with the safest next step.',
        'message_type': 'text',
        'timestamp':
            now.subtract(const Duration(minutes: 14)).toUtc().toIso8601String(),
      },
    ];
  }

  // --- CONNECT REALTIME CHANNELS ---
  void connect(String userId) {
    if (userId == 'UNKNOWN' || userId.isEmpty) return;

    // Disconnect existing channels if any
    disconnect();

    isConnected.value = true;

    // 1. Listen to Postgres changes for live messages
    _msgChannel = _client.channel('public:messages').onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final record = payload.newRecord;
            incomingMessage.value = _withSenderDisplayName(record);
          },
        );
    _msgChannel!.subscribe();

    // 2. Broadcast channel for typing indicators
    _typingChannel = _client.channel('typing_indicators');
    _typingChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        typingIndicator.value = payload;
      },
    );
    _typingChannel!.subscribe();

    // 3. Presence tracking channel for active statuses
    _presenceChannel = _client.channel('online_presence');
    _presenceChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Track this technician's online status
        await _presenceChannel!.track({
          'user_id': userId,
          'online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        });

        // Set online status in users profile
        try {
          await _client.from('users').update({
            'online': true,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', userId);
        } catch (_) {}
      }
    });
  }

  void joinRoom(String conversationId) {
    // Rooms are handled structurally via conversationId in messages; no explicit Socket.IO join required
    debugPrint("Joined Supabase conversation room: $conversationId");
  }

  // --- SEND CHAT MESSAGE ---
  Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> payload) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final optimisticMessage = {
      'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
      'conversation_id': payload['conversation_id'],
      'sender_id': currentUserId ?? payload['sender_id'] ?? 'local-technician',
      'sender_name': currentUserName ?? payload['sender_name'] ?? 'Technician',
      'message_text': payload['message_text'],
      'message_type': payload['message_type'] ?? 'text',
      'timestamp': timestamp,
      'delivery_state': 'sent',
    };

    try {
      final String conversationId = payload['conversation_id'];
      final String msgText = payload['message_text'];

      // Insert directly into Supabase messages table
      final inserted = await _client
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': currentUserId ?? payload['sender_id'],
            'message_text': msgText,
            'message_type': payload['message_type'] ?? 'text',
            'timestamp': timestamp,
          })
          .select()
          .maybeSingle();

      // Update conversations catalog metadata
      await _client.from('conversations').update({
        'last_message': msgText,
        'last_message_time': timestamp,
      }).eq('id', conversationId);
      return inserted == null
          ? optimisticMessage
          : {
              ..._withSenderDisplayName(Map<String, dynamic>.from(inserted)),
              'delivery_state': 'sent',
            };
    } catch (e) {
      debugPrint("Error inserting message on Supabase: $e");
      return {
        ...optimisticMessage,
        'delivery_state': 'queued',
      };
    }
  }

  // --- BROADCAST TYPING STATUS ---
  void sendTyping(String conversationId, String userId) {
    if (_typingChannel == null) return;
    _typingChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'conversation_id': conversationId,
        'user_id': userId,
      },
    );
  }

  // --- CLEAN TEARDOWN ---
  void disconnect() {
    isConnected.value = false;

    if (_msgChannel != null) {
      _client.removeChannel(_msgChannel!);
      _msgChannel = null;
    }
    if (_typingChannel != null) {
      _client.removeChannel(_typingChannel!);
      _typingChannel = null;
    }
    if (_presenceChannel != null) {
      // Mark user offline in DB before leaving
      final userId = currentUserId;
      if (userId != null) {
        _client
            .from('users')
            .update({
              'online': false,
              'last_seen': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', userId)
            .then((_) {}, onError: (_) {});
      }
      _client.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
  }

  Map<String, dynamic> _withSenderDisplayName(Map<String, dynamic> message) {
    final senderId = message['sender_id']?.toString();
    final isCurrentUser = senderId != null && senderId == currentUserId;

    return {
      ...message,
      'sender_name': message['sender_name'] ??
          (isCurrentUser
              ? currentUserName ?? 'Technician'
              : _conversationName(senderId) ?? 'Clinical Team'),
      'message_type': message['message_type'] ?? 'text',
      'delivery_state': message['delivery_state'] ?? 'sent',
    };
  }

  String? _conversationName(String? senderId) {
    if (senderId == null || senderId.isEmpty) return null;
    for (final contact in fallbackContacts) {
      if (contact['id'] == senderId) return contact['name']?.toString();
    }
    for (final conversation in fallbackConversations) {
      if (conversation['id'] == senderId) {
        return conversation['name']?.toString();
      }
    }
    return null;
  }

  Map<String, dynamic>? _fallbackContactFor(String? id) {
    if (id == null) return null;
    for (final contact in fallbackContacts) {
      if (contact['id'] == id) return contact;
    }
    return null;
  }
}
