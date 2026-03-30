import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 主色调 - 深邃蓝紫
  static const Color primaryDark = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF5B54E8);
  static const Color accentColor = Color(0xFFFF6B6B);
  static const Color goldColor = Color(0xFFFFBE0B);

  // 暗色背景层级
  static const Color darkBg0 = Color(0xFF0D0E1A);
  static const Color darkBg1 = Color(0xFF13141F);
  static const Color darkBg2 = Color(0xFF1A1B2E);
  static const Color darkBg3 = Color(0xFF242640);
  static const Color darkCard = Color(0xFF1E1F35);
  static const Color darkBorder = Color(0xFF2E3058);

  // 浅色背景层级
  static const Color lightBg0 = Color(0xFFF8F9FF);
  static const Color lightBg1 = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8EAFF);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primaryDark,
          secondary: accentColor,
          surface: darkBg2,
          background: darkBg1,
          onPrimary: Colors.white,
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: darkBg1,
        cardColor: darkCard,
        dividerColor: darkBorder,
        textTheme: GoogleFonts.notoSansTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBg1,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: darkBg2,
          indicatorColor: primaryDark.withOpacity(0.2),
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: darkBg3,
          selectedColor: primaryDark.withOpacity(0.3),
          labelStyle: const TextStyle(color: Colors.white),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: primaryLight,
          secondary: accentColor,
          surface: lightBg1,
          background: lightBg0,
          onPrimary: Colors.white,
          onSurface: Color(0xFF1A1B2E),
        ),
        scaffoldBackgroundColor: lightBg0,
        cardColor: lightCard,
        dividerColor: lightBorder,
        textTheme: GoogleFonts.notoSansTextTheme(
          ThemeData.light().textTheme,
        ).apply(
          bodyColor: const Color(0xFF1A1B2E),
          displayColor: const Color(0xFF1A1B2E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightBg0,
          foregroundColor: Color(0xFF1A1B2E),
          elevation: 0,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: lightCard,
          indicatorColor: primaryLight.withOpacity(0.15),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
        ),
      );
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggle() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
