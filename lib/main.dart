import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:ma_1/utils/supabase_config.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/providers/theme_provider.dart';
import 'package:ma_1/services/auth_service.dart';
import 'package:ma_1/screens/login_screen.dart';
import 'package:ma_1/screens/home_screen.dart';
import 'package:ma_1/utils/web_url_cleaner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    cleanStaleSupabaseCallbackUrl();
  }
  final shouldExchangeAuthCallback =
      kIsWeb && hasSupabaseAuthCallback() && hasSupabasePkceVerifier();

  // Initialize Supabase securely
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: false,
      ),
    );
    if (shouldExchangeAuthCallback) {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(Uri.base);
      } on AuthException catch (e) {
        debugPrint('Supabase auth callback ignored: ${e.message}');
      } finally {
        clearSupabaseCallbackUrl();
      }
    }
  } catch (e) {
    debugPrint("Supabase initialization failed: $e");
  }

  // Validate the cached session before allowing protected screens to load.
  final bool hasSession = await AuthService.instance.checkSession();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(hasSession: hasSession),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool hasSession;
  const MyApp({super.key, required this.hasSession});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pulse',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: hasSession ? const HomeScreen() : const LoginScreen(),
    );
  }
}
