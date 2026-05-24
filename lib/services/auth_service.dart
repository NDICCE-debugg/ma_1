import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  final _client = Supabase.instance.client;
  User? _mockUser;

  AuthService._init();

  Future<bool> checkSession() async =>
      _mockUser != null || _client.auth.currentSession != null;

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
      final normalizedEmail = email.trim().toLowerCase();
      final response = await _client.auth
          .signInWithPassword(
        email: normalizedEmail,
        password: password,
      )
          .timeout(const Duration(seconds: 20));

      if (response.user != null && response.session != null) {
        await _syncUserProfile(response.user!, email: normalizedEmail);
        return {'success': true, 'message': 'Signed in successfully.'};
      }

      return {
        'success': false,
        'message':
            'Sign in could not create a secure session. Please verify your email and try again.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'The auth server took too long to respond. Check your connection and try again.',
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _friendlyAuthMessage(e.message)};
    } catch (e) {
      debugPrint('Email login exception: $e');
      return {
        'success': false,
        'message': 'Unable to sign in right now. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password, String reg) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final response = await _client.auth
          .signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'name': name.trim(),
          'reg_number': reg.trim(),
        },
      )
          .timeout(const Duration(seconds: 20));

      if (response.user != null) {
        await _syncUserProfile(
          response.user!,
          name: name.trim(),
          email: normalizedEmail,
          regNumber: reg.trim(),
          online: response.session != null,
        );

        return {
          'success': true,
          'sessionActive': response.session != null,
          'message': response.session != null
              ? 'Account created and signed in.'
              : 'Account created. Please verify your email before signing in.',
        };
      }

      return {'success': false, 'message': 'Account creation failed.'};
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'The auth server took too long to respond. Check your connection and try again.',
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _friendlyAuthMessage(e.message)};
    } catch (e) {
      debugPrint('Email registration exception: $e');
      return {
        'success': false,
        'message': 'Unable to create the account right now. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> sendPasswordReset(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      await _client.auth
          .resetPasswordForEmail(
            normalizedEmail,
            redirectTo: kIsWeb ? Uri.base.origin : null,
          )
          .timeout(const Duration(seconds: 20));
      return {
        'success': true,
        'message': 'Password reset link sent to $normalizedEmail.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'The auth server took too long to respond. Check your connection and try again.',
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _friendlyAuthMessage(e.message)};
    } catch (e) {
      debugPrint('Password reset exception: $e');
      return {
        'success': false,
        'message': 'Unable to send a reset link right now. Please try again.',
      };
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

  Future<void> _syncUserProfile(
    User user, {
    String? name,
    String? email,
    String? regNumber,
    bool online = true,
  }) async {
    try {
      final metadata = user.userMetadata ?? {};
      await _client.from('users').upsert({
        'id': user.id,
        'name': name ?? metadata['name'] ?? 'Biomedical Technician',
        'email': email ?? user.email,
        'reg_number': regNumber ?? metadata['reg_number'] ?? '',
        'role': metadata['role'] ?? 'technician',
        'online': online,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Supabase user profile sync exception: $e');
    }
  }

  String _friendlyAuthMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (normalized.contains('already registered') ||
        normalized.contains('user already registered')) {
      return 'An account already exists for this email.';
    }
    if (normalized.contains('password')) {
      return message;
    }
    return message.isEmpty ? 'Authentication failed. Please try again.' : message;
  }
}
