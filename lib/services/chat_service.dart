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

  // Local simulated messages storage
  final Map<String, List<Map<String, dynamic>>> _localSimulatedMessages = {};
  bool _isLocalCacheLoaded = false;

  // Dynamic Call Logs & Meetings storage
  final List<Map<String, dynamic>> _localCallLogs = [];
  final List<Map<String, dynamic>> _localMeetings = [];
  bool _isCommsLoaded = false;

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
          'online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
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
        {
          'id': 'dr-sekai-nzenza',
          'name': 'Dr. Sekai Nzenza',
          'reg_number': 'CMO-ADMIN',
          'phone': '+263771987654',
          'online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
          'role': 'Chief Medical Officer',
        },
        {
          'id': 'rufaro-moyo',
          'name': 'Rufaro Moyo',
          'reg_number': 'BIOMED-HEAD',
          'phone': '+263782345678',
          'online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
          'role': 'Biomedical Department Head',
        },
        {
          'id': 'kudakwashe-hove',
          'name': 'Kudakwashe Hove',
          'reg_number': 'LAB-SPECIAL',
          'phone': '+263715678901',
          'online': true,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
          'role': 'Senior Laboratory Specialist',
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
          'phone': '+263772123456',
        },
        {
          'id': 'farai-gumbo',
          'name': 'Farai Gumbo',
          'last_message':
              "Evita V500 PEEP valve calibration test complete. Ready to redeploy.",
          'last_message_time': DateTime.now()
              .subtract(const Duration(hours: 3))
              .toUtc()
              .toIso8601String(),
          'unread': 0,
          'online': true,
          'role': 'Ventilator Technician',
          'phone': '+263773456789',
        },
        {
          'id': 'tendai-chidi',
          'name': 'Tendai Chidi',
          'last_message':
              "Central oxygen plant manifold pressure is dropping below 4.2 bar.",
          'last_message_time': DateTime.now()
              .subtract(const Duration(hours: 5))
              .toUtc()
              .toIso8601String(),
          'unread': 1,
          'online': true,
          'role': 'Medical Gas Technician',
          'phone': '+263774567890',
        },
        {
          'id': 'dr-sekai-nzenza',
          'name': 'Dr. Sekai Nzenza',
          'last_message':
              "BMET Team, please prepare the technical audit report for the ICU fleet.",
          'last_message_time': DateTime.now()
              .subtract(const Duration(hours: 8))
              .toUtc()
              .toIso8601String(),
          'unread': 0,
          'online': true,
          'role': 'Chief Medical Officer',
          'phone': '+263771987654',
        },
        {
          'id': 'rufaro-moyo',
          'name': 'Rufaro Moyo',
          'last_message':
              "Regarding the spare parts inventory: do we have the turbine replacements?",
          'last_message_time': DateTime.now()
              .subtract(const Duration(hours: 12))
              .toUtc()
              .toIso8601String(),
          'unread': 0,
          'online': true,
          'role': 'Biomedical Department Head',
          'phone': '+263782345678',
        },
        {
          'id': 'kudakwashe-hove',
          'name': 'Kudakwashe Hove',
          'last_message':
              "The blood gas analyzer in ICU lab is drifting on pH calibration.",
          'last_message_time': DateTime.now()
              .subtract(const Duration(hours: 18))
              .toUtc()
              .toIso8601String(),
          'unread': 0,
          'online': true,
          'role': 'Senior Laboratory Specialist',
          'phone': '+263715678901',
        },
      ];

  // --- LOCAL PERSISTENCE HELPERS ---
  Future<void> _loadLocalSimulatedMessages() async {
    if (_isLocalCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('local_simulated_messages_v3');
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        data.forEach((key, value) {
          _localSimulatedMessages[key] = List<Map<String, dynamic>>.from(
            (value as List).map((x) => Map<String, dynamic>.from(x)),
          );
        });
      }
    } catch (e) {
      debugPrint("Error loading local simulated messages: $e");
    }
    _isLocalCacheLoaded = true;
  }

  Future<void> _saveLocalSimulatedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'local_simulated_messages_v3', jsonEncode(_localSimulatedMessages));
    } catch (e) {
      debugPrint("Error saving local simulated messages: $e");
    }
  }

  Future<void> _loadCommsData() async {
    if (_isCommsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final callLogsStr = prefs.getString('local_call_logs_v2');
      if (callLogsStr != null) {
        _localCallLogs.clear();
        _localCallLogs.addAll(List<Map<String, dynamic>>.from(
            jsonDecode(callLogsStr).map((x) => Map<String, dynamic>.from(x))));
      }

      final meetingsStr = prefs.getString('local_meetings_v2');
      if (meetingsStr != null) {
        _localMeetings.clear();
        _localMeetings.addAll(List<Map<String, dynamic>>.from(
            jsonDecode(meetingsStr).map((x) => Map<String, dynamic>.from(x))));
      }
    } catch (e) {
      debugPrint("Error loading local call logs & meetings: $e");
    }
    _isCommsLoaded = true;
  }

  Future<void> _saveCallLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_call_logs_v2', jsonEncode(_localCallLogs));
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
    if (_localCallLogs.isEmpty) {
      // Seed high-fidelity starting logs dynamically
      _localCallLogs.addAll([
        {
          "name": "Dr. Chipo Moyo",
          "type": "voice",
          "direction": "incoming",
          "time": "Today, 10:45 AM",
          "status": "Low O2 Alarm Fault (12m 4s)",
          "phone": "+263772123456",
          "online": true,
        },
        {
          "name": "Farai Gumbo",
          "type": "video",
          "direction": "outgoing",
          "time": "Yesterday, 15:30",
          "status": "PEEP Valve Calibrated (8m 15s)",
          "phone": "+263773456789",
          "online": true,
        },
        {
          "name": "Tendai Chidi",
          "type": "voice",
          "direction": "missed",
          "time": "Yesterday, 09:15",
          "status": "Manifold Pressure Drop",
          "phone": "+263774567890",
          "online": true,
        },
        {
          "name": "Dr. Sekai Nzenza",
          "type": "voice",
          "direction": "incoming",
          "time": "May 22, 14:15",
          "status": "Clinical Audit Check (5m 12s)",
          "phone": "+263771987654",
          "online": true,
        },
      ]);
      await _saveCallLogs();
    }
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
    if (_localMeetings.isEmpty) {
      // Seed default scheduled meetings dynamically
      _localMeetings.addAll([
        {
          "topic": "Oxygen Plant Pipeline Pressure Failure Consultation",
          "time": "Today, 14:00",
          "host": "Farai Gumbo"
        },
        {
          "topic": "ICU Ventilator Oxygen Cell Failover Audit",
          "time": "Tomorrow, 09:30",
          "host": "Dr. Chipo Moyo"
        },
        {
          "topic": "National Biomedical Compliance Framework Review",
          "time": "May 26, 11:00",
          "host": "Dr. Sekai Nzenza"
        }
      ]);
      await _saveMeetings();
    }
    return _localMeetings;
  }

  Future<void> addMeeting(Map<String, dynamic> meeting) async {
    await _loadCommsData();
    _localMeetings.insert(0, meeting);
    await _saveMeetings();
  }

  String _getInitialSeedMessage(String contactId) {
    switch (contactId) {
      case 'dr-chipo-moyo':
        return "Hello colleague. We have SN-VG70-442 in ICU Bed 2 triggering high pressure alarms. Can you check it immediately? Patient is stable on manual mask for now.";
      case 'farai-gumbo':
        return "Colleague, I just finished calibrating the Evita V500 valve assembly. Let me know if you need to run the diagnostic on the ICU 1 system.";
      case 'tendai-chidi':
        return "Alarm in the oxygen plant manifold. Reserve cylinders are routing, but pressure is borderline. I need eyes on the plant pressure gauge.";
      case 'dr-sekai-nzenza':
        return "BMET Team, please prepare the technical audit report for the ICU ventilator fleet before the clinical safety review this afternoon.";
      case 'rufaro-moyo':
        return "Regarding the spare parts inventory: do we have the turbine replacements restocked on Shelf B2? I am drafting the procurement invoice.";
      case 'kudakwashe-hove':
        return "The blood gas analyzer in ICU lab is drifting on pH calibration. Can you bring the reference buffers for a verification test?";
      default:
        return "Hi, let me know if we have any pending maintenance orders to coordinate today.";
    }
  }

  // --- GET REGISTERED TECHNICIANS ---
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

      if (contacts.isEmpty) return fallbackContacts;
      
      for (final fallback in fallbackContacts) {
        if (!contacts.any((c) => c['id'] == fallback['id'])) {
          contacts.add(fallback);
        }
      }
      return contacts;
    } catch (e) {
      debugPrint("Error fetching contacts from Supabase: $e");
      return fallbackContacts;
    }
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    await _loadLocalSimulatedMessages();
    List<Map<String, dynamic>> list = [];

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
            'phone': '',
          },
        );

        final localMsgs = _localSimulatedMessages[id];
        String lastMsg = row['last_message'] ?? 'Conversation started';
        String lastTime = row['last_message_time'] ?? DateTime.now().toUtc().toIso8601String();
        if (localMsgs != null && localMsgs.isNotEmpty) {
          lastMsg = localMsgs.last['message_text'];
          lastTime = localMsgs.last['timestamp'];
        }

        return {
          'id': id,
          'name': row['group_name'] ?? contact['name'],
          'last_message': lastMsg,
          'last_message_time': lastTime,
          'unread': 0,
          'online': contact['online'] == true || contact['online'] == 1,
          'role': contact['role'] ?? contact['reg_number'] ?? 'Technician',
          'phone': contact['phone'] ?? '',
        };
      }).toList();

      if (conversations.isEmpty) {
        list = fallbackConversations.map((c) {
          final id = c['id'];
          final localMsgs = _localSimulatedMessages[id];
          if (localMsgs != null && localMsgs.isNotEmpty) {
            return {
              ...c,
              'last_message': localMsgs.last['message_text'],
              'last_message_time': localMsgs.last['timestamp'],
            };
          }
          return c;
        }).toList();
      } else {
        list = conversations;
      }
    } catch (e) {
      debugPrint("Error fetching conversations from Supabase: $e");
      list = fallbackConversations.map((c) {
        final id = c['id'];
        final localMsgs = _localSimulatedMessages[id];
        if (localMsgs != null && localMsgs.isNotEmpty) {
          return {
            ...c,
            'last_message': localMsgs.last['message_text'],
            'last_message_time': localMsgs.last['timestamp'],
          };
        }
        return c;
      }).toList();
    }

    // Dynamic Google Chat Space Injection (Path B)!
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
          'name': '💬 Pulse Workspace (Google Chat)',
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
    await _loadLocalSimulatedMessages();

    final isSimulated = fallbackContacts.any((c) => c['id'] == conversationId);
    if (isSimulated) {
      if (!_localSimulatedMessages.containsKey(conversationId) ||
          _localSimulatedMessages[conversationId]!.isEmpty) {
        final now = DateTime.now();
        _localSimulatedMessages[conversationId] = [
          {
            'id': 'seed-1-$conversationId',
            'conversation_id': conversationId,
            'sender_id': conversationId,
            'sender_name': fallbackContacts.firstWhere(
                (c) => c['id'] == conversationId)['name'],
            'message_text': _getInitialSeedMessage(conversationId),
            'message_type': 'text',
            'timestamp': now
                .subtract(const Duration(minutes: 30))
                .toUtc()
                .toIso8601String(),
          },
        ];
        await _saveLocalSimulatedMessages();
      }
      return _localSimulatedMessages[conversationId]!;
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

    await _loadLocalSimulatedMessages();
    final isSimulated = fallbackContacts.any((c) => c['id'] == conversationId);
    if (isSimulated) {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final userMsg = {
        'id': 'user-${DateTime.now().microsecondsSinceEpoch}',
        'conversation_id': conversationId,
        'sender_id': 'local-technician',
        'sender_name': currentUserName ?? 'Technician',
        'message_text': msgText,
        'message_type': 'text',
        'timestamp': timestamp,
        'delivery_state': 'sent',
      };

      if (!_localSimulatedMessages.containsKey(conversationId)) {
        _localSimulatedMessages[conversationId] = [];
      }
      _localSimulatedMessages[conversationId]!.add(userMsg);
      await _saveLocalSimulatedMessages();

      _triggerSimulatedReply(conversationId, msgText);

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

  // --- TRIGGER AI SIMULATED REPLY ---
  void _triggerSimulatedReply(String conversationId, String userMessage) async {
    final contact =
        fallbackContacts.firstWhere((c) => c['id'] == conversationId);
    final contactName = contact['name'];
    final role = contact['role'];

    typingIndicator.value = {
      'conversation_id': conversationId,
      'user_id': conversationId,
    };

    final typingDelay = 1500 + math.Random().nextInt(1500);
    await Future.delayed(Duration(milliseconds: typingDelay));

    final prior = _localSimulatedMessages[conversationId] ?? [];

    final replyText = await GemmaSimulationService.instance.generateReply(
      contactId: conversationId,
      contactName: contactName,
      role: role,
      userMessage: userMessage,
      priorMessages: prior,
    );

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final replyMsg = {
      'id': 'reply-${DateTime.now().microsecondsSinceEpoch}',
      'conversation_id': conversationId,
      'sender_id': conversationId,
      'sender_name': contactName,
      'message_text': replyText,
      'message_type': 'text',
      'timestamp': timestamp,
      'delivery_state': 'sent',
    };

    if (!_localSimulatedMessages.containsKey(conversationId)) {
      _localSimulatedMessages[conversationId] = [];
    }
    _localSimulatedMessages[conversationId]!.add(replyMsg);
    await _saveLocalSimulatedMessages();

    typingIndicator.value = null;
    incomingMessage.value = replyMsg;
  }

  // --- TRIGGER IN-APP AUDIO CALL RESPONSE GENERATION ---
  Future<String> getSimulatedCallReply({
    required String contactId,
    required String userSpeechText,
    required List<Map<String, dynamic>> callHistory,
  }) async {
    final contact = fallbackContacts.firstWhere((c) => c['id'] == contactId);
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
