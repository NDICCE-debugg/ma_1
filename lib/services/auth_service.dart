import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  final _client = Supabase.instance.client;

  AuthService._init();

  Future<bool> checkSession() async => _client.auth.currentSession != null;

  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Authentication failed.'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, String reg) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'reg_number': reg,
        },
      );
      
      if (response.user != null) {
        // Explicitly write profile record into public.users table to ensure immediate indexing
        try {
          await _client.from('users').upsert({
            'id': response.user!.id,
            'name': name,
            'email': email,
            'reg_number': reg,
            'role': 'technician',
            'online': true,
          });
        } catch (_) {
          // Fallback in case a Supabase trigger handles the insert
        }
        return {'success': true};
      }
      return {'success': false, 'message': 'Account creation failed.'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.biomedassist://login-callback',
      );
      return _client.auth.currentUser;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      if (_client.auth.currentUser != null) {
        // Mark user as offline before logging out
        await _client.from('users').update({
          'online': false,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _client.auth.currentUser!.id);
      }
    } catch (_) {}
    await _client.auth.signOut();
  }
}