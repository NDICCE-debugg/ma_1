import 'package:flutter/material.dart';
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
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(Icons.health_and_safety_outlined, size: 60, color: AppTheme.primary),
                const SizedBox(height: 12),
                const Text("BioAssist", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("Technician Portal", style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
                        const SizedBox(height: 16),
                        TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
                        const SizedBox(height: 24),
                        _isLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleLogin, 
                                child: const Text("Sign In")
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text("OR", style: TextStyle(color: AppTheme.neutral, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: const Icon(Icons.login),
                    label: const Text("Sign in with Google"),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _handleBypass,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange, width: 1.5),
                    ),
                    icon: const Icon(Icons.terminal),
                    label: const Text("SYSTEM OVERRIDE: DEV BYPASS"),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("New technician? ", style: TextStyle(color: AppTheme.textSecondary)),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                        );
                      },
                      child: const Text("Create Account", 
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}