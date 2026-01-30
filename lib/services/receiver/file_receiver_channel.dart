import 'dart:io';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../utils/app_log.dart';
import '../../config/app_config.dart';
import '../book/local_book_service.dart';
import '../qrcode_result_handler.dart';

/// 文件接收通道
/// 参考项目：io.legado.app.ui.association.FileAssociationActivity
class FileReceiverChannel {
  static final FileReceiverChannel instance = FileReceiverChannel._init();
  FileReceiverChannel._init();

  static const MethodChannel _channel = MethodChannel('io.legado.app/file');

  /// 初始化文件接收监听
  Future<void> init() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// 处理MethodCall
  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onFile':
          final uri = call.arguments['uri'] as String?;
          if (uri != null) {
            await handleFile(uri);
          }
          break;
        default:
          AppLog.instance.put('未知的文件接收方法: ${call.method}');
      }
    } catch (e) {
      AppLog.instance.put('处理文件接收失败: $e', error: e);
    }
  }

  /// 处理文件
  /// 参考项目：FileAssociationViewModel.dispatchIntent()
  Future<void> handleFile(String uri) async {
    try {
      AppLog.instance.put('收到文件打开请求: $uri');

      // 判断URI类型
      if (uri.startsWith('http://') || uri.startsWith('https://')) {
        // 在线URL，使用在线导入处理
        await QrcodeResultHandler.instance.handleResult(uri);
        return;
      }

      // 处理本地文件
      if (uri.startsWith('content://') || uri.startsWith('file://')) {
        await _handleLocalFile(uri);
      } else {
        AppLog.instance.put('不支持的文件URI格式: $uri');
      }
    } catch (e) {
      AppLog.instance.put('处理文件失败: $e', error: e);
    }
  }

  /// 处理本地文件
  /// 参考项目：FileAssociationViewModel.dispatch()
  Future<void> _handleLocalFile(String uri) async {
    try {
      // 获取文件路径和扩展名
      String? filePath;
      String? extension;

      if (uri.startsWith('file://')) {
        filePath = uri.substring(7);
        extension = _getExtensionFromPath(filePath);
      } else if (uri.startsWith('content://')) {
        // content:// URI需要通过平台通道获取文件名和扩展名
        try {
          final fileInfo = await _getFileInfoFromContentUri(uri);
          if (fileInfo != null) {
            filePath = fileInfo['path'];
            extension = fileInfo['extension'];
          } else {
            // 如果无法获取文件信息，尝试从URI中提取
            extension = _getExtensionFromUri(uri);
          }
        } catch (e) {
          AppLog.instance.put('获取content:// URI文件信息失败: $e', error: e);
          extension = _getExtensionFromUri(uri);
        }
      }

      if (extension == null || extension.isEmpty) {
        AppLog.instance.put('无法识别文件类型: $uri');
        _showUnsupportedFileTypeDialog(uri);
        return;
      }

      final lowerExtension = extension.toLowerCase();

      // 判断是否为压缩包
      final archiveExtensions = ['zip', 'rar', '7z'];
      if (archiveExtensions.contains(lowerExtension)) {
        await _handleArchiveFile(uri, filePath);
        return;
      }

      // 判断是否为JSON配置文件
      if (lowerExtension == 'json') {
        await _handleJsonFile(uri);
        return;
      }

      // 判断是否为书籍文件
      final bookExtensions = [
        'epub',
        'mobi',
        'azw',
        'azw3',
        'fb2',
        'umd',
        'txt',
        'pdf'
      ];
      if (bookExtensions.contains(lowerExtension)) {
        await _handleBookFile(uri, filePath);
        return;
      }

      // 不支持的文件类型
      AppLog.instance.put('不支持的文件类型: $extension');
      _showUnsupportedFileTypeDialog(uri);
    } catch (e) {
      AppLog.instance.put('处理本地文件失败: $e', error: e);
    }
  }

  /// 处理JSON文件
  Future<void> _handleJsonFile(String uri) async {
    try {
      final content = await _readContentFromUri(uri);
      if (content != null) {
        await QrcodeResultHandler.instance.handleResult(content);
      } else {
        AppLog.instance.put('读取JSON文件失败: $uri');
      }
    } catch (e) {
      AppLog.instance.put('处理JSON文件失败: $e', error: e);
    }
  }

  /// 处理书籍文件
  Future<void> _handleBookFile(String uri, String? filePath) async {
    try {
      File? file;

      if (uri.startsWith('file://') && filePath != null) {
        file = File(filePath);
        if (!await file.exists()) {
          AppLog.instance.put('文件不存在: $filePath');
          return;
        }
      } else if (uri.startsWith('content://')) {
        // content:// URI需要先复制到临时目录
        file = await _copyContentUriToTempFile(uri);
        if (file == null) {
          AppLog.instance.put('无法处理content:// URI: $uri');
          return;
        }
      }

      if (file != null) {
        final book = await LocalBookService.instance.importBook(file.path);
        if (book != null) {
          AppLog.instance.put('导入书籍成功: ${book.name}');
        }
      }
    } catch (e) {
      AppLog.instance.put('导入书籍失败: $e', error: e);
    }
  }

  /// 处理压缩包文件
  /// 参考项目：FileAssociationViewModel.importBook() - 压缩包解压逻辑
  Future<void> _handleArchiveFile(String uri, String? filePath) async {
    try {
      // 读取压缩包内容
      Uint8List? archiveBytes;

      if (uri.startsWith('file://') && filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          archiveBytes = await file.readAsBytes();
        }
      } else if (uri.startsWith('content://')) {
        archiveBytes = await _readBytesFromContentUri(uri);
      }

      if (archiveBytes == null || archiveBytes.isEmpty) {
        AppLog.instance.put('无法读取压缩包: $uri');
        return;
      }

      // 解压压缩包
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(archiveBytes);
      } catch (e) {
        AppLog.instance.put('解压失败，可能不是ZIP格式: $e');
        // 可以尝试其他格式（RAR、7Z等）
        return;
      }

      if (archive.files.isEmpty) {
        AppLog.instance.put('压缩包为空或格式不正确');
        return;
      }

      // 查找书籍文件
      final bookExtensions = [
        'epub',
        'mobi',
        'azw',
        'azw3',
        'fb2',
        'umd',
        'txt',
        'pdf'
      ];
      final bookFiles = archive.files.where((file) {
        if (file.isFile) {
          final fileName = file.name.toLowerCase();
          return bookExtensions.any((ext) => fileName.endsWith('.$ext'));
        }
        return false;
      }).toList();

      if (bookFiles.isEmpty) {
        AppLog.instance.put('压缩包中未找到书籍文件');
        return;
      }

      // 创建临时目录
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory(path.join(
          tempDir.path, 'extracted_${DateTime.now().millisecondsSinceEpoch}'));
      await extractDir.create(recursive: true);

      // 解压书籍文件并导入
      int successCount = 0;
      int failCount = 0;
      for (final archiveFile in bookFiles) {
        try {
          final fileName = path.basename(archiveFile.name);

          // 检查文件大小（避免处理过大的文件）
          final content = archiveFile.content as List<int>;
          if (content.isEmpty) {
            AppLog.instance.put('跳过空文件: $fileName');
            failCount++;
            continue;
          }

          // 限制单个文件大小（例如100MB）
          const maxFileSize = 100 * 1024 * 1024; // 100MB
          if (content.length > maxFileSize) {
            AppLog.instance.put(
                '文件过大，跳过: $fileName (${(content.length / 1024 / 1024).toStringAsFixed(2)}MB)');
            failCount++;
            continue;
          }

          final extractPath = path.join(extractDir.path, fileName);
          final extractFile = File(extractPath);
          await extractFile.writeAsBytes(content);

          final book = await LocalBookService.instance.importBook(extractPath);
          if (book != null) {
            successCount++;
            AppLog.instance.put('从压缩包导入书籍成功: ${book.name}');
          } else {
            failCount++;
            AppLog.instance.put('导入书籍失败: $fileName');
          }
        } catch (e) {
          failCount++;
          AppLog.instance.put('解压并导入书籍失败: ${archiveFile.name}', error: e);
        }
      }

      // 清理临时目录
      try {
        await extractDir.delete(recursive: true);
      } catch (e) {
        AppLog.instance.put('清理临时目录失败: $e', error: e);
        // 尝试延迟清理
        Future.delayed(const Duration(seconds: 5), () async {
          try {
            await extractDir.delete(recursive: true);
          } catch (_) {
            // 忽略延迟清理失败
          }
        });
      }

      if (successCount > 0) {
        AppLog.instance.put(
            '压缩包处理完成，成功导入 $successCount 个书籍文件${failCount > 0 ? '，失败 $failCount 个' : ''}');
      } else {
        AppLog.instance.put('压缩包处理完成，但未能导入任何书籍文件（失败 $failCount 个）');
      }
    } catch (e) {
      AppLog.instance.put('处理压缩包失败: $e', error: e);
    }
  }

  /// 显示不支持的文件类型对话框
  /// 通过AppConfig通知UI层显示对话框
  void _showUnsupportedFileTypeDialog(String uri) {
    try {
      // 从URI提取文件名
      String fileName = '未知文件';
      String? fileExtension;

      try {
        final uriObj = Uri.parse(uri);
        final pathSegments = uriObj.pathSegments;
        if (pathSegments.isNotEmpty) {
          fileName = pathSegments.last;
          if (fileName.contains('.')) {
            fileExtension = fileName.split('.').last;
          }
        }
      } catch (e) {
        // 解析失败，使用默认值
      }

      // 通过AppConfig设置待显示的不支持文件对话框信息
      AppConfig.setString('pending_unsupported_file_name', fileName);
      if (fileExtension != null) {
        AppConfig.setString(
            'pending_unsupported_file_extension', fileExtension);
      }
      AppConfig.setString('pending_navigation', 'unsupported_file');

      AppLog.instance.put('不支持的文件类型: $uri (文件名: $fileName)');
    } catch (e) {
      AppLog.instance.put('显示不支持文件类型对话框失败: $e', error: e);
    }
  }

  /// 从content:// URI获取文件信息
  Future<Map<String, String>?> _getFileInfoFromContentUri(String uri) async {
    try {
      final result = await _channel.invokeMethod('getFileInfo', {'uri': uri});
      if (result is Map) {
        return Map<String, String>.from(result);
      }
      return null;
    } catch (e) {
      AppLog.instance.put('获取content:// URI文件信息失败: $e', error: e);
      return null;
    }
  }

  /// 从content:// URI读取文本内容
  Future<String?> _readContentFromUri(String uri) async {
    try {
      if (uri.startsWith('file://')) {
        final file = File(uri.substring(7));
        if (await file.exists()) {
          return await file.readAsString();
        }
      } else if (uri.startsWith('content://')) {
        // 通过平台通道读取content:// URI内容
        try {
          final result =
              await _channel.invokeMethod('readContentUri', {'uri': uri});
          if (result is String) {
            return result;
          }
        } catch (e) {
          AppLog.instance.put('通过平台通道读取content:// URI失败: $e', error: e);
        }
      }
      return null;
    } catch (e) {
      AppLog.instance.put('读取文件内容失败: $e', error: e);
      return null;
    }
  }

  /// 从content:// URI读取字节数据
  Future<Uint8List?> _readBytesFromContentUri(String uri) async {
    try {
      if (uri.startsWith('file://')) {
        final file = File(uri.substring(7));
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } else if (uri.startsWith('content://')) {
        // 通过平台通道读取content:// URI字节数据
        try {
          final result =
              await _channel.invokeMethod('readContentUriBytes', {'uri': uri});
          if (result is Uint8List) {
            return result;
          } else if (result is List<int>) {
            return Uint8List.fromList(result);
          }
        } catch (e) {
          AppLog.instance.put('通过平台通道读取content:// URI字节失败: $e', error: e);
        }
      }
      return null;
    } catch (e) {
      AppLog.instance.put('读取文件字节失败: $e', error: e);
      return null;
    }
  }

  /// 将content:// URI复制到临时文件
  Future<File?> _copyContentUriToTempFile(String uri) async {
    try {
      final bytes = await _readBytesFromContentUri(uri);
      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      // 获取文件名
      final fileInfo = await _getFileInfoFromContentUri(uri);
      final fileName = fileInfo?['name'] ?? 'temp_file';

      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(bytes);

      return tempFile;
    } catch (e) {
      AppLog.instance.put('复制content:// URI到临时文件失败: $e', error: e);
      return null;
    }
  }

  /// 从路径获取扩展名
  String? _getExtensionFromPath(String path) {
    try {
      final fileName = path.split('/').last;
      if (fileName.contains('.')) {
        return fileName.split('.').last;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 从URI获取扩展名
  String? _getExtensionFromUri(String uri) {
    try {
      final uriObj = Uri.parse(uri);
      final pathSegments = uriObj.pathSegments;
      if (pathSegments.isNotEmpty) {
        final fileName = pathSegments.last;
        if (fileName.contains('.')) {
          return fileName.split('.').last;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
