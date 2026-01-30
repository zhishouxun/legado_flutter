import 'package:flutter/foundation.dart';

/// 应用日志管理
class AppLog {
  static final AppLog instance = AppLog._init();
  AppLog._init();

  final List<LogEntry> _logsList = [];
  static const int maxLogs = 100;
  
  // 用于通知监听器
  final ValueNotifier<void> logsNotifier = ValueNotifier<void>(null);

  List<LogEntry> get logs => List.unmodifiable(_logsList);

  /// 添加日志
  void put(String? message, {Object? error, bool toast = false}) {
    if (message == null || message.isEmpty) return;

    // 限制日志数量
    if (_logsList.length >= maxLogs) {
      _logsList.removeLast();
    }

    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      error: error?.toString(),
      stackTrace: error is Error ? error.stackTrace?.toString() : null,
    );

    _logsList.insert(0, entry);
    logsNotifier.value = null; // 触发通知

    // 在debug模式下打印到控制台（已禁用）
    // if (kDebugMode) {
    //   if (error != null) {
    //     debugPrint('AppLog: $message\n$error');
    //   } else {
    //     debugPrint('AppLog: $message');
    //   }
    // }
  }

  /// 添加调试日志（仅在记录日志时添加）
  void putDebug(String? message, {Object? error}) {
    // 检查是否启用日志记录（可以通过配置控制）
    // 当前默认启用，后续可以添加配置开关
    put(message, error: error);
  }

  /// 清空日志
  void clear() {
    _logsList.clear();
    logsNotifier.value = null; // 触发通知
  }
}

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final String message;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get formattedTime {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  String get fullMessage {
    if (error != null) {
      return '$message\n$error${stackTrace != null ? '\n$stackTrace' : ''}';
    }
    return message;
  }
}
