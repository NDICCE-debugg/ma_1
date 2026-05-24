import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/screens/home_screen.dart';
import 'package:ma_1/screens/registration_screen.dart';
import 'package:ma_1/widgets/pulse_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _checkActiveSession() async {
    // Allow Supabase cache initialization
    await Future.delayed(const Duration(milliseconds: 100));
    if (AuthService.instance.currentUser != null && mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  void _handleLogin() async {
    final email = _email.text.trim().toLowerCase();
    final password = _pass.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showStatusMessage("Please fill in all fields", AppTheme.error);
      return;
    }

    if (!_isValidEmail(email)) {
      _showStatusMessage("Enter a valid email address", AppTheme.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.instance.login(
        email,
        password,
      );

      if (res['success'] == true) {
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showStatusMessage(
            res['message'] ?? "Invalid email or password", AppTheme.error);
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
    final user = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (user != null && mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      _showStatusMessage("Google sign-in was not completed", AppTheme.error);
    }
  }

  void _handlePasswordReset() async {
    final email = _email.text.trim().toLowerCase();
    if (!_isValidEmail(email)) {
      _showStatusMessage(
        "Enter your email address first, then tap reset.",
        AppTheme.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await AuthService.instance.sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showStatusMessage(
      res['message'] ?? "Password reset request finished.",
      res['success'] == true ? AppTheme.success : AppTheme.error,
    );
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

          // 2. Main content area inside reactive scrolling container
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
                      const SizedBox(height: 30),

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
                        "Clinical Equipment Intelligence",
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

                      const SizedBox(height: 32),

                      // 3. Functional and clean login card
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
                              "AUTHORIZED SIGN IN",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                letterSpacing: 1.2,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Email Input Field (54dp height, standard keyboard flags)
                            TextField(
                              controller: _email,
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

                            // Password Input Field (54dp height, standard visibility toggle)
                            TextField(
                              controller: _pass,
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
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    _isLoading ? null : _handlePasswordReset,
                                child: const Text(
                                  "Forgot password?",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Main login trigger (Strict Supabase Auth connection)
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: AppTheme.primary))
                                : SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                      ),
                                      child: const Text("SIGN IN TO TERMINAL",
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

                      const SizedBox(height: 28),

                      // 4. Google Identity Credentials (Bound directly to Supabase Auth)
                      Row(
                        children: [
                          const Expanded(
                              child: Divider(
                                  color: Color(0xFFCBD5E1),
                                  indent: 10,
                                  endIndent: 10)),
                          Text(
                            "SECURE SOCIAL LOGIN",
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

                      // Google Auth Button
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
                          label: const Text("Sign in with Google",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ).animate().fadeIn(delay: 450.ms),

                      const SizedBox(height: 32),

                      // 5. Sign-up prompt for new clinical engineers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "New clinical engineer? ",
                            style: TextStyle(
                                color: Color(0xFF475569),
                                fontFamily: 'Outfit',
                                fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RegistrationScreen()),
                              );
                            },
                            child: const Text(
                              "Register here",
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

