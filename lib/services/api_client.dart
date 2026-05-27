import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ma_1/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRequiredException implements Exception {
  final String message;
  const AuthRequiredException([
    this.message =
        'Your Pulse session expired. Please sign in again to continue securely.',
  ]);

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient instance = ApiClient._init();
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const String _configuredBaseUrl = String.fromEnvironment(
    'PULSE_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    return 'http://172.16.30.18:5000/api';
  }

  ApiClient._init();

  Future<Map<String, String>> _getHeaders({bool authenticated = true}) async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    if (authenticated && (token == null || token.isEmpty)) {
      await AuthService.instance.clearInvalidSession();
      throw const AuthRequiredException();
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    var headers = await _getHeaders(authenticated: authenticated);
    var response = await _post(endpoint, headers, body);

    if (authenticated && response.statusCode == 401) {
      bool refreshed = await _refreshSession();
      if (refreshed) {
        headers = await _getHeaders(authenticated: authenticated);
        response = await _post(endpoint, headers, body);
      }
      if (response.statusCode == 401) {
        await AuthService.instance.clearInvalidSession();
        throw const AuthRequiredException();
      }
    }
    return response;
  }

  Future<http.Response> get(
    String endpoint, {
    bool authenticated = true,
  }) async {
    var headers = await _getHeaders(authenticated: authenticated);
    var response = await _get(endpoint, headers);

    if (authenticated && response.statusCode == 401) {
      bool refreshed = await _refreshSession();
      if (refreshed) {
        headers = await _getHeaders(authenticated: authenticated);
        response = await _get(endpoint, headers);
      }
      if (response.statusCode == 401) {
        await AuthService.instance.clearInvalidSession();
        throw const AuthRequiredException();
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

  Future<http.Response> _post(
    String endpoint,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) {
    return http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
  }

  Future<http.Response> _get(
    String endpoint,
    Map<String, String> headers,
  ) {
    return http
        .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
        .timeout(_requestTimeout);
  }
}
