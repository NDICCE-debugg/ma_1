import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ma_1/services/api_client.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  ValueNotifier<Map<String, dynamic>?> currentUser = ValueNotifier(null);
  bool get isLoggedIn => currentUser.value != null;

  AuthService._init();

  Future<bool> checkSession() async {
    final userStr = await _storage.read(key: 'user_data');
    final accessToken = await _storage.read(key: 'access_token');
    
    if (userStr != null && accessToken != null) {
      currentUser.value = jsonDecode(userStr);
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiClient.instance.post('/auth/login', {'email': email, 'password': password});
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        await _saveSession(data);
        return {'success': true};
      }
      return {'success': false, 'message': data['message']};
    } catch (e) {
      print("🚨 LOGIN CRASH: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, String regNumber) async {
    try {
      final response = await ApiClient.instance.post('/auth/register', {
        'name': name, 'email': email, 'password': password, 'reg_number': regNumber
      });
      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print("🚨 REGISTER CRASH: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle([String? newRegNumber]) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return {'success': false, 'message': 'Google sign-in cancelled.'};

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();

      if (idToken == null) return {'success': false, 'message': 'Failed to retrieve secure token.'};

      print("🚨 1. FIREBASE AUTH SUCCESSFUL. SENDING ID TOKEN TO PYTHON SERVER...");

      final response = await ApiClient.instance.post('/auth/google', {
        'id_token': idToken,
        'reg_number': newRegNumber
      });

      print("🚨 2. PYTHON SERVER RESPONDED WITH STATUS: ${response.statusCode}");
      print("🚨 3. PYTHON SERVER RAW BODY: ${response.body}");

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        await _saveSession(data);
        return {'success': true};
      }
      return data; // Might return {"success": false, "message": "reg_number_required"}
    } catch (e) {
      print("🚨 AUTH SERVICE CRASHED COMPLETELY: $e");
      // WE ARE FINALLY RETURNING THE REAL SYSTEM ERROR TO THE UI
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> logout() async {
    await ApiClient.instance.post('/auth/logout', {});
    await _storage.deleteAll();
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    currentUser.value = null;
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    await _storage.write(key: 'access_token', value: data['access_token']);
    await _storage.write(key: 'refresh_token', value: data['refresh_token']);
    await _storage.write(key: 'user_data', value: jsonEncode(data['user']));
    currentUser.value = data['user'];
  }
}