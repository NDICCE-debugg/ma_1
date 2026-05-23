import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/screens/login_screen.dart';
import 'package:ma_1/screens/home_screen.dart';
import 'package:ma_1/services/background_voice_service.dart';
import 'package:ma_1/services/notification_service.dart';
import 'package:ma_1/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Google Firebase safely (Web requires custom FirebaseOptions which may not be set yet)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization bypassed or failed: $e");
  }
  
  // 2. Initialize system alerts and listeners (Mobile background and notification services only)
  if (!kIsWeb) {
    try {
      await NotificationService.initialize();
      await BackgroundVoiceService.initializeService();
    } catch (e) {
      debugPrint("Mobile services initialization bypassed or failed: $e");
    }
  }
  
  // 3. Verify Local Token Session
  bool isLoggedIn = false;
  try {
    isLoggedIn = await AuthService.instance.checkSession();
  } catch (e) {
    debugPrint("Local token session check failed: $e");
  }
  
  runApp(BiomedApp(isLoggedIn: isLoggedIn));
}

class BiomedApp extends StatelessWidget {
  final bool isLoggedIn;
  const BiomedApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioMed Tech Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      // If valid tokens exist on device, skip login and go to Home
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(), 
    );
  }
}