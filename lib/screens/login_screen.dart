import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/screens/home_screen.dart';
import 'package:ma_1/screens/registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    if (_email.text.trim().isEmpty || _pass.text.trim().isEmpty) {
      _showStatusMessage("Please fill in all fields", AppTheme.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.instance.login(
        _email.text.trim(),
        _pass.text.trim(),
      );

      if (res['success'] == true) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        setState(() => _isLoading = false);
        _showStatusMessage(res['message'] ?? "Invalid email or password", AppTheme.error);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showStatusMessage("Connection error: Unable to reach auth server", AppTheme.error);
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final user = await AuthService.instance.signInWithGoogle();
    setState(() => _isLoading = false);
    if (user != null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  void _handleBypass() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _showStatusMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. High-Fidelity Clinical Blue Background Image
          Image.asset(
            'assets/clinical_bg.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // 2. Translucent dark overlay to ensure high contrast
          Container(color: AppTheme.midnightBlue.withValues(alpha: 0.4)),
          
          // 3. Main UI elements
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // BioAssist Clinical Logo Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.midnightBlue.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.iceBlue.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.iceBlue.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.health_and_safety_outlined, 
                        size: 55, 
                        color: AppTheme.iceBlue,
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 16),
                    
                    const Text(
                      "BioAssist", 
                      style: TextStyle(
                        fontSize: 28, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        fontFamily: 'Outfit',
                        letterSpacing: 0.5,
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                    
                    const Text(
                      "Clinical Maintenance Console", 
                      style: TextStyle(
                        color: AppTheme.softBlue, 
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Outfit',
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                    
                    const SizedBox(height: 32),
                    
                    // 4. Glassmorphic Card Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppTheme.iceBlue.withValues(alpha: 0.2), 
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "AUTHORIZED SIGN IN",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.iceBlue,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 18),
                              
                              // Email Input Field
                              TextField(
                                controller: _email, 
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
                                decoration: InputDecoration(
                                  labelText: "Email Address",
                                  labelStyle: const TextStyle(color: AppTheme.softBlue),
                                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.softBlue),
                                  fillColor: AppTheme.midnightBlue.withValues(alpha: 0.3),
                                  filled: true,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Password Input Field
                              TextField(
                                controller: _pass, 
                                obscureText: true,
                                style: const TextStyle(color: Colors.white, fontFamily: 'Outfit'),
                                decoration: InputDecoration(
                                  labelText: "Security Password",
                                  labelStyle: const TextStyle(color: AppTheme.softBlue),
                                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.softBlue),
                                  fillColor: AppTheme.midnightBlue.withValues(alpha: 0.3),
                                  filled: true,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              _isLoading 
                                ? const Center(child: CircularProgressIndicator(color: AppTheme.iceBlue))
                                : SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _handleLogin, 
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.iceBlue,
                                        foregroundColor: AppTheme.midnightBlue,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: const Text("ACCESS TERMINAL"),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 28),
                    
                    // 5. Native Credentials & Bypass Options
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.white24, indent: 10, endIndent: 10)),
                        Text(
                          "SECURE OAUTH", 
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white.withValues(alpha: 0.4),
                            letterSpacing: 2,
                          ),
                        ),
                        const Expanded(child: Divider(color: Colors.white24, indent: 10, endIndent: 10)),
                      ],
                    ).animate().fadeIn(delay: 400.ms),
                    
                    const SizedBox(height: 20),
                    
                    // Google Auth Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Image.asset(
                          'assets/icon.png', // Temporary fall back or standard google login representation
                          height: 18, 
                          width: 18, 
                          errorBuilder: (_, __, ___) => const Icon(Icons.security, size: 18, color: AppTheme.iceBlue),
                        ),
                        label: const Text("Authenticate via Google Identity", style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ).animate().fadeIn(delay: 450.ms),
                    
                    const SizedBox(height: 12),
                    
                    // Bypass System Override Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _handleBypass,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.iceBlue,
                          side: BorderSide(color: AppTheme.iceBlue.withValues(alpha: 0.4), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.terminal, color: AppTheme.iceBlue, size: 18),
                        label: const Text("Console Override: Bypass Login Hub", style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ).animate().fadeIn(delay: 500.ms),
                    
                    const SizedBox(height: 32),
                    
                    // 6. Sign-up prompt
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "New clinical engineer? ", 
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontFamily: 'Outfit'),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                            );
                          },
                          child: const Text(
                            "Deploy Account", 
                            style: TextStyle(
                              color: AppTheme.iceBlue, 
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 550.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}