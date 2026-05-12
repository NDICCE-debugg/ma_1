import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._init();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Set your Flask server IP here
  static const String baseUrl = 'http://10.160.120.215:5000/api'; 

  ApiClient._init();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    var headers = await _getHeaders();
    var response = await http.post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: jsonEncode(body));

    if (response.statusCode == 401) {
      bool refreshed = await _refreshToken();
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
      bool refreshed = await _refreshToken();
      if (refreshed) {
        headers = await _getHeaders();
        response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
      }
    }
    return response;
  }

  Future<bool> _refreshToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Authorization': 'Bearer $refreshToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'access_token', value: data['access_token']);
        return true;
      }
    } catch (e) {
      // Ignore
    }
    return false; // Refresh failed, user needs to log in again
  }
}