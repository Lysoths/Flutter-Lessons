import 'package:flutter/material.dart';
import 'package:flutter_ders/app/core/firebase/remote_app_config.dart';

/// masterfabric.co renkleri (Tailwind slate/blue paleti + Claude vurgusu).
/// masterfabric-flutter-duo'daki `MfColors` ile aynıdır.
class MfColors {
  /// Slate900 rengi (başlıklar, ana düğme).
  static const slate900 = Color(0xFF0F172A);

  /// Slate800 rengi.
  static const slate800 = Color(0xFF1E293B);

  /// Slate600 rengi (gövde metni).
  static const slate600 = Color(0xFF475569);

  /// Slate500 rengi (ikincil metin).
  static const slate500 = Color(0xFF64748B);

  /// Slate400 rengi.
  static const slate400 = Color(0xFF94A3B8);

  /// Slate200 rengi (kart ve alan kenarlığı).
  static const slate200 = Color(0xFFE2E8F0);

  /// Slate100 rengi.
  static const slate100 = Color(0xFFF1F5F9);

  /// Slate50 rengi.
  static const slate50 = Color(0xFFF8FAFC);

  /// Blue700 rengi.
  static const blue700 = Color(0xFF1D4ED8);

  /// Blue600 rengi (ana vurgu).
  static const blue600 = Color(0xFF2563EB);

  /// Blue100 rengi.
  static const blue100 = Color(0xFFDBEAFE);

  /// Blue50 rengi.
  static const blue50 = Color(0xFFEFF6FF);

  /// Claude rengi.
  static const claude = Color(0xFFD97757);

  /// Hata/silme rengi.
  static const red600 = Color(0xFFDC2626);

  /// Terminal rengi (duo'daki koyu kart zemini).
  static const terminal = Color(0xFF0B0D17);

  /// Emerald500 rengi.
  static const emerald500 = Color(0xFF10B981);
}

/// Uygulamanın Material teması (duo'daki `AppTheme.light` temel alınmıştır).
class AppTheme {
  /// MasterFabric paletiyle açık tema. DERS 18: renkler ve köşeler
  /// Remote Config'teki `tasarim` parametresinden ([DesignTokens]) gelir.
  static ThemeData light([DesignTokens t = const DesignTokens()]) {
    final scheme = ColorScheme.fromSeed(seedColor: t.primary).copyWith(
      primary: t.primary,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: MfColors.slate900,
      onSurfaceVariant: MfColors.slate600,
      outlineVariant: MfColors.slate100,
      secondary: t.accent,
      error: MfColors.red600,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme.apply(
      bodyColor: MfColors.slate900,
      displayColor: MfColors.slate900,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(t.radius),
      borderSide: const BorderSide(color: MfColors.slate200),
    );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          height: 1.08,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: text.labelMedium?.copyWith(
          color: MfColors.slate500,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        bodyLarge: text.bodyLarge?.copyWith(
          color: MfColors.slate600,
          height: 1.5,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          color: MfColors.slate600,
          height: 1.45,
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: MfColors.slate100,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.button,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MfColors.slate900,
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: MfColors.slate200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.button,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cardRadius),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.cardRadius),
          side: const BorderSide(color: MfColors.slate200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MfColors.slate50,
        labelStyle: const TextStyle(color: MfColors.slate500),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: t.primary, width: 1.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        showDragHandle: true,
        dragHandleColor: MfColors.slate200,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MfColors.slate900,
        actionTextColor: MfColors.blue100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: MfColors.slate100),
    );
  }
}
