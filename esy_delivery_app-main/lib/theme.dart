import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFFFAFAF7);
  static const ink = Color(0xFF0B0F0D);
  static const cream = Color(0xFFF5F1E8);

  static const brand50 = Color(0xFFEEFDE8);
  static const brand100 = Color(0xFFCEF8BE);
  static const brand200 = Color(0xFF9FF08A);
  static const brand300 = Color(0xFF6AE555);
  static const brand400 = Color(0xFF4ADB38);
  static const brand500 = Color(0xFF33D633);
  static const brand600 = Color(0xFF2BC42B);
  static const brand700 = Color(0xFF22A822);
  static const brand800 = Color(0xFF178417);
  static const brand900 = Color(0xFF0D5C0D);

  static const accent400 = Color(0xFFFB923C);
  static const accent500 = Color(0xFFF97316);

  static const zinc100 = Color(0xFFF4F4F5);
  static const zinc200 = Color(0xFFE4E4E7);
  static const zinc400 = Color(0xFFA1A1AA);
  static const zinc500 = Color(0xFF71717A);
  static const zinc600 = Color(0xFF52525B);
  static const zinc700 = Color(0xFF3F3F46);
  static const zinc800 = Color(0xFF27272A);
  static const zinc900 = Color(0xFF18181B);
}

class AppTypography {
  static TextTheme build(BuildContext context) {
    final base = Theme.of(context).textTheme;
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.bricolageGrotesque(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -1.5,
        color: AppColors.ink,
      ),
      displayMedium: GoogleFonts.bricolageGrotesque(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: -1.0,
        color: AppColors.ink,
      ),
      displaySmall: GoogleFonts.bricolageGrotesque(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -0.5,
        color: AppColors.ink,
      ),
      headlineLarge: GoogleFonts.bricolageGrotesque(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: AppColors.ink,
      ),
      headlineMedium: GoogleFonts.bricolageGrotesque(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineSmall: GoogleFonts.bricolageGrotesque(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleLarge: GoogleFonts.bricolageGrotesque(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        color: AppColors.ink,
        height: 1.45,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.zinc700,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: AppColors.zinc500),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.zinc500,
    letterSpacing: 0.4,
  );
}

ThemeData buildTheme(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.brand600,
      onPrimary: Colors.white,
      secondary: AppColors.accent500,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.zinc100,
    ),
    textTheme: AppTypography.build(context),
    splashFactory: InkSparkle.splashFactory,
    splashColor: AppColors.brand100.withValues(alpha: 0.5),
    highlightColor: Colors.transparent,
  );
}

extension MonoText on String {
  Widget mono({
    double size = 11,
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) => Text(
    toUpperCase(),
    style: AppTypography.mono(size: size, weight: weight, color: color),
  );
}
