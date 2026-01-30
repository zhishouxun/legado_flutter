import 'package:flutter/services.dart';
import 'share_receiver_service.dart';
import '../../utils/app_log.dart';

/// 分享接收平台通道
/// 处理来自Android原生的分享Intent
class ShareReceiverChannel {
  static const MethodChannel _channel = MethodChannel('io.legado.app/share');
  static bool _initialized = false;

  /// 初始化平台通道监听
  static Future<void> init() async {
    if (_initialized) return;
    
    try {
      _channel.setMethodCallHandler(_handleMethodCall);
      _initialized = true;
      AppLog.instance.put('分享接收平台通道已初始化');
    } catch (e) {
      AppLog.instance.put('初始化分享接收平台通道失败: $e', error: e);
    }
  }

  /// 处理方法调用
  static Future<void> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onSharedText':
          final text = call.arguments['text'] as String?;
          if (text != null && text.isNotEmpty) {
            await ShareReceiverService.instance.handleSharedText(text);
          }
          break;
        
        case 'onProcessText':
          final text = call.arguments['text'] as String?;
          if (text != null && text.isNotEmpty) {
            await ShareReceiverService.instance.handleProcessText(text);
          }
          break;
        
        case 'onReadAloud':
          await ShareReceiverService.instance.handleReadAloud();
          break;
        
        default:
          AppLog.instance.put('未知的方法调用: ${call.method}');
      }
    } catch (e) {
      AppLog.instance.put('处理平台通道方法调用失败: ${call.method}', error: e);
    }
  }
}

