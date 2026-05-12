import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/screens/login_screen.dart';
import 'package:ma_1/screens/home_screen.dart';
import 'package:ma_1/services/background_voice_service.dart';
import 'package:ma_1/services/notification_service.dart';
import 'package:ma_1/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Google Firebase
  await Firebase.initializeApp();
  
  // 2. Initialize system alerts and listeners
  await NotificationService.initialize();
  await BackgroundVoiceService.initializeService();
  
  // 3. Verify Local Token Session
  bool isLoggedIn = await AuthService.instance.checkSession();
  
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