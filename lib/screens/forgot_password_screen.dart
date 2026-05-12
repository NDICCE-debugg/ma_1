import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/utils/animation_helper.dart';
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
      // Direct call to Flask endpoint
      await ApiClient.instance.post('/auth/forgot-password', {'email': _emailCtrl.text.trim()});
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AppTheme.accent,
        content: Text("RESET LINK TRANSMITTED. CHECK INBOX.", style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, color: Colors.black)),
      ));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AppTheme.error,
        content: GlitchText("UPLINK FAILED. ACCOUNT NOT FOUND.", style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, color: Colors.white)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.primary), onPressed: () => Navigator.pop(context)),
        title: const Text("KEY RECOVERY", style: TextStyle(color: AppTheme.primary)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset, size: 80, color: AppTheme.warning).animate().fade().scale(),
              const SizedBox(height: 30),
              HudBrackets(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("INPUT REGISTERED EMAIL ADDRESS", style: TextStyle(color: AppTheme.warning, fontFamily: 'Share Tech Mono', fontSize: 12)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.white24), color: AppTheme.bgLight),
                      child: TextField(
                        controller: _emailCtrl,
                        style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: "> operative@hospital.com", hintStyle: TextStyle(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: AppTheme.warning))
                    else
                      GestureDetector(
                        onTap: _sendResetLink,
                        child: Container(
                          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.2), border: Border.all(color: AppTheme.warning)),
                          child: const Text("TRANSMIT RESET LINK", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}