import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// PAWD design tokens — warm, friendly, mobile-first. Mirrors the web app.
class PawdColors {
  static const brand = Color(0xFFFF6B3D);
  static const brandSoft = Color(0xFFFFE6DC);
  static const accent = Color(0xFF2BB673);
  static const danger = Color(0xFFE2483B);
  static const like = Color(0xFF2BB673);
  static const pass = Color(0xFFE2483B);

  static const bg = Color(0xFFFBF7F2);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF4EEE6);
  static const ink = Color(0xFF241C17);
  static const inkSoft = Color(0xFF6B5D51);
  static const line = Color(0xFFE7DDD0);
}

ThemeData buildPawdTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    // Native feel per OS: iOS/macOS get Cupertino slide + back-swipe,
    // Android keeps the Material transition. (Scroll physics already adapt.)
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    }),
    scaffoldBackgroundColor: PawdColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: PawdColors.brand,
      secondary: PawdColors.accent,
      surface: PawdColors.surface,
      error: PawdColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PawdColors.bg,
      foregroundColor: PawdColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        color: PawdColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'PlusJakartaSans',
      bodyColor: PawdColors.ink,
      displayColor: PawdColors.ink,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'PlusJakartaSans'),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PawdColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PawdColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PawdColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PawdColors.brand, width: 2),
      ),
      labelStyle: const TextStyle(color: PawdColors.inkSoft),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PawdColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PawdColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: PawdColors.line),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
