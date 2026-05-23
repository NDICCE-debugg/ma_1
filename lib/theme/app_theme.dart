import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- MEDICAL COLOR PALETTE (From Clinical Blue Palette) ---
  static const Color iceBlue = Color(0xFFC0E6FD);        // Ice Blue Accent (#c0e6fd)
  static const Color softBlue = Color(0xFF80AAD3);       // Soft Steel Blue (#80aad3)
  static const Color steelBlue = Color(0xFF5B86B6);      // Steel Blue Midtone (#5b86b6)
  static const Color classicBlue = Color(0xFF3F6593);    // Classic Midtone (#3f6593)
  static const Color deepNavy = Color(0xFF1B3554);       // Deep Navy (#1b3554)
  static const Color midnightBlue = Color(0xFF000F22);   // Midnight Black-Blue (#000f22)
  
  // --- THEME ASSIGNMENTS ---
  static const primary = deepNavy;      
  static const primaryDark = midnightBlue;  
  static const secondary = classicBlue;    
  static const success = Color(0xFF10B981);      // Clean Emerald green
  static const warning = Color(0xFFF59E0B);      // Vibrant amber
  static const error = Color(0xFFEF4444);        // Vibrant coral red
  static const neutral = softBlue;      
  
  // --- UI SURFACE COLORS ---
  static const background = Color(0xFFF0F4F8);   // Ice-blue tinted white background   
  static const surface = Color(0xFFFFFFFF);      
  static const textPrimary = Color(0xFF0F172A);  // Rich Slate 900
  static const textSecondary = Color(0xFF475569); // Slate 600
  static const border = Color(0xFFCBD5E1);       // Slate 300
  static const divider = Color(0xFFE2E8F0);      // Slate 200

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
    textTheme: GoogleFonts.outfitTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      iconTheme: IconThemeData(color: primary),
      titleTextStyle: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSecondary,
      indicator: UnderlineTabIndicator(borderSide: BorderSide(color: primary, width: 3.5)),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: const BorderSide(color: Color(0xFFCBD5E1))
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: const BorderSide(color: Color(0xFFE2E8F0))
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: const BorderSide(color: primary, width: 1.5)
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: midnightBlue,
    dividerColor: const Color(0xFF1B3554),
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: Color(0xFF0A192F),
      background: midnightBlue,
      error: error,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A192F),
      elevation: 0,
      iconTheme: IconThemeData(color: iceBlue),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF0A192F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: const BorderSide(color: Color(0xFF1B3554), width: 1.5)
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0A192F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: const BorderSide(color: Color(0xFF1B3554))
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: const BorderSide(color: Color(0xFF1B3554))
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), 
        borderSide: const BorderSide(color: iceBlue, width: 1.5)
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: iceBlue,
        foregroundColor: midnightBlue,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
  );
}