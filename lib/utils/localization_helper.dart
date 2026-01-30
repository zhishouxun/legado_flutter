import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'app_log.dart';

/// 本地化辅助工具类
/// 统一管理语言切换和字体缩放
/// 参考项目：AppContextWrapper.kt
class LocalizationHelper {
  static final LocalizationHelper instance = LocalizationHelper._init();
  LocalizationHelper._init();

  /// 支持的语言列表
  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'), // 简体中文
    Locale('zh', 'TW'), // 繁体中文
    Locale('en', ''), // 英文
  ];

  /// 获取当前语言
  /// 从配置中读取，如果没有设置则返回系统语言
  Locale getCurrentLocale() {
    final languageCode = AppConfig.getString('language', defaultValue: '');

    if (languageCode.isEmpty) {
      return _getSystemLocale();
    }

    switch (languageCode) {
      case 'zh':
        return const Locale('zh', 'CN');
      case 'tw':
        return const Locale('zh', 'TW');
      case 'en':
        return const Locale('en', '');
      default:
        return _getSystemLocale();
    }
  }

  /// 设置语言
  Future<void> setLanguage(String languageCode) async {
    try {
      await AppConfig.setString('language', languageCode);
      AppLog.instance.putDebug('语言设置成功: $languageCode');
    } catch (e) {
      AppLog.instance.put('语言设置失败: $languageCode', error: e);
    }
  }

  /// 设置简体中文
  Future<void> setSimplifiedChinese() async {
    await setLanguage('zh');
  }

  /// 设置繁体中文
  Future<void> setTraditionalChinese() async {
    await setLanguage('tw');
  }

  /// 设置英文
  Future<void> setEnglish() async {
    await setLanguage('en');
  }

  /// 获取系统语言
  Locale _getSystemLocale() {
    // Flutter 会自动使用系统语言
    // 这里返回一个默认值，实际使用时由 MaterialApp.locale 控制
    return const Locale('zh', 'CN');
  }

  /// 获取字体缩放比例
  /// 范围：0.8 - 1.6
  double getFontScale() {
    final scale = AppConfig.getInt('font_scale', defaultValue: 10) / 10.0;

    // 限制范围
    if (scale < 0.8 || scale > 1.6) {
      return 1.0;
    }

    return scale;
  }

  /// 设置字体缩放比例
  /// [scale] 范围：0.8 - 1.6
  Future<void> setFontScale(double scale) async {
    // 限制范围
    if (scale < 0.8) scale = 0.8;
    if (scale > 1.6) scale = 1.6;

    try {
      await AppConfig.setInt('font_scale', (scale * 10).round());
      AppLog.instance.putDebug('字体缩放设置成功: $scale');
    } catch (e) {
      AppLog.instance.put('字体缩放设置失败: $scale', error: e);
    }
  }

  /// 获取文本缩放因子（用于 MediaQuery）
  double getTextScaleFactor() {
    return getFontScale();
  }

  /// 创建带字体缩放的 MediaQuery
  MediaQueryData createMediaQueryWithFontScale(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.copyWith(
      textScaler: TextScaler.linear(getTextScaleFactor()),
    );
  }

  /// 检查当前语言是否与设置的语言相同
  bool isSameWithSetting(Locale currentLocale) {
    final settingLocale = getCurrentLocale();
    return currentLocale.languageCode == settingLocale.languageCode &&
        currentLocale.countryCode == settingLocale.countryCode;
  }

  /// 获取语言显示名称
  String getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'zh':
        return '简体中文';
      case 'tw':
        return '繁體中文';
      case 'en':
        return 'English';
      default:
        return '系统默认';
    }
  }

  /// 获取当前语言的显示名称
  String getCurrentLanguageDisplayName() {
    final locale = getCurrentLocale();
    if (locale.languageCode == 'zh') {
      return locale.countryCode == 'TW' ? '繁體中文' : '简体中文';
    } else if (locale.languageCode == 'en') {
      return 'English';
    }
    return '系统默认';
  }
}
