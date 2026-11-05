import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get retroTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.red,
        brightness: Brightness.dark,
      ),
      // User preference: No hover or focus effects
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
        bodyLarge: TextStyle(color: Colors.white),
      ),
      buttonTheme: const ButtonThemeData(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
    );
  }
}
