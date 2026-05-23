import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/screens/home_screen.dart';

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

  void _handleRegister() async {
    // Basic clinical validation
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty || _regCtrl.text.isEmpty) {
      _showStatusMessage("Please complete all required fields", AppTheme.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.instance.register(
        _nameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
        _regCtrl.text.trim(),
      );

      if (res['success'] == true) {
        if (!mounted) return;
        _showStatusMessage("Account created successfully", AppTheme.success);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        setState(() => _isLoading = false);
        _showStatusMessage(res['message'] ?? "Registration failed", AppTheme.error);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showStatusMessage("Connection error: Unable to reach server", AppTheme.error);
    }
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
          // 1. High-Fidelity Background Asset
          Image.asset(
            'assets/clinical_bg.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Dark layout mask
          Container(color: AppTheme.midnightBlue.withValues(alpha: 0.4)),
          
          // 2. Scrolling content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // BioAssist Medical Logo Header
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
                        Icons.medical_services_outlined, 
                        size: 55, 
                        color: AppTheme.iceBlue,
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                    
                    const SizedBox(height: 16),
                    
                    const Text(
                      "Deploy Terminal Console", 
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        fontFamily: 'Outfit',
                        letterSpacing: 0.5,
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    
                    const SizedBox(height: 32),
                    
                    // 3. Glassmorphic Card Container
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
                                "SUBMIT TECHNICIAN CREDENTIALS",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.iceBlue,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              _buildInputField("Full Name", _nameCtrl, Icons.person_outline),
                              _buildInputField("Email Address", _emailCtrl, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                              _buildInputField("Technician ID / Reg Number", _regCtrl, Icons.badge_outlined),
                              _buildInputField("Password", _passCtrl, Icons.lock_outline, isObscure: true),
                              
                              const SizedBox(height: 16),
                              
                              _isLoading 
                                ? const Center(child: CircularProgressIndicator(color: AppTheme.iceBlue))
                                : SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.iceBlue,
                                        foregroundColor: AppTheme.midnightBlue,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: const Text("DEPLOY ACCOUNT"),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                    
                    const SizedBox(height: 28),
                    
                    // Already have an account? Prompt
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already authorized? ", 
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontFamily: 'Outfit'),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            "Authenticate Session", 
                            style: TextStyle(
                              color: AppTheme.iceBlue, 
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {bool isObscure = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.softBlue, fontFamily: 'Outfit')),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: isObscure,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Outfit'),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: AppTheme.softBlue),
              hintText: "Enter $label",
              hintStyle: TextStyle(color: AppTheme.softBlue.withValues(alpha: 0.5), fontSize: 13),
              fillColor: AppTheme.midnightBlue.withValues(alpha: 0.3),
              filled: true,
            ),
          ),
        ],
      ),
    );
  }
}