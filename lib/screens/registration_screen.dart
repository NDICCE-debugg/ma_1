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
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, // F4F6F9 Medical Grey-Blue
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Clinical Branding
              const Icon(Icons.medical_services_outlined, size: 64, color: AppTheme.primary)
                  .animate().fadeIn(duration: 600.ms),
              const SizedBox(height: 16),
              Text("BioAssist", style: Theme.of(context).textTheme.displayLarge),
              Text("Create Technician Account", style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 40),
              
              // Registration Card
              Card(
                elevation: 2,
                shadowColor: Colors.black12,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Account Details", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 24),
                      
                      _buildInputField("Full Name", _nameCtrl, Icons.person_outline),
                      _buildInputField("Email Address", _emailCtrl, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                      _buildInputField("Technician ID / Reg Number", _regCtrl, Icons.badge_outlined),
                      _buildInputField("Password", _passCtrl, Icons.lock_outline, isObscure: true),
                      
                      const SizedBox(height: 24),
                      
                      _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleRegister,
                              child: const Text("Create Account"),
                            ),
                          ),
                    ],
                  ),
                ),
              ).animate().slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? ", style: TextStyle(color: AppTheme.textSecondary)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text("Sign In", 
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {bool isObscure = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: isObscure,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: AppTheme.neutral),
              hintText: "Enter $label",
              hintStyle: const TextStyle(color: AppTheme.neutral, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}