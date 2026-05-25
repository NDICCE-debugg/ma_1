import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/api_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  bool _isLoading = false;

  void _sendResetLink() async {
    if (_emailCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      // Logic remains the same, connecting to your Flask backend
      await ApiClient.instance.post(
          '/auth/forgot-password', {'email': _emailCtrl.text.trim()},
          authenticated: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AppTheme.primary,
        content: Text("Password reset link sent. Please check your inbox.",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AppTheme.error,
        content: Text("Error: Account not found. Please verify your email.",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, // F4F6F9 Medical Light Grey-Blue
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: const Text("Reset Password"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Clean Clinical Icon
              const Icon(Icons.lock_open_rounded,
                      size: 64, color: AppTheme.primary)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(delay: 200.ms),

              const SizedBox(height: 32),

              // Professional Card Container
              Card(
                elevation: 2,
                shadowColor: Colors.black12,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Forgot Password?",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Enter your registered email address below to receive a secure reset link.",
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 24),

                      // Professional Input Field
                      const Text(
                        "Email Address",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: "e.g., technician@hospital.com",
                          hintStyle:
                              TextStyle(color: AppTheme.neutral, fontSize: 14),
                        ),
                      ),

                      const SizedBox(height: 32),

                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _sendResetLink,
                            child: const Text("Send Reset Link"),
                          ),
                        ),
                    ],
                  ),
                ),
              ).animate().slideY(begin: 0.1, end: 0, curve: Curves.easeOut),

              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Return to Sign In",
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
