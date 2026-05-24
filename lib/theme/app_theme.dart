import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Clinical operations palette, tuned with shadcn-style semantic tokens.
  static const Color iceBlue = Color(0xFFD8F7F2);
  static const Color softBlue = Color(0xFF8DA4AF);
  static const Color steelBlue = Color(0xFF64748B);
  static const Color classicBlue = Color(0xFF0F766E);
  static const Color deepNavy = Color(0xFF111827);
  static const Color midnightBlue = Color(0xFF071013);

  static const primary = deepNavy;
  static const primaryDark = midnightBlue;
  static const secondary = classicBlue;
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFE11D48);
  static const neutral = softBlue;

  static const background = Color(0xFFF7FAF9);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF52616B);
  static const border = Color(0xFFD5DEE3);
  static const divider = Color(0xFFE8EEF1);
  static const muted = Color(0xFFF1F5F4);
  static const mutedForeground = Color(0xFF64747D);
  static const ring = Color(0xFF14B8A6);

  // Legacy aliases used by existing screens.
  static const primaryBlue = primary;
  static const neutralSlate = neutral;
  static const textGrey = textSecondary;
  static const bgDark = primaryDark;

  static OutlinedBorder get _controlShape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(9));

  static TextTheme _textTheme([TextTheme? base]) {
    final textTheme = GoogleFonts.outfitTextTheme(base);
    return textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        color: textPrimary,
        height: 1.35,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,
        dividerColor: divider,
        visualDensity: VisualDensity.standard,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: secondary,
          surface: surface,
          error: error,
          tertiary: Color(0xFF7C3AED),
          outline: border,
          outlineVariant: divider,
          surfaceContainerHighest: muted,
        ),
        textTheme: _textTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: primary),
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: primary,
          unselectedLabelColor: textSecondary,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: divider),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          hoverColor: muted,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: ring, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: error, width: 1.5),
          ),
          labelStyle: const TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: const TextStyle(
            color: mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: muted,
          selectedColor: iceBlue,
          disabledColor: muted,
          side: const BorderSide(color: divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Outfit',
          ),
          secondaryLabelStyle: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Outfit',
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          iconColor: secondary,
          textColor: textPrimary,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          subtitleTextStyle: TextStyle(
            color: textSecondary,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: divider,
          thickness: 1,
          space: 1,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: primary,
            hoverColor: muted,
            highlightColor: iceBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 66,
          backgroundColor: surface,
          indicatorColor: iceBlue,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? primary
                  : textSecondary,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: 11,
              fontFamily: 'Outfit',
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? secondary
                  : textSecondary,
              size: 22,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: secondary,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: _controlShape,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: muted,
            disabledForegroundColor: mutedForeground,
            elevation: 0,
            shape: _controlShape,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
            textStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: border),
            shape: _controlShape,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
            textStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: secondary,
            shape: _controlShape,
            textStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: divider),
          ),
          titleTextStyle: const TextStyle(
            color: textPrimary,
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: primary,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: midnightBlue,
        dividerColor: const Color(0xFF1F2A2E),
        visualDensity: VisualDensity.standard,
        colorScheme: const ColorScheme.dark(
          primary: iceBlue,
          secondary: Color(0xFF2DD4BF),
          surface: Color(0xFF0A1518),
          error: error,
          outline: Color(0xFF24353A),
          outlineVariant: Color(0xFF172428),
          surfaceContainerHighest: Color(0xFF111F23),
        ),
        textTheme: _textTheme(ThemeData.dark().textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1518),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: iceBlue),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF0A1518),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF24353A), width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0A1518),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFF24353A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFF24353A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: iceBlue, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: iceBlue,
            foregroundColor: midnightBlue,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: _controlShape,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: iceBlue,
            foregroundColor: midnightBlue,
            elevation: 0,
            shape: _controlShape,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: iceBlue,
            side: const BorderSide(color: Color(0xFF24353A)),
            shape: _controlShape,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF0A1518),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF24353A)),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF0A1518),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
        ),
      );
}
