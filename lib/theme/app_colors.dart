import 'package:flutter/material.dart';

/// Paleta de colores YaYa! Eats
/// Naranja = cliente/marca  |  Azul = rider/delivery
abstract final class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color orange       = Color(0xFFFF6B00); // naranja primario
  static const Color orangeDark   = Color(0xFFE55F00); // hover / pressed
  static const Color orangeLight  = Color(0xFFFFF0E6); // fondos suaves naranja

  // ── Rider / Delivery ──────────────────────────────────────────────────────
  static const Color riderBlue     = Color(0xFF2563EB); // azul rider
  static const Color riderBlueDark = Color(0xFF1E40AF); // pressed
  static const Color riderBlueLight = Color(0xFFEFF4FF); // fondos suaves azul

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color dark         = Color(0xFF1A1A1A);
  static const Color surface      = Color(0xFFF7F7FA);
  static const Color surfaceCard  = Color(0xFFFFFFFF);
  static const Color border       = Color(0xFFEEEEEE);
  static const Color textPrimary  = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint     = Color(0xFFADB5BD);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error        = Color(0xFFDC2626);
  static const Color errorLight   = Color(0xFFFEE2E2);
  static const Color info         = Color(0xFF0EA5E9);
  static const Color infoLight    = Color(0xFFE0F2FE);

  // ── Themes ────────────────────────────────────────────────────────────────
  static ThemeData get clientTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          brightness: Brightness.light,
        ).copyWith(
          primary: orange,
          onPrimary: Colors.white,
          primaryContainer: orangeLight,
          onPrimaryContainer: orangeDark,
          secondary: orangeDark,
          onSecondary: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: surface,
        cardTheme: const CardThemeData(
          color: surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: border),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: orange, width: 1.5),
          ),
        ),
      );

  static ThemeData get riderTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: riderBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: riderBlue,
          onPrimary: Colors.white,
          primaryContainer: riderBlueLight,
          onPrimaryContainer: riderBlueDark,
          secondary: riderBlueDark,
          onSecondary: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: surface,
        cardTheme: const CardThemeData(
          color: surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: border),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: riderBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      );
}
