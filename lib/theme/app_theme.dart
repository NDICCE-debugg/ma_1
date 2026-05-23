import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- MEDICAL COLOR PALETTE ---
  static const primary = Color(0xFF1A6EBD);      
  static const primaryDark = Color(0xFF1A3C5E);  
  static const secondary = Color(0xFF0D9488);    
  static const success = Color(0xFF16A34A);      
  static const warning = Color(0xFFD97706);      
  static const error = Color(0xFFDC2626);        
  static const neutral = Color(0xFF94A3B8);      
  
  // --- UI SURFACE COLORS ---
  static const background = Color(0xFFF4F6F9);   
  static const surface = Color(0xFFFFFFFF);      
  static const textPrimary = Color(0xFF1A202C);  
  static const textSecondary = Color(0xFF64748B); 
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFF1F5F9); // FIX: Added for CollaborationView

  // --- ALIASES (To prevent 'Member not found' in legacy screens) ---
  static const primaryBlue = primary;
  static const neutralSlate = neutral;
  static const textGrey = textSecondary;
  static const bgDark = primaryDark;

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    dividerColor: divider,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      background: background,
      error: error,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      iconTheme: IconThemeData(color: primary),
      titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSecondary,
      indicator: UnderlineTabIndicator(borderSide: BorderSide(color: primary, width: 3)),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), 
        borderSide: const BorderSide(color: border)
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    dividerColor: const Color(0xFF334155),
    colorScheme: const ColorScheme.dark(
      primary: primary,
      surface: Color(0xFF1E293B),
      background: Color(0xFF0F172A),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: const BorderSide(color: Color(0xFF334155))
      ),
    ),
  );
}