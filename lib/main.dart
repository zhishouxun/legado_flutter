import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:ui' show PlatformDispatcher;
import 'dart:io' show HttpException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'config/theme_config.dart';
import 'services/network/network_service.dart';
import 'services/url_scheme_service.dart';
import 'services/receiver/network_changed_listener.dart';
import 'services/receiver/time_battery_listener.dart';
import 'services/receiver/media_button_handler.dart';
import 'services/receiver/share_receiver_channel.dart';
import 'services/receiver/file_receiver_channel.dart';
import 'services/notification_service.dart';
import 'services/crash_log_service.dart';
import 'utils/crash_handler.dart';
import 'utils/app_log.dart';
import 'services/media/audio_play_service.dart';
import 'services/shortcut_service.dart';
import 'services/book_group_service.dart';
import 'services/source/source_config_service.dart';
import 'services/local_config_service.dart';
import 'services/read_config_service.dart';
import 'utils/default_data.dart';
import 'utils/chinese_utils.dart';
import 'utils/startup_performance_monitor.dart';
import 'dart:io' show Platform;

void main() async {
  // 初始化性能监控
  startupPerformanceMonitor.reset();
  startupPerformanceMonitor.start('total_app_startup');

  WidgetsFlutterBinding.ensureInitialized();
  startupPerformanceMonitor.end('widget_binding');

  try {
    startupPerformanceMonitor.start('app_config_init');
    // 第一阶段：关键初始化（必须完成才能启动应用）
    // 初始化配置（必须同步执行，其他服务依赖配置）
    await AppConfig.init();
    await AppTheme.init();
    startupPerformanceMonitor.end('app_config_init');

    // 设置全局错误处理（必须在其他初始化之前）
    _setupErrorHandlers();

    // 第二阶段：关键服务初始化（只初始化最核心的服务）
    startupPerformanceMonitor.start('critical_services_init');

    // 仅初始化绝对必要的服务
    await _initNetworkService(); // 网络服务是核心功能

    // 其他服务移到后台初始化
    _scheduleEarlyBackgroundInitialization();

    startupPerformanceMonitor.end('critical_services_init');

    startupPerformanceMonitor.start('other_services_init');
    // 第三阶段：其他服务延迟到后台初始化
    _scheduleOtherServices();
    startupPerformanceMonitor.end('other_services_init');

    // 非关键服务延迟到后台初始化，不阻塞启动
    _scheduleNonCriticalServices();

    // 第四阶段：平台特定初始化延迟到后台
    if (!kIsWeb) {
      startupPerformanceMonitor.start('platform_specific_init');
      _schedulePlatformSpecificInit();
      startupPerformanceMonitor.end('platform_specific_init');
    }

    // 记录启动完成时间
    startupPerformanceMonitor.end('total_app_startup');

    // 输出性能报告
    AppLog.instance.put(
        '应用初始化完成，总耗时: ${startupPerformanceMonitor.getDuration('total_app_startup')?.inMilliseconds ?? 0}ms');
    startupPerformanceMonitor.printAllDurations();

    // 第五阶段：延迟初始化（在后台执行，不阻塞启动）
    _scheduleBackgroundInitialization();
  } catch (e) {
    // 即使初始化失败也继续运行
    AppLog.instance.put('应用初始化过程中发生未预期的错误', error: e);
  }

  // 设置系统UI样式（Web平台不支持）
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  runApp(
    const ProviderScope(
      child: LegadoApp(),
    ),
  );
}

/// 初始化阅读配置服务
Future<void> _initReadConfigService() async {
  try {
    await ReadConfigService.instance.initConfigs();
  } catch (e) {
    AppLog.instance.put('初始化阅读配置服务失败', error: e);
  }
}

/// 初始化本地配置服务
Future<void> _initLocalConfigService() async {
  try {
    await LocalConfigService.instance.init();
    // 初始化应用版本号（快速操作，不需要等待）
    LocalConfigService.instance.initVersionCode().catchError((e) {
      AppLog.instance.put('初始化应用版本号失败', error: e);
    });
  } catch (e) {
    AppLog.instance.put('初始化本地配置服务失败', error: e);
  }
}

/// 初始化网络服务
Future<void> _initNetworkService() async {
  try {
    await NetworkService.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化网络服务失败', error: e);
  }
}

/// 初始化基础服务
Future<void> _initBaseServices() async {
  // 目前暂时为空，可以添加更多基础服务
}

/// 初始化崩溃日志服务
Future<void> _initCrashLogService() async {
  try {
    await CrashLogService.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化崩溃日志服务失败', error: e);
  }
}

/// 优化版的书籍分组服务初始化
Future<void> _initBookGroupServiceOptimized() async {
  try {
    await BookGroupService.instance.init();
    // 延迟到后台执行默认分组初始化，避免阻塞启动
    Future.microtask(() async {
      try {
        await BookGroupService.instance.initDefaultGroups();
      } catch (e) {
        AppLog.instance.put('初始化默认分组失败', error: e);
      }
    });
  } catch (e) {
    AppLog.instance.put('初始化书籍分组服务失败', error: e);
  }
}

/// 初始化书源配置服务
Future<void> _initSourceConfigService() async {
  try {
    await SourceConfigService.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化书源配置服务失败', error: e);
  }
}

/// 初始化音频播放服务
Future<void> _initAudioPlayService() async {
  try {
    await AudioPlayService.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化音频播放服务失败', error: e);
  }
}

/// 初始化网络变化监听器
Future<void> _initNetworkChangedListener() async {
  try {
    await NetworkChangedListener.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化网络变化监听器失败', error: e);
  }
}

/// 初始化时间和电池监听器
Future<void> _initTimeBatteryListener() async {
  try {
    await TimeBatteryListener.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化时间和电池监听器失败', error: e);
  }
}

/// 初始化媒体按钮处理器
Future<void> _initMediaButtonHandler() async {
  try {
    await MediaButtonHandler.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化媒体按钮处理器失败', error: e);
  }
}

/// 初始化URL Scheme服务
Future<void> _initUrlSchemeService() async {
  try {
    UrlSchemeService.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化URL Scheme服务失败', error: e);
  }
}

/// 初始化分享接收平台通道
Future<void> _initShareReceiverChannel() async {
  try {
    await ShareReceiverChannel.init();
  } catch (e) {
    AppLog.instance.put('初始化分享接收平台通道失败', error: e);
  }
}

/// 初始化文件接收平台通道
Future<void> _initFileReceiverChannel() async {
  try {
    await FileReceiverChannel.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化文件接收平台通道失败', error: e);
  }
}

/// 初始化通知服务
Future<void> _initNotificationService() async {
  try {
    await NotificationService.instance.init();
  } catch (e) {
    AppLog.instance.put('初始化通知服务失败', error: e);
  }
}

/// 初始化快捷方式服务
Future<void> _initShortcutService() async {
  try {
    await ShortcutService.instance.buildShortcuts();
  } catch (e) {
    AppLog.instance.put('初始化快捷方式服务失败', error: e);
  }
}

/// 调度非关键服务初始化（后台执行，不阻塞启动）
void _scheduleNonCriticalServices() {
  // 崩溃日志服务（延迟到后台）
  Future.microtask(() async {
    try {
      await _initCrashLogService();
    } catch (e) {
      AppLog.instance.put('后台初始化崩溃日志服务失败', error: e);
    }
  });

  // 音频播放服务（延迟到后台）
  Future.microtask(() async {
    try {
      await _initAudioPlayService();
    } catch (e) {
      AppLog.instance.put('后台初始化音频播放服务失败', error: e);
    }
  });
}

/// 调度平台特定初始化（后台执行，不阻塞启动）
void _schedulePlatformSpecificInit() {
  if (kIsWeb) return;

  // 网络变化监听器（延迟到后台）
  Future.microtask(() async {
    try {
      await _initNetworkChangedListener();
    } catch (e) {
      AppLog.instance.put('后台初始化网络变化监听器失败', error: e);
    }
  });

  // 时间和电池监听器（延迟到后台）
  Future.microtask(() async {
    try {
      await _initTimeBatteryListener();
    } catch (e) {
      AppLog.instance.put('后台初始化时间和电池监听器失败', error: e);
    }
  });

  // 媒体按钮处理器（延迟到后台）
  Future.microtask(() async {
    try {
      await _initMediaButtonHandler();
    } catch (e) {
      AppLog.instance.put('后台初始化媒体按钮处理器失败', error: e);
    }
  });

  // URL Scheme服务（延迟到后台）
  Future.microtask(() async {
    try {
      _initUrlSchemeService();
    } catch (e) {
      AppLog.instance.put('后台初始化URL Scheme服务失败', error: e);
    }
  });

  // Android 特定初始化（延迟到后台）
  if (Platform.isAndroid) {
    // 分享接收平台通道（延迟到后台）
    Future.microtask(() async {
      try {
        await _initShareReceiverChannel();
      } catch (e) {
        AppLog.instance.put('后台初始化分享接收平台通道失败', error: e);
      }
    });

    // 文件接收平台通道（延迟到后台）
    Future.microtask(() async {
      try {
        await _initFileReceiverChannel();
      } catch (e) {
        AppLog.instance.put('后台初始化文件接收平台通道失败', error: e);
      }
    });

    // 通知服务（延迟到后台）
    Future.microtask(() async {
      try {
        await _initNotificationService();
      } catch (e) {
        AppLog.instance.put('后台初始化通知服务失败', error: e);
      }
    });

    // 快捷方式服务（延迟到后台）
    Future.microtask(() async {
      try {
        await _initShortcutService();
      } catch (e) {
        AppLog.instance.put('后台初始化快捷方式服务失败', error: e);
      }
    });
  }
}

/// 调度早期后台初始化任务
void _scheduleEarlyBackgroundInitialization() {
  // 本地配置服务（延迟到后台初始化，非阻塞）
  Future.microtask(() async {
    try {
      await _initLocalConfigService();
    } catch (e) {
      AppLog.instance.put('后台初始化本地配置服务失败', error: e);
    }
  });

  // 阅读配置服务（延迟到后台初始化，非阻塞）
  Future.microtask(() async {
    try {
      await _initReadConfigService();
    } catch (e) {
      AppLog.instance.put('后台初始化阅读配置服务失败', error: e);
    }
  });

  // 基础服务（延迟到后台初始化，非阻塞）
  Future.microtask(() async {
    try {
      await _initBaseServices();
    } catch (e) {
      AppLog.instance.put('后台初始化基础服务失败', error: e);
    }
  });
}

/// 调度其他服务初始化
void _scheduleOtherServices() {
  // 书籍分组服务（延迟到后台初始化，非阻塞）
  Future.microtask(() async {
    try {
      await _initBookGroupServiceOptimized();
    } catch (e) {
      AppLog.instance.put('后台初始化书籍分组服务失败', error: e);
    }
  });

  // 书源配置服务（延迟到后台初始化，非阻塞）
  Future.microtask(() async {
    try {
      await _initSourceConfigService();
    } catch (e) {
      AppLog.instance.put('后台初始化书源配置服务失败', error: e);
    }
  });
}

/// 调度后台初始化任务
void _scheduleBackgroundInitialization() {
  // 版本升级检查（可能涉及大量数据库操作，延迟执行）
  Future.microtask(() async {
    try {
      await DefaultData.instance.upVersion();
    } catch (e) {
      AppLog.instance.put('版本升级检查失败', error: e);
    }
  });

  // 简繁转换工具预加载（延迟执行，按需加载）
  Future.microtask(() async {
    try {
      await ChineseUtils.preLoad();
    } catch (e) {
      AppLog.instance.put('初始化简繁转换工具失败', error: e);
    }
  });
}

/// 设置全局错误处理
void _setupErrorHandlers() {
  // 捕获Flutter框架错误
  FlutterError.onError = (FlutterErrorDetails details) {
    // 过滤掉图片加载的 404 错误，不显示在控制台
    final exception = details.exception;
    if (exception is HttpException &&
        exception.message.contains('Invalid statusCode: 404') &&
        (exception.uri?.path.contains('.jpg') == true ||
            exception.uri?.path.contains('.png') == true ||
            exception.uri?.path.contains('.jpeg') == true ||
            exception.uri?.path.contains('.webp') == true)) {
      // 静默处理图片加载失败的错误
      return;
    }

    // 检查是否应该吸收异常
    if (CrashHandler.shouldAbsorb(exception)) {
      AppLog.instance
          .put('发生未捕获的异常\n${exception.toString()}', error: exception);
      return;
    }

    FlutterError.presentError(details);

    // 使用增强的 CrashHandler 处理异常
    CrashHandler.handleException(exception, details.stack);

    // 保存崩溃日志（兼容性）
    CrashLogService.instance.saveCrashLog(
      error: details.exceptionAsString(),
      stackTrace: details.stack?.toString() ?? '无堆栈信息',
      details: details.context?.toString(),
    );
  };

  // 捕获异步错误（非Flutter框架错误）
  PlatformDispatcher.instance.onError = (error, stack) {
    // 过滤掉图片加载的 404 错误
    if (error is HttpException &&
        error.message.contains('Invalid statusCode: 404') &&
        (error.uri?.path.contains('.jpg') == true ||
            error.uri?.path.contains('.png') == true ||
            error.uri?.path.contains('.jpeg') == true ||
            error.uri?.path.contains('.webp') == true)) {
      // 静默处理图片加载失败的错误
      return true;
    }

    // 检查是否应该吸收异常
    if (CrashHandler.shouldAbsorb(error)) {
      AppLog.instance.put('发生未捕获的异常\n${error.toString()}', error: error);
      return true;
    }

    // 使用增强的 CrashHandler 处理异常
    CrashHandler.handleException(error, stack);

    // 保存崩溃日志（兼容性）
    CrashLogService.instance.saveCrashLog(
      error: error.toString(),
      stackTrace: stack.toString(),
    );

    return true; // 表示错误已处理
  };
}
