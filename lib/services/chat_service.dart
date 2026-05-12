import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;

class ChatService {
  static final ChatService instance = ChatService._init();
  late IO.Socket socket;
  
  static const String _serverIp = "10.160.120.215"; // Your local IP
  final String _apiUrl = "http://$_serverIp:5001/api";

  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<Map<String, dynamic>?> incomingMessage = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> typingIndicator = ValueNotifier(null);

  // --- NEW: CURRENT USER STATE ---
  String? currentUserId;
  String? currentUserName;

  ChatService._init();

  // --- NEW: FETCH REAL TECHNICIANS ---
  Future<List<Map<String, dynamic>>> getContacts() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/users'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
    }
    return [];
  }

  // --- NEW: LOGIN EXISTING TECHNICIAN ---
  Future<bool> loginTechnician(String regNumber) async {
    try {
      final users = await getContacts();
      for (var user in users) {
        if (user['reg_number'] == regNumber) {
          currentUserId = user['id'];
          currentUserName = user['name'];
          return true; // Successfully found and logged in
        }
      }
    } catch (e) {
      debugPrint("Error logging in: $e");
    }
    return false; // User not found
  }

  // --- NEW: REGISTER TECHNICIAN ---
  Future<String?> registerTechnician(String name, String regNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/chat/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name, "reg_number": regNumber}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentUserId = data['user_id'];
        currentUserName = name;
        return currentUserId; // Returns the new UUID
      }
    } catch (e) {
      debugPrint("Error registering: $e");
    }
    return null;
  }

  // --- SOCKET CONNECTIONS ---
  void connect(String currentUserId) {
    socket = IO.io('http://$_serverIp:5001', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      isConnected.value = true;
      socket.emit('user_online', {'user_id': currentUserId});
    });

    socket.onDisconnect((_) => isConnected.value = false);

    socket.on('receive_message', (data) {
      incomingMessage.value = data;
      incomingMessage.notifyListeners(); 
    });

    socket.on('user_typing', (data) {
      typingIndicator.value = data;
      typingIndicator.notifyListeners();
    });
  }

  void joinRoom(String conversationId) {
    socket.emit('join', {'conversation_id': conversationId});
  }

  void sendMessage(Map<String, dynamic> payload) {
    socket.emit('send_message', payload);
  }

  void sendTyping(String conversationId, String userId) {
    socket.emit('typing', {'conversation_id': conversationId, 'user_id': userId});
  }

  void disconnect() {
    socket.disconnect();
  }
}