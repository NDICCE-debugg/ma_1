import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- MEDICAL COLOR PALETTE ---
  static const primary = Color(0xFF1A6EBD);      // Medical Blue
  static const primaryDark = Color(0xFF1A3C5E);  // Deep Navy
  static const secondary = Color(0xFF0D9488);    // Clinical Teal
  static const background = Color(0xFFF4F6F9);   // Light Grey Blue
  static const surface = Color(0xFFFFFFFF);      // Clean White
  
  static const textPrimary = Color(0xFF1A202C);  // Near Black
  static const textSecondary = Color(0xFF64748B); // Slate Grey
  
  // --- STATUS & NEUTRAL COLORS ---
  static const success = Color(0xFF16A34A);      // Medical Green
  static const warning = Color(0xFFD97706);      // Amber
  static const error = Color(0xFFDC2626);        // Medical Red
  static const neutral = Color(0xFF94A3B8);      // Slate/Grey (FIX: Added this)
  
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFF1F5F9);

  // --- LEGACY SUPPORT ALIASES ---
  static const bgDark = primaryDark;  
  static const textGrey = textSecondary;

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    dividerColor: divider,
    
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    ),
    
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: GoogleFonts.inter(fontSize: 14, color: textPrimary),
      bodyMedium: GoogleFonts.inter(fontSize: 13, color: textSecondary),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      iconTheme: IconThemeData(color: primary, size: 20),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primary, width: 1.5)),
    ),
  );
}