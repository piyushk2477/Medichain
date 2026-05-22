import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
class AppColors {
  AppColors._();

  // Brand
  static const Color primary       = Color(0xFF2563EB);
  static const Color primaryDark   = Color(0xFF1D4ED8);
  static const Color primaryLight  = Color(0xFF3B82F6);
  static const Color primaryTint   = Color(0xFFEEF3FF);
  static const Color primarySurface= Color(0xFFF5F8FF);
  static const Color warning = Color(0xFFF59E0B);
  // Accent
  static const Color accentRed     = Color(0xFFEF4444);

  // Text5
  static const Color textPrimary   = Color(0xFF0B1840);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary  = Color(0xFF94A3B8);

  // Surface
  static const Color background    = Color(0xFFFFFFFF);
  static const Color surface       = Color(0xFFF8FAFC);
  static const Color border        = Color(0xFFE5E7EB);
  static const Color borderStrong  = Color(0xFFCBD5E1);

  // Status
  static const Color success       = Color(0xFF16A34A);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.plusJakartaSansTextTheme(const TextTheme(
      displayLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.15, letterSpacing: -0.5),
      displayMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2, letterSpacing: -0.4),
      headlineSmall: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.45),
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 15),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accentRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.accentRed, width: 1.8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
        disabledForegroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}