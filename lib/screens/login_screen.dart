import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/screens/home_screen.dart';
import 'package:ma_1/screens/forgot_password_screen.dart';
import 'package:ma_1/services/sound_service.dart';
import 'package:ma_1/utils/animation_helper.dart';
import 'package:ma_1/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _regCtrl = TextEditingController();
  
  bool _isLoginMode = true;
  bool _isLoading = false;

  void _showHudAlert(String message, {bool isSuccess = false}) {
    Color color = isSuccess ? AppTheme.accent : AppTheme.error;
    try { isSuccess ? SoundService.instance.playSuccess() : SoundService.instance.playError(); } catch(e) {}
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color.withOpacity(0.9),
      content: GlitchText(message, style: const TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, color: Colors.white)),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _submitEmailAuth() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showHudAlert("ERROR: MISSING CREDENTIALS");
      return;
    }

    setState(() => _isLoading = true);
    try { SoundService.instance.playTransmit(); } catch(e) {}

    if (_isLoginMode) {
      final res = await AuthService.instance.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (res['success']) {
        _bootSequence();
      } else {
        _showHudAlert("ACCESS DENIED: ${res['message']}");
        setState(() => _isLoading = false);
      }
    } else {
      if (_nameCtrl.text.isEmpty || _regCtrl.text.isEmpty) {
        _showHudAlert("ERROR: ALL FIELDS REQUIRED FOR REGISTRATION");
        setState(() => _isLoading = false);
        return;
      }
      final res = await AuthService.instance.register(
        _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text, _regCtrl.text.trim()
      );
      if (res['success']) {
        _showHudAlert(res['message'], isSuccess: true);
        setState(() { _isLoginMode = true; _isLoading = false; }); // Switch back to login
      } else {
        _showHudAlert("REGISTRATION FAILED: ${res['message']}");
        setState(() => _isLoading = false);
      }
    }
  }

  void _authenticateViaGoogle() async {
    setState(() => _isLoading = true);
    try { SoundService.instance.playTransmit(); } catch(e) {}

    try {
      // 1. Send the request
      var res = await AuthService.instance.signInWithGoogle();
      
      // 2. FORCE PRINT THE RAW RESPONSE TO THE TERMINAL
      print("🚨=========================================🚨");
      print("🚨 RAW AUTH RESPONSE: $res");
      print("🚨=========================================🚨");

      if (res['message'] == 'reg_number_required') {
        // First time Google user needs to provide a Registration ID
        setState(() => _isLoading = false);
        _showGoogleRegDialog();
      } else if (res['success']) {
        _bootSequence();
      } else {
        // Force print the specific failure reason
        print("🚨 UPLINK FAILING EXACTLY BECAUSE: ${res['message']}");
        _showHudAlert("UPLINK FAILED: ${res['message']}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // Catch any absolute critical crashes that bypass the AuthService
      print("🚨=========================================🚨");
      print("🚨 HARD CRASH DURING GOOGLE SIGN IN: ${e.toString()}");
      print("🚨=========================================🚨");
      _showHudAlert("CRASH: ${e.toString()}");
      setState(() => _isLoading = false);
    }
  }

  void _showGoogleRegDialog() {
    final regDialogCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgDark,
        shape: const RoundedRectangleBorder(side: BorderSide(color: AppTheme.primary)),
        title: const Text("TECHNICIAN ID REQUIRED", style: TextStyle(color: AppTheme.primary, fontFamily: 'Orbitron')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("To access the Team Hub, please link your hospital registration number.", style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 15),
            _buildInputField("REGISTRATION ID", regDialogCtrl, false),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: AppTheme.textGrey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final res = await AuthService.instance.signInWithGoogle(regDialogCtrl.text.trim());
              if (res['success']) {
                _bootSequence();
              } else {
                _showHudAlert(res['message'] ?? "REGISTRATION FAILED");
                setState(() => _isLoading = false);
              }
            }, 
            child: const Text("LINK ACCOUNT", style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _bootSequence() {
    try { SoundService.instance.playBoot(); } catch(e) {}
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          Container(decoration: AppTheme.cosmicBackground),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.radar, size: 60, color: AppTheme.primary).animate(onPlay: (c) => c.repeat(reverse: true)).scale(end: const Offset(1.2, 1.2)).fade(),
                    const SizedBox(height: 20),
                    Text("BIOMEDICAL COMMLINK", style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary, shadows: [const Shadow(color: AppTheme.primary, blurRadius: 10)])).animate().fadeIn(),
                    const SizedBox(height: 30),
                    
                    HudBrackets(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_isLoginMode ? "SECURE LOGIN" : "NEW OPERATIVE REGISTRATION", style: const TextStyle(color: AppTheme.accent, fontFamily: 'Share Tech Mono', fontSize: 12)),
                              GestureDetector(
                                onTap: () => setState(() => _isLoginMode = !_isLoginMode),
                                child: Text(_isLoginMode ? "[ REGISTER ]" : "[ CANCEL ]", style: const TextStyle(color: AppTheme.primary, fontFamily: 'Share Tech Mono', fontSize: 12)),
                              )
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          if (!_isLoginMode) ...[
                            _buildInputField("OPERATIVE NAME", _nameCtrl, false),
                            const SizedBox(height: 15),
                            _buildInputField("REGISTRATION ID (e.g. OP-104)", _regCtrl, false),
                            const SizedBox(height: 15),
                          ],
                          
                          _buildInputField("EMAIL ADDRESS", _emailCtrl, false),
                          const SizedBox(height: 15),
                          _buildInputField("ENCRYPTION KEY (PASSWORD)", _passCtrl, true),
                          
                          if (_isLoginMode)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                                child: const Text("Forgot Encryption Key?", style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontFamily: 'Share Tech Mono')),
                              ),
                            )
                          else
                            const SizedBox(height: 20),
                          
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                          else ...[
                            GestureDetector(
                              onTap: _submitEmailAuth,
                              child: Container(
                                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), border: Border.all(color: AppTheme.primary)),
                                child: Text(_isLoginMode ? "AUTHENTICATE" : "TRANSMIT REGISTRATION", textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                            ),
                            if (_isLoginMode) ...[
                              const SizedBox(height: 15),
                              GestureDetector(
                                onTap: _authenticateViaGoogle,
                                child: Container(
                                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
                                      SizedBox(width: 5),
                                      Text("AUTHENTICATE VIA GOOGLE", style: TextStyle(color: Colors.white70, fontFamily: 'Share Tech Mono')),
                                    ],
                                  ),
                                ),
                              ),
                            ]
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, bool isObscured) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("> $label", style: const TextStyle(color: AppTheme.textGrey, fontSize: 10, fontFamily: 'Share Tech Mono')),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(border: Border.all(color: Colors.white24), color: AppTheme.bgLight),
          child: TextField(
            controller: controller,
            obscureText: isObscured,
            style: const TextStyle(color: Colors.white, fontFamily: 'Share Tech Mono'),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ),
      ],
    );
  }
}