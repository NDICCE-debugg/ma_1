import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  final _client = Supabase.instance.client;
  User? _mockUser;

  AuthService._init();

  Future<bool> checkSession() async => _mockUser != null || _client.auth.currentSession != null;

  User? get currentUser => _mockUser ?? _client.auth.currentUser;

  void enableBypassMode() {
    _mockUser = User(
      id: 'mock-technician-id-12345',
      appMetadata: const {},
      userMetadata: const {
        'name': 'Tadiwanashe M.',
        'reg_number': 'REG: 2026-HIT-04',
      },
      aud: 'authenticated',
      email: 'technician@hararehospital.gov.zw',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

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

  Future<Map<String, dynamic>> register(
      String name, String email, String password, String reg) async {
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
        } catch (e) {
          debugPrint("Supabase User Profile Sync Exception: $e");
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
      if (kIsWeb) {
        // On Web, use standard Supabase OAuth redirect. This is extremely robust, 
        // official, and avoids the Google identity services 'idToken' deprecation trap.
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        return _client.auth.currentUser;
      }

      // 🔑 CONFIGURE YOUR WEB/SERVER CLIENT ID HERE (Native Platforms):
      const String webClientId =
          '287297883810-9ke9cqk0oena9s7ol062in2eijrjfco4.apps.googleusercontent.com';

      // 1. Trigger the native system sign-in popup
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId: webClientId,
        serverClientId: webClientId,
      ).signIn();

      if (googleUser == null) return null;

      // 2. Fetch the Google authentication credentials
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw 'No Google ID Token was retrieved.';
      }

      // 3. Exchange the Google token directly for a Supabase session
      final AuthResponse response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // 4. Synchronize details into the users profile index
      if (response.user != null) {
        try {
          await _client.from('users').upsert({
            'id': response.user!.id,
            'name': googleUser.displayName ?? 'Google User',
            'email': googleUser.email,
            'reg_number':
                'GOOG-${response.user!.id.substring(0, 5).toUpperCase()}',
            'role': 'technician',
            'online': true,
          });
        } catch (_) {}
      }

      return response.user;
    } catch (e) {
      debugPrint("Supabase Google Auth Exception: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    _mockUser = null;
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
