import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../source/book_source_service.dart';
import '../source/book_source_debug_service.dart';
import '../../utils/app_log.dart';

/// WebSocket调试处理器
class WebSocketDebugHandler {
  static Handler createHandler() {
    return webSocketHandler((WebSocketChannel channel, String? protocol) {
      _handleConnection(channel);
    });
  }

  static void _handleConnection(WebSocketChannel channel) {
    AppLog.instance.put('WebSocket调试连接已建立');

    // 发送ping保持连接
    Timer? pingTimer;
    pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      try {
        channel.sink.add(jsonEncode({'type': 'ping', 'data': 'ping'}));
      } catch (e) {
        timer.cancel();
      }
    });

    // 监听消息
    channel.stream.listen(
      (message) {
        _handleMessage(channel, message);
      },
      onError: (error) {
        AppLog.instance.put('WebSocket调试错误', error: error);
        pingTimer?.cancel();
        try {
          channel.sink.close();
        } catch (_) {
          // 忽略关闭错误
        }
      },
      onDone: () {
        AppLog.instance.put('WebSocket调试连接已关闭');
        pingTimer?.cancel();
      },
      cancelOnError: true,
    );
  }

  static Future<void> _handleMessage(WebSocketChannel channel, dynamic message) async {
    try {
      // 解析消息
      final data = jsonDecode(message.toString()) as Map<String, dynamic>;
      final tag = data['tag'] as String?;
      final key = data['key'] as String?;

      if (tag == null || tag.isEmpty || key == null || key.isEmpty) {
        channel.sink.add('tag和key不能为空');
        channel.sink.close();
        return;
      }

      // 获取书源
      final source = await BookSourceService.instance.getBookSourceByUrl(tag);
      if (source == null) {
        channel.sink.add('未找到书源: $tag');
        channel.sink.close();
        return;
      }

      // 创建调试服务实例
      final debugService = BookSourceDebugService.instance;
      
      // 设置消息回调
      debugService.onMessage = (state, msg) {
        try {
          // 不打印某些状态（参考Android实现）
          if (state == 10 || state == 20 || state == 30 || state == 40) {
            return;
          }

          channel.sink.add(msg);

          // 调试完成或出错时关闭连接
          if (state == -1 || state == 1000) {
            channel.sink.close();
          }
        } catch (e) {
          AppLog.instance.put('发送WebSocket消息失败', error: e);
        }
      };

      // 开始调试
      await debugService.startDebug(source, key);
    } catch (e) {
      AppLog.instance.put('处理WebSocket消息失败', error: e);
      try {
        channel.sink.add('处理消息失败: $e');
        channel.sink.close();
      } catch (_) {
        // 忽略关闭错误
      }
    }
  }
}
