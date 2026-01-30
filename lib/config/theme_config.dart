import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_config.dart';

/// 主题模式 Provider
final themeModeProvider = Provider<ThemeMode>((ref) {
  final mode = AppConfig.getString('theme_mode', defaultValue: 'system');
  switch (mode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
});

/// 设置主题模式
void setThemeMode(WidgetRef ref, ThemeMode mode) {
  AppConfig.setString('theme_mode', mode.name);
  // 刷新provider
  ref.invalidate(themeModeProvider);
}

/// 应用主题 Provider
final appThemeProvider = Provider<AppTheme>((ref) {
  return AppTheme();
});

class AppTheme {
  ThemeData get lightTheme {
    // 从配置读取自定义颜色
    final primary =
        Color(AppConfig.getInt('c_primary', defaultValue: 0xFF795548));
    final accent =
        Color(AppConfig.getInt('c_accent', defaultValue: 0xFFD32F2F));
    final background =
        Color(AppConfig.getInt('c_background', defaultValue: 0xFFF5F5F5));
    final bottomBackground =
        Color(AppConfig.getInt('c_b_background', defaultValue: 0xFFEEEEEE));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: background,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: bottomBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomBackground,
      ),
    );
  }

  ThemeData get darkTheme {
    // 从配置读取自定义颜色
    final primary =
        Color(AppConfig.getInt('c_n_primary', defaultValue: 0xFF546E7A));
    final accent =
        Color(AppConfig.getInt('c_n_accent', defaultValue: 0xFFBF360C));
    final background =
        Color(AppConfig.getInt('c_n_background', defaultValue: 0xFF212121));
    final bottomBackground =
        Color(AppConfig.getInt('c_n_b_background', defaultValue: 0xFF303030));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: background,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: bottomBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomBackground,
      ),
    );
  }

  static Future<void> init() async {
    // 初始化主题配置
  }
}
