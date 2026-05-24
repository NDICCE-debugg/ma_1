import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._init();
  
  // Set your Flask server IP here
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    return 'http://10.160.120.215:5000/api'; 
  }

  ApiClient._init();

  Future<Map<String, String>> _getHeaders() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    var headers = await _getHeaders();
    var response = await http.post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: jsonEncode(body));

    if (response.statusCode == 401) {
      bool refreshed = await _refreshSession();
      if (refreshed) {
        headers = await _getHeaders(); // Get the new token
        response = await http.post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: jsonEncode(body));
      }
    }
    return response;
  }

  Future<http.Response> get(String endpoint) async {
    var headers = await _getHeaders();
    var response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);

    if (response.statusCode == 401) {
      bool refreshed = await _refreshSession();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
      }
    }
    return response;
  }

  Future<bool> _refreshSession() async {
    try {
      final response = await Supabase.instance.client.auth.refreshSession();
      return response.session != null;
    } catch (e) {
      return false;
    }
  }
}
