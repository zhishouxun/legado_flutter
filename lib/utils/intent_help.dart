import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../utils/app_log.dart';

/// Intent 帮助类
/// 参考项目：io.legado.app.help.IntentHelp
///
/// 提供系统功能调用，如打开浏览器、TTS 设置等
class IntentHelp {
  IntentHelp._();

  /// 获取浏览器 Intent（打开 URL）
  /// 参考项目：IntentHelp.getBrowserIntent()
  ///
  /// [url] 要打开的 URL
  /// 返回是否成功打开
  static Future<bool> openBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        AppLog.instance.put('无法打开浏览器: $url');
        return false;
      }
    } catch (e) {
      AppLog.instance.put('打开浏览器失败: $url', error: e);
      return false;
    }
  }

  /// 打开 TTS 设置界面
  /// 参考项目：IntentHelp.openTTSSetting()
  ///
  /// 注意：Flutter 中需要使用平台通道或 url_launcher
  /// Android: 使用自定义 URL scheme 或平台通道
  static Future<bool> openTTSSetting() async {
    try {
      // Android TTS 设置
      // 使用自定义 URL scheme 或平台通道
      // 这里使用通用的设置页面 URL
      final uri = Uri.parse('android.settings.TTS_SETTINGS');
      
      // 尝试使用 url_launcher（可能不支持，需要平台通道）
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      
      // 如果 url_launcher 不支持，记录日志
      AppLog.instance.put('无法打开 TTS 设置页面');
      return false;
    } catch (e) {
      AppLog.instance.put('打开 TTS 设置失败', error: e);
      return false;
    }
  }

  /// 打开未知来源安装设置
  /// 参考项目：IntentHelp.toInstallUnknown()
  ///
  /// [context] BuildContext（用于显示提示）
  /// 注意：Flutter 中需要使用平台通道
  static Future<bool> openInstallUnknownSettings(BuildContext? context) async {
    try {
      // Android 未知来源安装设置
      // 使用自定义 URL scheme 或平台通道
      final uri = Uri.parse('android.settings.MANAGE_UNKNOWN_APP_SOURCES');
      
      // 尝试使用 url_launcher（可能不支持，需要平台通道）
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      
      // 如果 url_launcher 不支持，显示提示
      if (context != null) {
        // 可以显示 SnackBar 提示
        AppLog.instance.put('无法打开未知来源安装设置');
      }
      return false;
    } catch (e) {
      AppLog.instance.put('打开未知来源安装设置失败', error: e);
      return false;
    }
  }
}

