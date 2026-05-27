import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_1/services/gemma_simulation_service.dart';
import 'package:ma_1/services/google_chat_service.dart';

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

  // Dynamic Call Logs & Meetings storage
  final List<Map<String, dynamic>> _localCallLogs = [];
  final List<Map<String, dynamic>> _localMeetings = [];
  bool _isCommsLoaded = false;

  final List<Map<String, dynamic>> _localCallNotes = [];
  bool _isCallNotesLoaded = false;

  ChatService._init();

  List<Map<String, dynamic>> get fallbackContacts => [];

  List<Map<String, dynamic>> get fallbackConversations => [];

  // --- LOCAL PERSISTENCE HELPERS ---

  Future<void> _loadCommsData() async {
    if (_isCommsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final callLogsStr = prefs.getString('local_call_logs_v3');
      if (callLogsStr != null) {
        _localCallLogs.clear();
        final rawLogs = List<Map<String, dynamic>>.from(
            jsonDecode(callLogsStr).map((x) => Map<String, dynamic>.from(x)));
        final decoys = {"Dr. Sekai Nzenza", "Dr. Chipo Moyo", "Farai Gumbo", "Tendai Chidi", "Rufaro Moyo"};
        _localCallLogs.addAll(rawLogs.where((log) => !decoys.contains(log['name'])));
      }

      final meetingsStr = prefs.getString('local_meetings_v2');
      if (meetingsStr != null) {
        _localMeetings.clear();
        final rawMeetings = List<Map<String, dynamic>>.from(
            jsonDecode(meetingsStr).map((x) => Map<String, dynamic>.from(x)));
        final decoys = {"Dr. Sekai Nzenza", "Dr. Chipo Moyo", "Farai Gumbo", "Tendai Chidi", "Rufaro Moyo"};
        _localMeetings.addAll(rawMeetings.where((m) => !decoys.contains(m['host'])));
      }
    } catch (e) {
      debugPrint("Error loading local call logs & meetings: $e");
    }
    _isCommsLoaded = true;
  }

  Future<void> _saveCallLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_call_logs_v3', jsonEncode(_localCallLogs));
    } catch (e) {
      debugPrint("Error saving local call logs: $e");
    }
  }

  Future<void> _saveMeetings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_meetings_v2', jsonEncode(_localMeetings));
    } catch (e) {
      debugPrint("Error saving local meetings: $e");
    }
  }

  // --- DYNAMIC CALL LOGS API ---
  Future<List<Map<String, dynamic>>> getCallLogs() async {
    await _loadCommsData();
    return _localCallLogs;
  }

  Future<void> addCallLog(Map<String, dynamic> log) async {
    await _loadCommsData();
    _localCallLogs.insert(0, log);
    await _saveCallLogs();
  }

  // --- DYNAMIC MEETINGS API ---
  Future<List<Map<String, dynamic>>> getMeetings() async {
    await _loadCommsData();
    return _localMeetings;
  }

  Future<void> addMeeting(Map<String, dynamic> meeting) async {
    await _loadCommsData();
    _localMeetings.insert(0, meeting);
    await _saveMeetings();
  }

  String generateMeetUrl() {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    final rand = math.Random();
    String block(int len) {
      return List.generate(len, (_) => letters[rand.nextInt(letters.length)]).join('');
    }
    return 'https://meet.google.com/${block(3)}-${block(4)}-${block(3)}';
  }

  Future<void> _loadCallNotes() async {
    if (_isCallNotesLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesStr = prefs.getString('local_call_notes_v3');
      if (notesStr != null) {
        _localCallNotes.clear();
        _localCallNotes.addAll(List<Map<String, dynamic>>.from(
            jsonDecode(notesStr).map((x) => Map<String, dynamic>.from(x))));
      }
    } catch (e) {
      debugPrint("Error loading call notes: $e");
    }
    _isCallNotesLoaded = true;
  }

  Future<void> saveCallNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_call_notes_v3', jsonEncode(_localCallNotes));
    } catch (e) {
      debugPrint("Error saving call notes: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getCallNotes() async {
    await _loadCallNotes();
    if (_localCallNotes.isEmpty) {
      _localCallNotes.addAll([
        {
          "id": "CALL-4890",
          "equipment": "Mindray SV300 Ventilator",
          "technician": "Marcus Chen",
          "date": "Today, 14:12",
          "issue": "Frequent pressure deviations (Error Code: P-ERR-11).",
          "notes": "Collaboratively analyzed O2 sensor flow rates. Instructed field engineer to replace the secondary flow valve. Flow sensor recalibrated and tested under simulated lung load. Operating capacity restored to 100%.",
        },
        {
          "id": "CALL-4752",
          "equipment": "Drager Evita V500",
          "technician": "Sarah Jenkins",
          "date": "Yesterday, 10:45",
          "issue": "System backup battery failure alert during grid fluctuations.",
          "notes": "Guided technician to inspect battery terminals. Deployed external UPS module in Paediatric Ward ER to maintain continuous operation. Logged a preventative maintenance task to swap the internal Li-Ion battery pack within 48 hours.",
        },
        {
          "id": "CALL-4610",
          "equipment": "Aeonmed VG70",
          "technician": "Tadiwanashe M.",
          "date": "May 21, 15:30",
          "issue": "Expiratory valve locking due to humidity accumulation.",
          "notes": "Ongoing expiratory condensation cleared. Heated moisture trap aligned. recalibrated expiratory flow parameters. Calibrations matching guidelines. Valve returned to service.",
        }
      ]);
      await saveCallNotes();
    }
    return _localCallNotes;
  }

  Future<void> addCallNote(Map<String, dynamic> note) async {
    await _loadCallNotes();
    _localCallNotes.insert(0, note);
    await saveCallNotes();
  }

  // --- GET REGISTERED TECHNICIANS ---
  Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      final currentUid = currentUserId;
      final response = await _client
          .from('users')
          .select('id, name, reg_number, online, last_seen')
          .order('name');
      
      final contacts = List<Map<String, dynamic>>.from(response)
          .where((row) => row['id'] != currentUid)
          .map((row) {
            return {
              ...row,
              'phone': row['phone'] ?? '',
              'role': row['role'] ?? row['reg_number'] ?? 'Technician',
            };
          })
          .toList();
      return contacts;
    } catch (e) {
      debugPrint("Error fetching contacts from Supabase: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    List<Map<String, dynamic>> list = [];

    try {
      final response = await _client
          .from('conversations')
          .select('id, group_name, last_message, last_message_time, is_group')
          .order('last_message_time', ascending: false);
      final conversations = List<Map<String, dynamic>>.from(response);

      // Resolve each conversation's details using live contacts
      final contacts = await getContacts();
      final contactsMap = {for (var c in contacts) c['id']: c};

      list = conversations.map((row) {
        final id = row['id']?.toString() ?? '';
        final isGroup = row['is_group'] == true;
        
        final contact = contactsMap[id] ?? {
          'name': row['group_name'] ?? 'Clinical Conversation',
          'online': false,
          'role': isGroup ? 'Group' : 'Technician',
          'phone': '',
        };

        String extractedPhone = '';
        final String gName = row['group_name']?.toString() ?? '';
        if (gName.startsWith('Technician (')) {
          extractedPhone = gName.replaceAll('Technician (', '').replaceAll(')', '').trim();
        } else {
          extractedPhone = contact['phone']?.toString() ?? '';
        }

        return {
          'id': id,
          'name': isGroup ? (row['group_name'] ?? 'Clinical Group') : contact['name'],
          'last_message': row['last_message'] ?? 'Conversation started',
          'last_message_time': row['last_message_time'] ?? DateTime.now().toUtc().toIso8601String(),
          'unread': 0,
          'online': contact['online'] == true || contact['online'] == 1,
          'role': contact['role'] ?? contact['reg_number'] ?? 'Technician',
          'phone': extractedPhone,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching conversations from Supabase: $e");
    }

    // Optional Google Chat Space injection. Disabled unless explicitly configured.
    if (GoogleChatService.instance.isConfiguredForApi) {
      try {
        final List<Map<String, dynamic>> realMessages =
            await GoogleChatService.instance.fetchMessages();
        String lastMsg = 'No messages in this workspace room.';
        String lastTime = DateTime.now().toUtc().toIso8601String();
        if (realMessages.isNotEmpty) {
          final last = realMessages.last;
          lastMsg = '${last['sender_name']}: ${last['message_text']}';
          lastTime = last['timestamp'];
        }

        list.insert(0, {
          'id': 'google-chat-workspace',
          'name': 'Pulse Workspace (Google Chat)',
          'last_message': lastMsg,
          'last_message_time': lastTime,
          'unread': 0,
          'online': true,
          'role': 'Real-time Google Workspace Space',
          'phone': 'GCP Service Account Sync',
        });
      } catch (e) {
        debugPrint("Error injecting Google Chat Workspace: $e");
      }
    }

    return list;
  }

  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    if (conversationId == 'google-chat-workspace') {
      return await GoogleChatService.instance.fetchMessages();
    }

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
      return messages;
    } catch (e) {
      debugPrint("Error fetching messages from Supabase: $e");
      return [];
    }
  }

  // --- CONNECT REALTIME CHANNELS ---
  void connect(String userId) {
    if (userId == 'UNKNOWN' || userId.isEmpty) return;

    disconnect();
    isConnected.value = true;

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

    _typingChannel = _client.channel('typing_indicators');
    _typingChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        typingIndicator.value = payload;
      },
    );
    _typingChannel!.subscribe();

    _presenceChannel = _client.channel('online_presence');
    _presenceChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel!.track({
          'user_id': userId,
          'online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        });

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
    debugPrint("Joined Supabase conversation room: $conversationId");
  }

  // --- SEND CHAT MESSAGE ---
  Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> payload) async {
    final String conversationId = payload['conversation_id'];
    final String msgText = payload['message_text'];

    if (conversationId == 'google-chat-workspace') {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final userMsg = {
        'id': 'gchat-${DateTime.now().microsecondsSinceEpoch}',
        'conversation_id': conversationId,
        'sender_id': 'me',
        'sender_name': currentUserName ?? 'Clinical Coordinator',
        'message_text': msgText,
        'message_type': 'text',
        'timestamp': timestamp,
        'delivery_state': 'sent',
      };

      // Dispatch to Google Chat space asynchronously in background
      GoogleChatService.instance.sendTextMessage(msgText);

      return userMsg;
    }

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final optimisticMessage = {
      'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
      'conversation_id': conversationId,
      'sender_id': currentUserId ?? payload['sender_id'] ?? 'local-technician',
      'sender_name': currentUserName ?? payload['sender_name'] ?? 'Technician',
      'message_text': msgText,
      'message_type': payload['message_type'] ?? 'text',
      'timestamp': timestamp,
      'delivery_state': 'sent',
    };

    try {
      // Ensure the conversation entry already exists in Supabase
      final existingConvo = await _client
          .from('conversations')
          .select('id')
          .eq('id', conversationId)
          .maybeSingle();

      if (existingConvo == null) {
        String groupName = payload['recipient_name'] ?? 'Direct Chat';
        try {
          if (payload['recipient_name'] == null) {
            final recipientUser = await _client
                .from('users')
                .select('name')
                .eq('id', conversationId)
                .maybeSingle();
            if (recipientUser != null && recipientUser['name'] != null) {
              groupName = recipientUser['name'];
            }
          }
        } catch (_) {}

        await _client.from('conversations').insert({
          'id': conversationId,
          'is_group': false,
          'group_name': groupName,
          'last_message': msgText,
          'last_message_time': timestamp,
        });
      } else {
        await _client.from('conversations').update({
          'last_message': msgText,
          'last_message_time': timestamp,
        }).eq('id', conversationId);
      }

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

  // --- TRIGGER IN-APP AUDIO CALL RESPONSE GENERATION ---
  Future<String> getSimulatedCallReply({
    required String contactId,
    required String userSpeechText,
    required List<Map<String, dynamic>> callHistory,
  }) async {
    final contacts = await getContacts();
    final contact = contacts.firstWhere(
      (c) => c['id'] == contactId,
      orElse: () => {
        'name': 'Clinical Coordinator',
        'role': 'Technician',
      },
    );
    return GemmaSimulationService.instance.generateReply(
      contactId: contactId,
      contactName: contact['name'],
      role: contact['role'],
      userMessage: userSpeechText,
      priorMessages: callHistory,
      isVoiceCall: true,
    );
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

  String deterministicUuidFromPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '').trim();
    if (clean.isEmpty) {
      return '00000000-0000-0000-0000-000000000000';
    }
    
    int seed = int.tryParse(clean) ?? 0;
    if (seed == 0) {
      for (int i = 0; i < clean.length; i++) {
        seed = (seed * 31 + clean.codeUnitAt(i)) & 0xFFFFFFFF;
      }
    }
    
    int x = seed;
    final StringBuffer hex = StringBuffer();
    for (int i = 0; i < 32; i++) {
      x = (1103515245 * x + 12345) & 0x7FFFFFFF;
      final int digit = x % 16;
      hex.write(digit.toRadixString(16));
    }
    
    final String h = hex.toString();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }

  String? _conversationName(String? senderId) {
    if (senderId == null || senderId.isEmpty) return null;
    return null;
  }
}
