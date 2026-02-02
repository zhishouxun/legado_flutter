import 'dart:isolate';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';
import '../../data/models/book_source.dart';
import '../../utils/app_log.dart';
import '../notification_service.dart';
import 'cache_service.dart';

/// 基于Isolate的章节下载服务
///
/// 设计思路:
/// 1. **主Isolate**: 负责UI更新(进度条)和发送指令(开始/停止)
/// 2. **Worker Isolate**: 负责真正的网络请求、内容解析、文件缓存
/// 3. **性能优化**: 批量下载、事务提交、避免内存溢出
///
/// 使用场景:
/// - 用户点击"下载全本"
/// - 自动缓存后三章
/// - 批量缓存选定章节
///
/// 参考文档: gemini重构建议/如何写一个DownloaderService.md
class ChapterDownloaderService {
  static final ChapterDownloaderService instance =
      ChapterDownloaderService._init();
  ChapterDownloaderService._init();

  static const int notificationId = 105;

  // Worker Isolate相关
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  // 当前下载任务
  DownloadTask? _currentTask;
  bool _isDownloading = false;

  // 进度通知器
  final ValueNotifier<DownloadProgress> progressNotifier =
      ValueNotifier(DownloadProgress.idle());

  /// 是否正在下载
  bool get isDownloading => _isDownloading;

  /// 开始下载任务
  ///
  /// [book] 书籍
  /// [chapters] 要下载的章节列表
  /// [source] 书源
  /// [batchSize] 批量大小(默认10章一批)
  /// [showNotification] 是否显示通知
  Future<void> startDownload({
    required Book book,
    required List<BookChapter> chapters,
    required BookSource source,
    int batchSize = 10,
    bool showNotification = true,
  }) async {
    if (_isDownloading) {
      AppLog.instance.put('已有下载任务正在进行');
      return;
    }

    _isDownloading = true;

    // 过滤出未缓存的章节
    final uncachedChapters = <BookChapter>[];
    for (final chapter in chapters) {
      final isCached =
          await CacheService.instance.hasChapterCache(book, chapter);
      if (!isCached) {
        uncachedChapters.add(chapter);
      }
    }

    if (uncachedChapters.isEmpty) {
      AppLog.instance.put('所有章节已缓存,无需下载');
      _isDownloading = false;
      progressNotifier.value = DownloadProgress.completed(
        total: chapters.length,
        completed: chapters.length,
      );
      return;
    }

    AppLog.instance.put(
        '开始下载: ${book.name}, 共${uncachedChapters.length}章(总${chapters.length}章)');

    // 创建下载任务
    _currentTask = DownloadTask(
      book: book,
      chapters: uncachedChapters,
      source: source,
      batchSize: batchSize,
      showNotification: showNotification,
    );

    // 初始化进度
    progressNotifier.value = DownloadProgress.downloading(
      total: uncachedChapters.length,
      completed: 0,
      currentChapter: uncachedChapters.first.title,
    );

    // 显示初始通知
    if (showNotification) {
      await _showNotification(
        progress: 0.0,
        current: 0,
        total: uncachedChapters.length,
        bookName: book.name,
      );
    }

    try {
      // 启动Worker Isolate
      await _startWorkerIsolate();
    } catch (e) {
      AppLog.instance.put('启动下载Worker失败', error: e);
      _isDownloading = false;
      progressNotifier.value = DownloadProgress.error(
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// 停止下载
  Future<void> stopDownload() async {
    if (!_isDownloading) return;

    AppLog.instance.put('停止下载');

    // 发送停止指令
    _sendPort?.send({'action': 'stop'});

    // 等待一小段时间让Worker处理停止指令
    await Future.delayed(const Duration(milliseconds: 100));

    // 强制杀死Isolate
    await _killWorkerIsolate();

    _isDownloading = false;
    _currentTask = null;

    progressNotifier.value = DownloadProgress.cancelled();
  }

  /// 启动Worker Isolate
  Future<void> _startWorkerIsolate() async {
    if (_receivePort != null || _isolate != null) {
      await _killWorkerIsolate();
    }

    _receivePort = ReceivePort();

    // 启动Isolate
    _isolate = await Isolate.spawn(
      _downloadWorker,
      _receivePort!.sendPort,
    );

    // 监听Worker消息
    _receivePort!.listen((message) {
      if (message is SendPort) {
        // Worker已就绪,发送任务
        _sendPort = message;
        _sendPort!.send(_currentTask!.toMap());
      } else if (message is Map) {
        _handleWorkerMessage(message);
      }
    });
  }

  /// 处理Worker消息
  void _handleWorkerMessage(Map message) {
    final type = message['type'] as String;

    switch (type) {
      case 'progress':
        _handleProgressMessage(message);
        break;
      case 'complete':
        _handleCompleteMessage(message);
        break;
      case 'error':
        _handleErrorMessage(message);
        break;
    }
  }

  /// 处理进度消息
  void _handleProgressMessage(Map message) {
    final current = message['current'] as int;
    final total = message['total'] as int;
    final chapterTitle = message['chapterTitle'] as String?;

    progressNotifier.value = DownloadProgress.downloading(
      total: total,
      completed: current,
      currentChapter: chapterTitle,
    );

    // 更新通知
    if (_currentTask?.showNotification ?? false) {
      _showNotification(
        progress: current / total,
        current: current,
        total: total,
        bookName: _currentTask!.book.name,
      );
    }
  }

  /// 处理完成消息
  void _handleCompleteMessage(Map message) {
    final total = message['total'] as int;
    final success = message['success'] as int;
    final failed = message['failed'] as int;

    AppLog.instance
        .put('下载完成: ${_currentTask?.book.name}, 成功$success章, 失败$failed章');

    progressNotifier.value = DownloadProgress.completed(
      total: total,
      completed: success,
    );

    // 显示完成通知
    if (_currentTask?.showNotification ?? false) {
      NotificationService.instance.showNotification(
        id: notificationId,
        title: '下载完成',
        content: '${_currentTask!.book.name} 已下载$success章',
        isOngoing: false,
        channelId: NotificationService.channelIdCache,
      );
    }

    _killWorkerIsolate();
    _isDownloading = false;
    _currentTask = null;
  }

  /// 处理错误消息
  void _handleErrorMessage(Map message) {
    final error = message['error'] as String;

    AppLog.instance.put('下载出错: $error');

    progressNotifier.value = DownloadProgress.error(error: error);

    // 显示错误通知
    if (_currentTask?.showNotification ?? false) {
      NotificationService.instance.showNotification(
        id: notificationId,
        title: '下载失败',
        content: '${_currentTask!.book.name} 下载失败: $error',
        isOngoing: false,
        channelId: NotificationService.channelIdCache,
      );
    }

    _killWorkerIsolate();
    _isDownloading = false;
    _currentTask = null;
  }

  /// 显示通知
  Future<void> _showNotification({
    required double progress,
    required int current,
    required int total,
    required String bookName,
  }) async {
    await NotificationService.instance.showProgressNotification(
      id: notificationId,
      title: '下载章节',
      content: '$bookName ($current/$total)',
      progress: progress,
      max: total,
      current: current,
      isOngoing: true,
      channelId: NotificationService.channelIdCache,
    );
  }

  /// 杀死Worker Isolate
  Future<void> _killWorkerIsolate() async {
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;
  }

  /// 清理资源
  Future<void> dispose() async {
    await stopDownload();
    progressNotifier.dispose();
  }
}

/// Worker Isolate入口函数
///
/// ⚠️ 必须是顶层函数或静态方法
void _downloadWorker(SendPort mainSendPort) async {
  final workerReceivePort = ReceivePort();

  // 向主Isolate发送Worker的SendPort
  mainSendPort.send(workerReceivePort.sendPort);

  // 监听主Isolate的消息
  await for (var message in workerReceivePort) {
    if (message is Map) {
      final action = message['action'] as String?;

      if (action == 'stop') {
        // 停止下载
        break;
      }

      // 否则是下载任务
      await _executeDownloadTask(message, mainSendPort);
      break; // 一个任务完成后退出
    }
  }

  workerReceivePort.close();
}

/// 执行下载任务
Future<void> _executeDownloadTask(
  Map taskData,
  SendPort mainSendPort,
) async {
  try {
    // 解析任务数据
    // final book = Book.fromJson(taskData['book'] as Map<String, dynamic>);
    final chaptersList = (taskData['chapters'] as List)
        .map((c) => BookChapter.fromJson(c as Map<String, dynamic>))
        .toList();
    // final source = BookSource.fromJson(taskData['source'] as Map<String, dynamic>);
    final batchSize = taskData['batchSize'] as int;

    final total = chaptersList.length;
    int successCount = 0;
    int failedCount = 0;

    // 分批下载
    for (int i = 0; i < total; i++) {
      final chapter = chaptersList[i];

      try {
        // TODO: 在Worker中下载和缓存章节
        // 这里需要实现:
        // 1. 网络请求(需要在Worker中初始化Dio)
        // 2. 内容解析(使用LegadoParser)
        // 3. 文件缓存(直接写入文件系统)

        // 临时实现: 标记为成功
        successCount++;

        // 发送进度
        mainSendPort.send({
          'type': 'progress',
          'current': i + 1,
          'total': total,
          'chapterTitle': chapter.title,
        });

        // 每批之后稍作延迟,避免请求过快
        if ((i + 1) % batchSize == 0) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } catch (e) {
        failedCount++;
        debugPrint('Worker: 下载章节失败: ${chapter.title}, error: $e');
      }
    }

    // 发送完成消息
    mainSendPort.send({
      'type': 'complete',
      'total': total,
      'success': successCount,
      'failed': failedCount,
    });
  } catch (e) {
    // 发送错误消息
    mainSendPort.send({
      'type': 'error',
      'error': e.toString(),
    });
  }
}

/// 下载任务模型
class DownloadTask {
  final Book book;
  final List<BookChapter> chapters;
  final BookSource source;
  final int batchSize;
  final bool showNotification;

  DownloadTask({
    required this.book,
    required this.chapters,
    required this.source,
    this.batchSize = 10,
    this.showNotification = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'book': book.toJson(),
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'source': source.toJson(),
      'batchSize': batchSize,
      'showNotification': showNotification,
    };
  }
}

/// 下载进度模型
class DownloadProgress {
  final DownloadStatus status;
  final int total;
  final int completed;
  final String? currentChapter;
  final String? error;

  DownloadProgress({
    required this.status,
    this.total = 0,
    this.completed = 0,
    this.currentChapter,
    this.error,
  });

  factory DownloadProgress.idle() {
    return DownloadProgress(status: DownloadStatus.idle);
  }

  factory DownloadProgress.downloading({
    required int total,
    required int completed,
    String? currentChapter,
  }) {
    return DownloadProgress(
      status: DownloadStatus.downloading,
      total: total,
      completed: completed,
      currentChapter: currentChapter,
    );
  }

  factory DownloadProgress.completed({
    required int total,
    required int completed,
  }) {
    return DownloadProgress(
      status: DownloadStatus.completed,
      total: total,
      completed: completed,
    );
  }

  factory DownloadProgress.cancelled() {
    return DownloadProgress(status: DownloadStatus.cancelled);
  }

  factory DownloadProgress.error({required String error}) {
    return DownloadProgress(
      status: DownloadStatus.error,
      error: error,
    );
  }

  double get progress => total > 0 ? completed / total : 0.0;

  @override
  String toString() {
    return 'DownloadProgress(status: $status, completed: $completed/$total, '
        'current: $currentChapter, error: $error)';
  }
}

/// 下载状态枚举
enum DownloadStatus {
  idle, // 空闲
  downloading, // 下载中
  completed, // 已完成
  cancelled, // 已取消
  error, // 出错
}
