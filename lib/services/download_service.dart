import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';
import '../../core/base/base_service.dart';
import '../../utils/app_log.dart';
import 'network/network_service.dart';
import 'notification_service.dart';

/// 下载信息
class DownloadInfo {
  final String id;
  final String url;
  final String fileName;
  final String savePath;
  final int notificationId;
  
  DownloadInfo({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    required this.notificationId,
  });
}

/// 下载状态
enum DownloadStatus {
  pending,    // 等待下载
  downloading, // 下载中
  paused,     // 已暂停
  completed,  // 已完成
  failed,     // 失败
  cancelled,  // 已取消
}

/// 下载任务
class DownloadTask {
  final String id;
  final String url;
  final String fileName;
  final String savePath;
  final CancelToken cancelToken;
  DownloadStatus status;
  int downloadedBytes;
  int totalBytes;
  String? errorMessage;
  
  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    required this.cancelToken,
    this.status = DownloadStatus.pending,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
  });
  
  /// 获取下载进度（0.0 - 1.0）
  double get progress {
    if (totalBytes == 0) return 0.0;
    return downloadedBytes / totalBytes;
  }
}

/// 下载服务
/// 参考项目：io.legado.app.service.DownloadService
class DownloadService extends BaseService {
  static final DownloadService instance = DownloadService._init();
  DownloadService._init();

  final Map<String, DownloadTask> _downloads = {};
  final Map<String, DownloadInfo> _downloadInfos = {};
  final Set<String> _completedDownloads = {};
  static const int baseNotificationId = 106; // 参考项目：NotificationId.Download

  /// 下载进度回调
  /// [taskId] 任务ID
  /// [progress] 进度（0.0 - 1.0）
  /// [downloadedBytes] 已下载字节数
  /// [totalBytes] 总字节数
  Function(String taskId, double progress, int downloadedBytes, int totalBytes)? onProgress;

  /// 下载完成回调
  /// [taskId] 任务ID
  /// [filePath] 文件路径
  Function(String taskId, String filePath)? onComplete;

  /// 下载失败回调
  /// [taskId] 任务ID
  /// [error] 错误信息
  Function(String taskId, String error)? onError;

  /// 开始下载文件
  /// 参考项目：DownloadService.startDownload()
  /// 
  /// [url] 下载URL
  /// [fileName] 文件名（可选，如果不提供则从URL提取）
  /// [savePath] 保存路径（可选，如果不提供则保存到Downloads目录）
  /// 
  /// 返回任务ID
  Future<String?> startDownload(
    String url, {
    String? fileName,
    String? savePath,
  }) async {
    try {
      // 检查URL是否已在下载列表中
      final existingTask = _downloads.values.firstWhere(
        (task) => task.url == url,
        orElse: () => throw Exception(''),
      );
      if (existingTask.status == DownloadStatus.downloading ||
          existingTask.status == DownloadStatus.pending) {
        AppLog.instance.put('文件已在下载列表中: $url');
        return existingTask.id;
      }
    } catch (e) {
      // URL不在下载列表中，继续
    }

    // 生成任务ID
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();

    // 确定文件名
    String finalFileName = fileName ?? _extractFileNameFromUrl(url);
    if (finalFileName.isEmpty) {
      finalFileName = 'download_$taskId';
    }

    // 确定保存路径
    String finalSavePath;
    if (savePath != null) {
      finalSavePath = savePath;
    } else {
      // 保存到Downloads目录
      final downloadsDir = await _getDownloadsDirectory();
      finalSavePath = path.join(downloadsDir.path, finalFileName);
    }

    // 检查文件是否已存在
    final file = File(finalSavePath);
    if (await file.exists()) {
      // 文件已存在，询问是否覆盖（这里直接覆盖）
      AppLog.instance.put('文件已存在，将覆盖: $finalSavePath');
    }

    // 创建下载任务
    final cancelToken = CancelToken();
    final task = DownloadTask(
      id: taskId,
      url: url,
      fileName: finalFileName,
      savePath: finalSavePath,
      cancelToken: cancelToken,
      status: DownloadStatus.pending,
    );

    final downloadInfo = DownloadInfo(
      id: taskId,
      url: url,
      fileName: finalFileName,
      savePath: finalSavePath,
      notificationId: baseNotificationId + _downloads.length,
    );

    _downloads[taskId] = task;
    _downloadInfos[taskId] = downloadInfo;

    // 开始下载
    _downloadFile(task);

    return taskId;
  }

  /// 下载文件（内部方法）
  Future<void> _downloadFile(DownloadTask task) async {
    try {
      task.status = DownloadStatus.downloading;

      // 确保目录存在
      final file = File(task.savePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 显示下载通知
      await NotificationService.instance.showProgressNotification(
        id: _downloadInfos[task.id]?.notificationId ?? baseNotificationId,
        title: '下载文件',
        content: task.fileName,
        progress: 0.0,
        max: 0,
        current: 0,
        isOngoing: true,
        channelId: NotificationService.channelIdDownload,
      );

      // 使用 NetworkService 下载
      await NetworkService.instance.download(
        task.url,
        task.savePath,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          task.downloadedBytes = received;
          task.totalBytes = total;
          
          // 更新进度回调
          onProgress?.call(
            task.id,
            task.progress,
            received,
            total,
          );
          
          // 更新通知
          NotificationService.instance.showProgressNotification(
            id: _downloadInfos[task.id]?.notificationId ?? baseNotificationId,
            title: '下载文件',
            content: task.fileName,
            progress: task.progress,
            max: total,
            current: received,
            isOngoing: true,
            channelId: NotificationService.channelIdDownload,
          );
        },
      );

      // 下载完成
      task.status = DownloadStatus.completed;
      _completedDownloads.add(task.id);
      
      // 显示完成通知（添加payload用于点击跳转）
      await NotificationService.instance.showNotification(
        id: _downloadInfos[task.id]?.notificationId ?? baseNotificationId,
        title: '下载完成',
        content: task.fileName,
        isOngoing: false,
        channelId: NotificationService.channelIdDownload,
        payload: 'download:${task.savePath}', // payload格式：action:data
      );
      
      onComplete?.call(task.id, task.savePath);
      AppLog.instance.put('下载完成: ${task.fileName} -> ${task.savePath}');
    } catch (e) {
      if (task.cancelToken.isCancelled) {
        task.status = DownloadStatus.cancelled;
        AppLog.instance.put('下载已取消: ${task.fileName}');
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.toString();
        
        // 显示失败通知
        await NotificationService.instance.showNotification(
          id: _downloadInfos[task.id]?.notificationId ?? baseNotificationId,
          title: '下载失败',
          content: '${task.fileName}: ${e.toString()}',
          isOngoing: false,
          channelId: NotificationService.channelIdDownload,
        );
        
        onError?.call(task.id, e.toString());
        AppLog.instance.put('下载失败: ${task.fileName}', error: e);
      }
    }
  }

  /// 取消下载
  /// 参考项目：DownloadService.removeDownload()
  Future<bool> cancelDownload(String taskId) async {
    final task = _downloads[taskId];
    if (task == null) {
      return false;
    }

    try {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.pending) {
        task.cancelToken.cancel('用户取消');
        task.status = DownloadStatus.cancelled;
      }

      _downloads.remove(taskId);
      _downloadInfos.remove(taskId);
      _completedDownloads.remove(taskId);

      AppLog.instance.put('已取消下载: ${task.fileName}');
      return true;
    } catch (e) {
      AppLog.instance.put('取消下载失败: ${task.fileName}', error: e);
      return false;
    }
  }

  /// 暂停下载
  /// 注意：dio 的 CancelToken 不支持暂停，只能取消
  /// 如果需要暂停功能，需要使用其他下载库或平台通道
  Future<bool> pauseDownload(String taskId) async {
    final task = _downloads[taskId];
    if (task == null || task.status != DownloadStatus.downloading) {
      return false;
    }

    // dio 不支持暂停，这里只能取消
    // 如果需要暂停功能，建议使用 flutter_downloader 插件
    AppLog.instance.put('dio不支持暂停下载，将取消下载: ${task.fileName}');
    return await cancelDownload(taskId);
  }

  /// 获取下载任务
  DownloadTask? getDownloadTask(String taskId) {
    return _downloads[taskId];
  }

  /// 获取所有下载任务
  List<DownloadTask> getAllDownloadTasks() {
    return _downloads.values.toList();
  }

  /// 获取下载信息
  DownloadInfo? getDownloadInfo(String taskId) {
    return _downloadInfos[taskId];
  }

  /// 检查下载是否完成
  bool isDownloadCompleted(String taskId) {
    return _completedDownloads.contains(taskId);
  }

  /// 打开下载的文件
  /// 参考项目：DownloadService.openDownload()
  Future<bool> openDownload(String taskId) async {
    final task = _downloads[taskId];
    if (task == null) {
      return false;
    }

    if (task.status != DownloadStatus.completed) {
      AppLog.instance.put('下载未完成，无法打开: ${task.fileName}');
      return false;
    }

    try {
      final file = File(task.savePath);
      if (!await file.exists()) {
        AppLog.instance.put('文件不存在: ${task.savePath}');
        return false;
      }

      // 使用 open_filex 打开文件
      final result = await OpenFilex.open(task.savePath);
      if (result.type == ResultType.done) {
        AppLog.instance.put('打开文件成功: ${task.savePath}');
        return true;
      } else {
        AppLog.instance.put('无法打开文件: ${result.message}');
        return false;
      }
    } catch (e) {
      AppLog.instance.put('打开文件失败: ${task.savePath}', error: e);
      return false;
    }
  }

  /// 获取Downloads目录
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Android: 使用外部存储的Downloads目录
      // 注意：需要存储权限
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadsDir = Directory(path.join(directory.path, '..', 'Download'));
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        return downloadsDir;
      }
    }
    
    // iOS 或其他平台：使用应用文档目录
    final directory = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(path.join(directory.path, 'Downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  /// 从URL提取文件名
  String _extractFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final fileName = pathSegments.last;
        if (fileName.isNotEmpty && fileName.contains('.')) {
          return fileName;
        }
      }
      
      // 尝试从查询参数获取文件名
      final contentDisposition = uri.queryParameters['filename'];
      if (contentDisposition != null && contentDisposition.isNotEmpty) {
        return contentDisposition;
      }
      
      return '';
    } catch (e) {
      return '';
    }
  }

  /// 清除所有下载任务
  Future<void> clearAllDownloads() async {
    // 取消所有进行中的下载
    for (final task in _downloads.values) {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.pending) {
        task.cancelToken.cancel('清除所有下载');
      }
    }

    _downloads.clear();
    _downloadInfos.clear();
    _completedDownloads.clear();
    AppLog.instance.put('已清除所有下载任务');
  }

  @override
  Future<void> onDispose() async {
    await clearAllDownloads();
  }
}

