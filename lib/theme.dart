import 'package:flutter/material.dart';
import 'services/widget_service.dart';

// 小米澎湃OS3 风格配色系统
// 设计原则：简洁、现代、毛玻璃、清晰层级

class AppTheme {
  // ═══════════════════════════════════════════
  // 主色调 - 澎湃OS3 经典蓝
  // ═══════════════════════════════════════════
  static const Color primaryDark = Color(0xFF1D9BF0);    // 澎湃蓝 - 主色
  static const Color primaryLight = Color(0xFF1D9BF0);    // 同色浅色端
  static const Color primarySubtle = Color(0xFFE8F5FD);   // 极淡蓝背景
  
  // 功能色
  static const Color accentBlue = Color(0xFF2196F3);     // 文件导入蓝
  static const Color accentGreen = Color(0xFF00A870);     // 成功绿
  static const Color accentOrange = Color(0xFFFF6D00);    // 警示橙
  static const Color accentRed = Color(0xFFE53935);       // 错误红
  static const Color accentTeal = Color(0xFF00BFA5);     // 完成青
  static const Color accentPurple = Color(0xFF7C4DFF);    // 辅助紫
  
  // ═══════════════════════════════════════════
  // 暗色模式 - 澎湃OS3 深色
  // ═══════════════════════════════════════════
  static const Color darkBg0 = Color(0xFF0D0D0D);         // 最深背景
  static const Color darkBg1 = Color(0xFF1A1A1A);         // 主背景
  static const Color darkBg2 = Color(0xFF242424);         // 卡片/表面
  static const Color darkBg3 = Color(0xFF2E2E2E);         // 次级表面
  static const Color darkCard = Color(0xFF1F1F1F);        // 卡片背景
  static const Color darkBorder = Color(0xFF3A3A3A);       // 边框
  static const Color darkDivider = Color(0xFF2D2D2D);     // 分割线
  
  // 暗色文字
  static const Color darkText = Color(0xFFE6E6E6);        // 主要文字
  static const Color darkTextSecondary = Color(0xFF999999); // 次要文字
  static const Color darkTextHint = Color(0xFF666666);    // 提示文字
  
  // ═══════════════════════════════════════════
  // 浅色模式 - 澎湃OS3 浅色
  // ═══════════════════════════════════════════
  static const Color lightBg0 = Color(0xFFF5F5F5);        // 主背景
  static const Color lightBg1 = Color(0xFFFFFFFF);        // 卡片/表面
  static const Color lightBg2 = Color(0xFFFAFAFA);       // 次级背景
  static const Color lightBg3 = Color(0xFFF0F0F0);        // 更深背景
  static const Color lightCard = Color(0xFFFFFFFF);        // 卡片
  static const Color lightBorder = Color(0xFFEDEDED);      // 边框
  static const Color lightDivider = Color(0xFFF0F0F0);    // 分割线
  
  // 浅色文字
  static const Color lightText = Color(0xFF1A1A1A);        // 主要文字
  static const Color lightTextSecondary = Color(0xFF757575); // 次要文字
  static const Color lightTextHint = Color(0xFFBDBDBD);   // 提示文字
  
  // 兼容性别名
  static const Color backgroundColor = darkBg1;
  static const Color cardColor = darkCard;
  static const Color whiteText = Color(0xFFFFFFFF);
  static const Color lightText1 = Color(0xFFB0B2C5);
  
  // ═══════════════════════════════════════════
  // 澎湃OS3 暗色主题
  // ═══════════════════════════════════════════
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryDark,
      secondary: accentGreen,
      tertiary: accentOrange,
      surface: darkBg2,
      onPrimary: Colors.white,
      onSurface: darkText,
      outline: darkBorder,
      surfaceContainerHighest: darkBg3,
      error: accentRed,
    ),
    scaffoldBackgroundColor: darkBg1,
    cardColor: darkCard,
    dividerColor: darkDivider,
    
    // 文字主题
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: darkText, fontWeight: FontWeight.w700, letterSpacing: -1),
      displayMedium: TextStyle(color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displaySmall: TextStyle(color: darkText, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: darkText, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: darkText, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w500, fontSize: 16),
      titleSmall: TextStyle(color: darkTextSecondary, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge: TextStyle(color: darkText, fontSize: 16),
      bodyMedium: TextStyle(color: darkText, fontSize: 14),
      bodySmall: TextStyle(color: darkTextSecondary, fontSize: 12),
      labelLarge: TextStyle(color: darkText, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: darkTextSecondary, fontSize: 12),
      labelSmall: TextStyle(color: darkTextHint, fontSize: 11),
    ),
    
    // AppBar - 极简风格
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg1,
      foregroundColor: darkText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: darkText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    
    // 底部导航 - 澎湃风格
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkBg1,
      indicatorColor: primaryDark.withOpacity(0.15),
      height: 64,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11, 
            color: primaryDark, 
            fontWeight: FontWeight.w600,
          );
        }
        return const TextStyle(fontSize: 11, color: darkTextHint);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryDark, size: 24);
        }
        return const IconThemeData(color: darkTextHint, size: 24);
      }),
    ),
    
    // 卡片主题
    cardTheme: CardTheme(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: darkBorder.withOpacity(0.5)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    
    // 列表瓦片
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: const TextStyle(color: darkText, fontSize: 16, fontWeight: FontWeight.w500),
      subtitleTextStyle: const TextStyle(color: darkTextSecondary, fontSize: 13),
    ),
    
    // 开关主题
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? Colors.white : darkTextHint),
      trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? primaryDark : darkBg3),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    
    // 输入框主题
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkBg2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: darkBorder.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryDark, width: 1.5),
      ),
      hintStyle: const TextStyle(color: darkTextHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    
    // 按钮主题
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    
    // 对话框主题
    dialogTheme: DialogTheme(
      backgroundColor: darkBg2,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(color: darkText, fontSize: 20, fontWeight: FontWeight.w700),
      contentTextStyle: const TextStyle(color: darkTextSecondary, fontSize: 15),
    ),
    
    // 底部弹窗主题
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: darkBg2,
      modalBackgroundColor: darkBg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    
    // Snackbar 主题
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkBg3,
      contentTextStyle: const TextStyle(color: darkText, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    
    // TabBar 主题
    tabBarTheme: TabBarTheme(
      labelColor: primaryDark,
      unselectedLabelColor: darkTextHint,
      indicatorColor: primaryDark,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    
    // 分隔符
    dividerTheme: DividerThemeData(
      color: darkDivider,
      thickness: 0.5,
      space: 0,
    ),
    
    // 进度条
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryDark,
      linearTrackColor: darkBg3,
    ),
  );

  // ═══════════════════════════════════════════
  // 澎湃OS3 浅色主题
  // ═══════════════════════════════════════════
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryDark,
      secondary: accentGreen,
      tertiary: accentOrange,
      surface: lightBg1,
      onPrimary: Colors.white,
      onSurface: lightText,
      outline: lightBorder,
      surfaceContainerHighest: lightBg2,
      error: accentRed,
    ),
    scaffoldBackgroundColor: lightBg0,
    cardColor: lightCard,
    dividerColor: lightDivider,
    
    // 文字主题
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: lightText, fontWeight: FontWeight.w700, letterSpacing: -1),
      displayMedium: TextStyle(color: lightText, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displaySmall: TextStyle(color: lightText, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: lightText, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: lightText, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: lightText, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: TextStyle(color: lightText, fontWeight: FontWeight.w500, fontSize: 16),
      titleSmall: TextStyle(color: lightTextSecondary, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge: TextStyle(color: lightText, fontSize: 16),
      bodyMedium: TextStyle(color: lightText, fontSize: 14),
      bodySmall: TextStyle(color: lightTextSecondary, fontSize: 12),
      labelLarge: TextStyle(color: lightText, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: lightTextSecondary, fontSize: 12),
      labelSmall: TextStyle(color: lightTextHint, fontSize: 11),
    ),
    
    // AppBar - 极简风格
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBg0,
      foregroundColor: lightText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: lightText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    
    // 底部导航 - 澎湃风格
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightBg1,
      indicatorColor: primaryDark.withOpacity(0.12),
      height: 64,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11, 
            color: primaryDark, 
            fontWeight: FontWeight.w600,
          );
        }
        return const TextStyle(fontSize: 11, color: lightTextHint);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryDark, size: 24);
        }
        return const IconThemeData(color: lightTextHint, size: 24);
      }),
    ),
    
    // 卡片主题
    cardTheme: CardTheme(
      color: lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: lightBorder),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    
    // 列表瓦片
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: const TextStyle(color: lightText, fontSize: 16, fontWeight: FontWeight.w500),
      subtitleTextStyle: const TextStyle(color: lightTextSecondary, fontSize: 13),
    ),
    
    // 开关主题
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? Colors.white : lightTextHint),
      trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? primaryDark : lightBg2),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    
    // 输入框主题
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightBg2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryDark, width: 1.5),
      ),
      hintStyle: const TextStyle(color: lightTextHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    
    // 按钮主题
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    
    // 对话框主题
    dialogTheme: DialogTheme(
      backgroundColor: lightBg1,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(color: lightText, fontSize: 20, fontWeight: FontWeight.w700),
      contentTextStyle: const TextStyle(color: lightTextSecondary, fontSize: 15),
    ),
    
    // 底部弹窗主题
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightBg1,
      modalBackgroundColor: lightBg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    
    // Snackbar 主题
    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightText,
      contentTextStyle: const TextStyle(color: lightBg0, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    
    // TabBar 主题
    tabBarTheme: TabBarTheme(
      labelColor: primaryDark,
      unselectedLabelColor: lightTextHint,
      indicatorColor: primaryDark,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    
    // 分隔符
    dividerTheme: DividerThemeData(
      color: lightDivider,
      thickness: 0.5,
      space: 0,
    ),
    
    // 进度条
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryDark,
      linearTrackColor: lightBg2,
    ),
  );
}

// 主题切换 Provider
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    // 主题切换后触发小组件更新
    _updateWidgetAfterThemeChange();
  }
  
  void toggle() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    // 主题切换后触发小组件更新
    _updateWidgetAfterThemeChange();
  }
  
  void _updateWidgetAfterThemeChange() {
    // 延迟500ms确保主题切换完成后再更新小组件
    Future.delayed(const Duration(milliseconds: 500), () {
      WidgetService.updateWidget();
    });
  }
}
