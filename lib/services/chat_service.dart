import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final ChatService instance = ChatService._init();
  final _client = Supabase.instance.client;

  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<Map<String, dynamic>?> incomingMessage = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> typingIndicator = ValueNotifier(null);

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

  // --- GET REGISTERED TECHNICIANS FROM SUPABASE ---
  Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      final response = await _client
          .from('users')
          .select('id, name, reg_number, online, last_seen')
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching contacts from Supabase: $e");
      return [];
    }
  }

  // --- CONNECT REALTIME CHANNELS ---
  void connect(String userId) {
    if (userId == 'UNKNOWN' || userId.isEmpty) return;

    // Disconnect existing channels if any
    disconnect();

    isConnected.value = true;

    // 1. Listen to Postgres changes for live messages
    _msgChannel = _client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final record = payload.newRecord;
            incomingMessage.value = record;
            incomingMessage.notifyListeners();
          },
        );
    _msgChannel!.subscribe();

    // 2. Broadcast channel for typing indicators
    _typingChannel = _client.channel('typing_indicators');
    _typingChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        typingIndicator.value = payload;
        typingIndicator.notifyListeners();
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
  Future<void> sendMessage(Map<String, dynamic> payload) async {
    try {
      final String conversationId = payload['conversation_id'];
      final String msgText = payload['message_text'];

      // Insert directly into Supabase messages table
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'message_text': msgText,
        'message_type': payload['message_type'] ?? 'text',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      // Update conversations catalog metadata
      await _client.from('conversations').update({
        'last_message': msgText,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', conversationId);

    } catch (e) {
      debugPrint("Error inserting message on Supabase: $e");
    }
  }

  // --- BROADCAST TYPING STATUS ---
  void sendTyping(String conversationId, String userId) {
    if (_typingChannel == null) return;
    _typingChannel!.sendBroadcast(
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
        _client.from('users').update({
          'online': false,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId).then((_) {}, onError: (_) {});
      }
      _client.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
  }
}