import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/base/base_service.dart';
import '../../utils/app_log.dart';
import '../../config/app_config.dart';

/// 通知服务
/// 参考项目：Android NotificationManager
class NotificationService extends BaseService {
  static final NotificationService instance = NotificationService._init();
  NotificationService._init();

  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
  bool _initialized = false;

  // 通知渠道ID（参考项目：AppConst.channelId*）
  static const String channelIdDownload = 'download';
  static const String channelIdCache = 'cache';
  static const String channelIdExport = 'export';
  static const String channelIdCheckSource = 'check_source';
  static const String channelIdWebService = 'web_service';
  static const String channelIdReadAloud = 'read_aloud';
  static const String channelIdAudioPlay = 'audio_play';

  @override
  Future<void> onInit() async {
    if (kIsWeb || !Platform.isAndroid) {
      AppLog.instance.putDebug('通知功能仅在Android平台支持');
      return;
    }

    try {
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Android 初始化设置
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 初始化设置（可选）
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      // 初始化设置
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // 初始化插件
      await _flutterLocalNotificationsPlugin!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // 创建通知渠道（Android 8.0+）
      await _createNotificationChannels();

      _initialized = true;
      AppLog.instance.put('通知服务初始化成功');
    } catch (e) {
      AppLog.instance.put('初始化通知服务失败', error: e);
    }
  }

  /// 创建通知渠道
  /// 参考项目：AppConst.channelId*
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin =
        _flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // 下载渠道
    const AndroidNotificationChannel downloadChannel =
        AndroidNotificationChannel(
      channelIdDownload,
      '下载',
      description: '文件下载通知',
      importance: Importance.low,
      showBadge: false,
    );

    // 缓存渠道
    const AndroidNotificationChannel cacheChannel = AndroidNotificationChannel(
      channelIdCache,
      '缓存',
      description: '书籍缓存通知',
      importance: Importance.low,
      showBadge: false,
    );

    // 导出渠道
    const AndroidNotificationChannel exportChannel = AndroidNotificationChannel(
      channelIdExport,
      '导出',
      description: '书籍导出通知',
      importance: Importance.low,
      showBadge: false,
    );

    // 书源校验渠道
    const AndroidNotificationChannel checkSourceChannel =
        AndroidNotificationChannel(
      channelIdCheckSource,
      '书源校验',
      description: '书源校验通知',
      importance: Importance.low,
      showBadge: false,
    );

    // Web服务渠道
    const AndroidNotificationChannel webServiceChannel =
        AndroidNotificationChannel(
      channelIdWebService,
      'Web服务',
      description: 'Web服务通知',
      importance: Importance.low,
      showBadge: false,
    );

    // 朗读渠道
    const AndroidNotificationChannel readAloudChannel =
        AndroidNotificationChannel(
      channelIdReadAloud,
      '朗读',
      description: '朗读服务通知',
      importance: Importance.high,
      showBadge: false,
    );

    // 音频播放渠道
    const AndroidNotificationChannel audioPlayChannel =
        AndroidNotificationChannel(
      channelIdAudioPlay,
      '音频播放',
      description: '音频播放通知',
      importance: Importance.high,
      showBadge: false,
    );

    // 创建所有渠道
    await androidPlugin.createNotificationChannel(downloadChannel);
    await androidPlugin.createNotificationChannel(cacheChannel);
    await androidPlugin.createNotificationChannel(exportChannel);
    await androidPlugin.createNotificationChannel(checkSourceChannel);
    await androidPlugin.createNotificationChannel(webServiceChannel);
    await androidPlugin.createNotificationChannel(readAloudChannel);
    await androidPlugin.createNotificationChannel(audioPlayChannel);
  }

  /// 通知点击回调
  /// 参考项目：NotificationManager.onNotificationTapped()
  void _onNotificationTapped(NotificationResponse response) {
    AppLog.instance.put('通知被点击: ${response.id} - ${response.payload}');

    // 根据通知ID和payload处理点击事件
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      // 解析payload（格式：action:data）
      final parts = payload.split(':');
      if (parts.length >= 2) {
        final action = parts[0];
        final data = parts.sublist(1).join(':');

        switch (action) {
          case 'download':
            // 下载完成，可以打开文件
            // 通过AppConfig设置导航，由LegadoApp处理
            AppConfig.setString('pending_navigation', 'download');
            AppConfig.setString('pending_download_path', data);
            break;

          case 'web_service':
            // Web服务通知，可以打开Web服务页面
            AppConfig.setString('pending_navigation', 'web_service');
            break;

          case 'read_aloud':
            // 朗读通知，可以打开朗读控制页面
            AppConfig.setString('pending_navigation', 'readAloud');
            break;

          case 'audio_play':
            // 音频播放通知，可以打开音频播放页面
            AppConfig.setString('pending_navigation', 'audio_play');
            break;

          default:
            AppLog.instance.put('未知的通知操作: $action');
        }
      }
    } else {
      // 根据通知ID判断操作
      // 通知ID范围：
      // 100-199: 书源校验
      // 103: 缓存服务
      // 104: 导出服务
      // 105: Web服务
      // 106+: 下载服务

      final id = response.id;
      if (id != null) {
        if (id == 105) {
          // Web服务通知
          AppConfig.setString('pending_navigation', 'web_service');
        } else if (id >= 100 && id < 200) {
          // 书源校验通知，可以打开书源管理页面
          AppConfig.setString('pending_navigation', 'book_source');
        }
      }
    }
  }

  /// 显示进度通知
  /// 参考项目：BaseService.startForegroundNotification()
  ///
  /// [id] 通知ID
  /// [title] 通知标题
  /// [content] 通知内容
  /// [progress] 进度（0.0 - 1.0）
  /// [max] 最大值
  /// [current] 当前值
  /// [isOngoing] 是否持续通知（前台服务）
  /// [channelId] 通知渠道ID
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String content,
    double? progress,
    int? max,
    int? current,
    bool isOngoing = false,
    String channelId = channelIdDownload,
  }) async {
    if (!_initialized || _flutterLocalNotificationsPlugin == null) {
      AppLog.instance.putDebug('通知服务未初始化');
      return;
    }

    if (kIsWeb || !Platform.isAndroid) {
      AppLog.instance.putDebug('通知功能仅在Android平台支持');
      return;
    }

    try {
      // Android 通知详情
      final androidDetails = AndroidNotificationDetails(
        channelId,
        title,
        channelDescription: '进度通知',
        importance: isOngoing ? Importance.low : Importance.defaultImportance,
        priority: isOngoing ? Priority.low : Priority.defaultPriority,
        showWhen: false,
        ongoing: isOngoing,
        onlyAlertOnce: true,
        // 进度条
        progress: progress != null && max != null && current != null
            ? (progress * 100).round()
            : (max != null && current != null ? current : 0),
        maxProgress: max ?? 100,
        indeterminate: progress == null && (max == null || current == null),
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _flutterLocalNotificationsPlugin!.show(
        id,
        title,
        content,
        notificationDetails,
      );
    } catch (e) {
      AppLog.instance.put('显示进度通知失败', error: e);
    }
  }

  /// 显示简单通知
  ///
  /// [id] 通知ID
  /// [title] 通知标题
  /// [content] 通知内容
  /// [isOngoing] 是否持续通知（前台服务）
  /// [channelId] 通知渠道ID
  Future<void> showNotification({
    required int id,
    required String title,
    required String content,
    bool isOngoing = false,
    String channelId = channelIdDownload,
    String? payload,
  }) async {
    if (!_initialized || _flutterLocalNotificationsPlugin == null) {
      AppLog.instance.putDebug('通知服务未初始化');
      return;
    }

    if (kIsWeb || !Platform.isAndroid) {
      AppLog.instance.putDebug('通知功能仅在Android平台支持');
      return;
    }

    try {
      // Android 通知详情
      final androidDetails = AndroidNotificationDetails(
        channelId,
        title,
        channelDescription: '通知',
        importance: isOngoing ? Importance.low : Importance.defaultImportance,
        priority: isOngoing ? Priority.low : Priority.defaultPriority,
        showWhen: true,
        ongoing: isOngoing,
        autoCancel: !isOngoing,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _flutterLocalNotificationsPlugin!.show(
        id,
        title,
        content,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      AppLog.instance.put('显示通知失败', error: e);
    }
  }

  /// 取消通知
  ///
  /// [id] 通知ID
  Future<void> cancelNotification(int id) async {
    if (!_initialized || _flutterLocalNotificationsPlugin == null) {
      return;
    }

    try {
      await _flutterLocalNotificationsPlugin!.cancel(id);
    } catch (e) {
      AppLog.instance.put('取消通知失败', error: e);
    }
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    if (!_initialized || _flutterLocalNotificationsPlugin == null) {
      return;
    }

    try {
      await _flutterLocalNotificationsPlugin!.cancelAll();
    } catch (e) {
      AppLog.instance.put('取消所有通知失败', error: e);
    }
  }

  /// 生成新的通知ID
  int generateNotificationId() {
    return DateTime.now().millisecondsSinceEpoch % 1000000;
  }

  /// 检查是否已初始化
  @override
  bool get isInitialized => _initialized;
}
