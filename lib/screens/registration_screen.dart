import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/screens/home_screen.dart';
import 'package:ma_1/widgets/pulse_logo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _regCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.session != null && mounted) {
        await AuthService.instance.syncCurrentUserProfile();
        _goHome();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _regCtrl.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _goHome() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _handleRegister() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text.trim();
    final regNumber = _regCtrl.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        regNumber.isEmpty) {
      _showStatusMessage("Please complete all required fields", AppTheme.error);
      return;
    }

    if (!_isValidEmail(email)) {
      _showStatusMessage("Enter a valid email address", AppTheme.error);
      return;
    }

    if (password.length < 8) {
      _showStatusMessage(
        "Use at least 8 characters for the password",
        AppTheme.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.instance.register(
        name,
        email,
        password,
        regNumber,
      );

      if (res['success'] == true) {
        if (!mounted) return;
        if (res['sessionActive'] == true) {
          _goHome();
        } else {
          setState(() => _isLoading = false);
          _passCtrl.clear();
          _showStatusMessage(
            res['message'] ??
                "Account created. Verify your email before signing in.",
            AppTheme.success,
          );
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showStatusMessage(
            res['message'] ?? "Registration failed", AppTheme.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showStatusMessage(
          "Connection error: Unable to reach auth server", AppTheme.error);
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final res = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (res['pending'] == true) {
      _showStatusMessage(
          res['message'] ?? 'Complete Google sign-in in the browser.',
          AppTheme.primary);
    } else if (res['success'] == true) {
      _goHome();
    } else {
      _showStatusMessage(
          res['message'] ?? "Google registration was not completed",
          AppTheme.error);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  void _showStatusMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(msg,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Sleek clinical holo-gradient background (white to soft ice-blue and light slate)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF), // Clinical white
                  Color(0xFFF1F5F9), // Very soft ice-blue grey
                  Color(0xFFE2E8F0), // Light slate
                  Color(0xFFF8FAFC), // Faint blue white
                ],
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
            ),
          ),

          // 2. Main content area inside reactive scrolling container with LayoutBuilder + ConstrainedBox
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      const PulseLogo(size: 88, borderRadius: 22)
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.easeOutBack),

                      const SizedBox(height: 16),

                      const Text(
                        "Pulse",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                          letterSpacing: -0.5,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideY(begin: 0.2, end: 0),

                      const Text(
                        "Pulse Technician Registration",
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Outfit',
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 28),

                      // 3. Functional and clean registration card
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 24.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "SUBMIT TECHNICIAN CREDENTIALS",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                letterSpacing: 1.2,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Full Name (words capitalized)
                            TextField(
                              controller: _nameCtrl,
                              keyboardType: TextInputType.name,
                              autocorrect: true,
                              enableSuggestions: true,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Outfit',
                                  fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: "Full Name",
                                labelStyle: TextStyle(color: Color(0xFF64748B)),
                                prefixIcon: Icon(Icons.person_outline,
                                    color: Color(0xFF64748B)),
                                fillColor: Color(0xFFF8FAFC),
                                filled: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 16),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Email Address
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Outfit',
                                  fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: "Email Address",
                                labelStyle: TextStyle(color: Color(0xFF64748B)),
                                prefixIcon: Icon(Icons.email_outlined,
                                    color: Color(0xFF64748B)),
                                fillColor: Color(0xFFF8FAFC),
                                filled: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 16),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Technician ID / Reg Number (characters capitalized)
                            TextField(
                              controller: _regCtrl,
                              keyboardType: TextInputType.text,
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Outfit',
                                  fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: "Technician ID / Reg Number",
                                labelStyle: TextStyle(color: Color(0xFF64748B)),
                                prefixIcon: Icon(Icons.badge_outlined,
                                    color: Color(0xFF64748B)),
                                fillColor: Color(0xFFF8FAFC),
                                filled: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 16),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Security Password
                            TextField(
                              controller: _passCtrl,
                              obscureText: !_isPasswordVisible,
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Outfit',
                                  fontSize: 14),
                              decoration: InputDecoration(
                                labelText: "Security Password",
                                labelStyle:
                                    const TextStyle(color: Color(0xFF64748B)),
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: Color(0xFF64748B)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      _isPasswordVisible = !_isPasswordVisible),
                                ),
                                fillColor: const Color(0xFFF8FAFC),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 16),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Submit Action
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: AppTheme.primary))
                                : SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                      ),
                                      child: const Text("DEPLOY ACCOUNT",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                              fontSize: 13)),
                                    ),
                                  ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 24),

                      // 4. Secure Google Signup (Symmetric to Login)
                      Row(
                        children: [
                          const Expanded(
                              child: Divider(
                                  color: Color(0xFFCBD5E1),
                                  indent: 10,
                                  endIndent: 10)),
                          Text(
                            "SECURE SOCIAL REGISTRATION",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B)
                                  .withValues(alpha: 0.7),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Expanded(
                              child: Divider(
                                  color: Color(0xFFCBD5E1),
                                  indent: 10,
                                  endIndent: 10)),
                        ],
                      ).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(
                                color: Color(0xFFCBD5E1), width: 1.5),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.security,
                              size: 18, color: AppTheme.primary),
                          label: const Text("Sign up with Google",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ).animate().fadeIn(delay: 450.ms),

                      const SizedBox(height: 28),

                      // 5. Back to Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already authorized? ",
                            style: TextStyle(
                                color: Color(0xFF475569),
                                fontFamily: 'Outfit',
                                fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Sign in here",
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 500.ms),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
