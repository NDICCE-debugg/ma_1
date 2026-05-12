import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bgDark = Color(0xFF050A0E); // Deep black
  static const Color bgLight = Color(0xFF0B141C); // Terminal dark
  static const Color primary = Color(0xFF00F5FF); // Electric cyan
  static const Color accent = Color(0xFF00FF41); // Toxic green
  static const Color warning = Color(0xFFFFB700); // Amber
  static const Color error = Color(0xFFFF003C); // Alert red
  
  // --- RESTORED THESE TO FIX BUILD ERRORS ---
  static const Color success = Color(0xFF00FF41); // Mapped to toxic green
  
  static const Color textWhite = Color(0xFFE0F7FA);
  static const Color textGrey = Color(0xFF546E7A);

  static BoxDecoration get cosmicBackground => const BoxDecoration(
        color: bgDark,
      );

  static BoxDecoration get hudDecoration => BoxDecoration(
        color: bgLight.withOpacity(0.8),
        border: Border.all(color: primary.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      );

  // --- RESTORED THIS TO FIX BUILD ERRORS ---
  static BoxDecoration get glassDecoration => hudDecoration;

  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        primaryColor: primary,
        colorScheme: const ColorScheme.dark(
            primary: primary, 
            secondary: accent, 
            surface: bgLight, 
            error: error),
        textTheme: GoogleFonts.shareTechMonoTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.orbitron(fontWeight: FontWeight.bold, color: primary),
          headlineMedium: GoogleFonts.orbitron(fontWeight: FontWeight.bold, color: textWhite, fontSize: 24),
          titleLarge: GoogleFonts.orbitron(fontWeight: FontWeight.bold, color: primary),
          bodyLarge: const TextStyle(color: textWhite),
          bodyMedium: const TextStyle(color: textGrey),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgDark.withOpacity(0.9),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.orbitron(fontSize: 20, color: primary, letterSpacing: 2),
        ),
      );
}