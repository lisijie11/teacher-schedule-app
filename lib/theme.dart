import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── 主色调：靛蓝紫，参考微信/支付宝/MIUI 设计规范 ──
  static const Color primaryDark = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF5B54E8);
  static const Color accentGreen = Color(0xFF07C160);    // 微信绿，上课中
  static const Color accentOrange = Color(0xFFFF8C42);   // 调休/警示
  static const Color accentRed = Color(0xFFFF4757);      // 删除/紧急
  static const Color accentTeal = Color(0xFF00D2C8);     // 完成/休息

  // ── 暗色背景层级（深邃但不死黑，参考 MIUI 暗色） ──
  static const Color darkBg0 = Color(0xFF0C0D18);   // 最深
  static const Color darkBg1 = Color(0xFF12131F);   // Scaffold
  static const Color darkBg2 = Color(0xFF191A2E);   // Surface
  static const Color darkBg3 = Color(0xFF20213A);   // 次级 Surface
  static const Color darkCard = Color(0xFF1C1D32);  // 卡片
  static const Color darkBorder = Color(0xFF2A2C4A); // 边框
  static const Color darkDivider = Color(0xFF1E2040); // 分割线

  // ── 浅色背景层级（柔和米白，参考 iOS + 国产 App） ──
  static const Color lightBg0 = Color(0xFFF5F6FB);   // Scaffold
  static const Color lightBg1 = Color(0xFFEEEFF8);   // 次级背景
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE4E6F2);
  static const Color lightDivider = Color(0xFFECEEF8);

  // 通用颜色定义
  static const Color backgroundColor = darkBg1;
  static const Color cardColor = darkCard;
  static const Color whiteText = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFFB0B2C5);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: primaryDark,
          secondary: accentGreen,
          tertiary: accentOrange,
          surface: darkBg2,
          onPrimary: Colors.white,
          onSurface: const Color(0xFFE8EAFF),
          outline: darkBorder,
          surfaceVariant: darkBg3,
        ),
        scaffoldBackgroundColor: darkBg1,
        cardColor: darkCard,
        dividerColor: darkDivider,
        // 全局字体：思源黑体，中文更好看
        textTheme: GoogleFonts.notoSansTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: const Color(0xFFE4E6FF),
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBg1,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: darkBg1,
          indicatorColor: primaryDark.withOpacity(0.18),
          height: 64,
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(
                  fontSize: 11, color: primaryDark, fontWeight: FontWeight.w600);
            }
            return const TextStyle(fontSize: 11, color: Color(0x61FFFFFF));
          }),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: primaryDark, size: 24);
            }
            return const IconThemeData(color: Color(0x61FFFFFF), size: 22);
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: darkBg3,
          selectedColor: primaryDark.withOpacity(0.25),
          labelStyle: const TextStyle(color: Color(0xFFE4E6FF), fontSize: 13),
          side: BorderSide(color: darkBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkBg3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryDark, width: 1.5),
          ),
          hintStyle: const TextStyle(color: Color(0x4DFFFFFF)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((s) =>
              s.contains(MaterialState.selected) ? Colors.white : const Color(0x61FFFFFF)),
          trackColor: MaterialStateProperty.resolveWith((s) =>
              s.contains(MaterialState.selected)
                  ? primaryDark
                  : darkBg3),
        ),
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: primaryLight,
          secondary: accentGreen,
          tertiary: accentOrange,
          surface: lightCard,
          onPrimary: Colors.white,
          onSurface: const Color(0xFF1A1B2E),
          outline: lightBorder,
          surfaceVariant: lightBg1,
        ),
        scaffoldBackgroundColor: lightBg0,
        cardColor: lightCard,
        dividerColor: lightDivider,
        textTheme: GoogleFonts.notoSansTextTheme(
          ThemeData.light().textTheme,
        ).apply(
          bodyColor: const Color(0xFF1A1B2E),
          displayColor: const Color(0xFF0C0D18),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightBg0,
          foregroundColor: Color(0xFF1A1B2E),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1B2E),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: lightCard,
          indicatorColor: primaryLight.withOpacity(0.12),
          height: 64,
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(
                  fontSize: 11,
                  color: primaryLight,
                  fontWeight: FontWeight.w600);
            }
            return const TextStyle(
                fontSize: 11, color: Color(0x61000000));
          }),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: primaryLight, size: 24);
            }
            return const IconThemeData(color: Color(0x61000000), size: 22);
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: lightBg1,
          selectedColor: primaryLight.withOpacity(0.12),
          labelStyle: const TextStyle(color: Color(0xFF1A1B2E), fontSize: 13),
          side: BorderSide(color: lightBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightBg1,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
          hintStyle: const TextStyle(color: Color(0x42000000)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((s) =>
              s.contains(MaterialState.selected) ? Colors.white : const Color(0xB3FFFFFF)),
          trackColor: MaterialStateProperty.resolveWith((s) =>
              s.contains(MaterialState.selected)
                  ? primaryLight
                  : lightBorder),
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
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
