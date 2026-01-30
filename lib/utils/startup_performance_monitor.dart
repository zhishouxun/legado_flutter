import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// 启动性能监控工具
class StartupPerformanceMonitor {
  static final StartupPerformanceMonitor _instance =
      StartupPerformanceMonitor._internal();
  factory StartupPerformanceMonitor() => _instance;
  StartupPerformanceMonitor._internal();

  final Map<String, DateTime> _startTimeStamps = {};
  final Map<String, Duration> _durations = {};

  /// 记录某个阶段的开始时间
  void start(String stage) {
    _startTimeStamps[stage] = DateTime.now();
  }

  /// 记录某个阶段的结束时间并计算持续时间
  void end(String stage) {
    final startTime = _startTimeStamps[stage];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _durations[stage] = duration;

      if (kDebugMode) {
        print('Startup Performance: $stage took ${duration.inMilliseconds}ms');
      }

      // 发送性能指标到开发者工具
      dev.log(
        'Startup Performance: $stage took ${duration.inMilliseconds}ms',
        name: 'startup.performance',
        level: 1000, // info level
      );
    }
  }

  /// 获取指定阶段的持续时间
  Duration? getDuration(String stage) {
    return _durations[stage];
  }

  /// 获取所有阶段的性能数据
  Map<String, Duration> getAllDurations() {
    return Map.from(_durations);
  }

  /// 打印所有性能数据
  void printAllDurations() {
    if (!kDebugMode) return;

    print('\n=== 启动性能报告 ===');
    _durations.forEach((stage, duration) {
      print('$stage: ${duration.inMilliseconds}ms');
    });
    print('==================\n');
  }

  /// 重置所有计时数据
  void reset() {
    _startTimeStamps.clear();
    _durations.clear();
  }
}

/// 便捷访问器
StartupPerformanceMonitor get startupPerformanceMonitor =>
    StartupPerformanceMonitor();
