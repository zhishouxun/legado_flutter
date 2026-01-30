import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart' as xml;
import '../../core/base/base_service.dart';
import '../../config/app_config.dart';
import '../../utils/app_log.dart';

/// WebDAV文件信息
class WebDavFile {
  final String name;
  final String path;
  final int size;
  final DateTime lastModified;
  final bool isDirectory;

  WebDavFile({
    required this.name,
    required this.path,
    required this.size,
    required this.lastModified,
    required this.isDirectory,
  });
}

/// WebDAV服务 - 处理备份恢复相关的WebDAV操作
class WebDavService extends BaseService {
  static final WebDavService instance = WebDavService._init();
  WebDavService._init();

  Dio? _dio;
  String? _rootUrl;
  String? _username;
  String? _password;

  static const String defaultWebDavUrl = 'https://dav.jianguoyun.com/dav/';

  /// 获取根URL
  String get rootUrl {
    if (_rootUrl != null) return _rootUrl!;
    
    var url = AppConfig.getString('webdav_url', defaultValue: defaultWebDavUrl);
    if (!url.endsWith('/')) {
      url = '$url/';
    }
    
    final dir = AppConfig.getString('webdav_dir', defaultValue: 'legado');
    if (dir.isNotEmpty) {
      url = '$url$dir/';
    }
    
    return url;
  }

  /// 配置WebDAV连接
  Future<void> configure({
    required String url,
    String? username,
    String? password,
  }) async {
    var baseUrl = url;
    if (!baseUrl.endsWith('/')) {
      baseUrl = '$baseUrl/';
    }

    _rootUrl = baseUrl;
    _username = username;
    _password = password;

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // 设置认证
    if (username != null && password != null) {
      final auth = base64Encode(utf8.encode('$username:$password'));
      _dio!.options.headers['Authorization'] = 'Basic $auth';
    }

    // 保存配置
    await AppConfig.setString('webdav_url', url);
    if (username != null) {
      await AppConfig.setString('webdav_account', username);
    }
    if (password != null) {
      await AppConfig.setString('webdav_password', password);
    }
  }

  /// 从配置加载
  Future<void> loadConfig() async {
    final url = AppConfig.getString('webdav_url', defaultValue: defaultWebDavUrl);
    final username = AppConfig.getString('webdav_account');
    final password = AppConfig.getString('webdav_password');
    
    if (url.isNotEmpty && username.isNotEmpty && password.isNotEmpty) {
      await configure(url: url, username: username, password: password);
    }
  }

  /// 检查是否已配置
  bool get isConfigured => _dio != null && _username != null && _password != null;

  /// 检查连接和认证
  Future<bool> check() async {
    if (!isConfigured) {
      return false;
    }

    try {
      final response = await _dio!.request(
        '',
        options: Options(method: 'PROPFIND', headers: {'Depth': '0'}),
      );
      return response.statusCode == 207 || response.statusCode == 200;
    } catch (e) {
      AppLog.instance.put('WebDAV连接检查失败', error: e);
      return false;
    }
  }

  /// 创建目录（如果不存在）
  Future<void> makeAsDir() async {
    if (!isConfigured) return;

    try {
      await _dio!.request(
        '',
        options: Options(method: 'MKCOL'),
      );
    } catch (e) {
      // 目录可能已存在，忽略错误
    }
  }

  /// 列出文件
  Future<List<WebDavFile>> listFiles({String? path}) async {
    if (!isConfigured) {
      throw Exception('WebDAV未配置');
    }

    try {
      final targetPath = path ?? '';
      final response = await _dio!.request(
        targetPath,
        options: Options(
          method: 'PROPFIND',
          headers: {
            'Depth': '1',
            'Content-Type': 'application/xml',
          },
        ),
        data: '''<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <prop>
    <resourcetype/>
    <getcontentlength/>
    <getlastmodified/>
    <displayname/>
  </prop>
</propfind>''',
      );

      final xmlDoc = xml.XmlDocument.parse(response.data.toString());
      final files = <WebDavFile>[];

      final responses = xmlDoc.findAllElements('response');
      for (final response in responses) {
        final href = response.findElements('href').firstOrNull?.text ?? '';
        if (href.isEmpty || href == targetPath || href == '$targetPath/') {
          continue;
        }

        final pathParts = href.split('/').where((p) => p.isNotEmpty).toList();
        final name = pathParts.isNotEmpty ? pathParts.last : '';

        final resourcetype = response.findElements('resourcetype').firstOrNull;
        final isDir = resourcetype?.findElements('collection').isNotEmpty ?? false;

        final contentLength = response.findElements('getcontentlength').firstOrNull?.text ?? '0';
        final size = int.tryParse(contentLength) ?? 0;

        final lastModified = response.findElements('getlastmodified').firstOrNull?.text ?? '';
        final lastModify = _parseLastModified(lastModified);

        files.add(WebDavFile(
          name: name,
          path: href,
          size: size,
          lastModified: lastModify,
          isDirectory: isDir,
        ));
      }

      return files;
    } catch (e) {
      AppLog.instance.put('列出WebDAV文件失败', error: e);
      rethrow;
    }
  }

  /// 上传文件
  Future<void> upload(String filePath, {String? remotePath}) async {
    if (!isConfigured) {
      throw Exception('WebDAV未配置');
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }

      final targetPath = remotePath ?? file.path.split('/').last;
      final bytes = await file.readAsBytes();

      await _dio!.put(
        targetPath,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': 'application/zip',
            'Content-Length': bytes.length.toString(),
          },
        ),
      );
    } catch (e) {
      AppLog.instance.put('上传文件到WebDAV失败', error: e);
      rethrow;
    }
  }

  /// 上传字节数组
  Future<void> uploadBytes(List<int> bytes, String remotePath) async {
    if (!isConfigured) {
      throw Exception('WebDAV未配置');
    }

    try {
      await _dio!.put(
        remotePath,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': 'application/zip',
            'Content-Length': bytes.length.toString(),
          },
        ),
      );
    } catch (e) {
      AppLog.instance.put('上传字节到WebDAV失败', error: e);
      rethrow;
    }
  }

  /// 下载文件
  Future<List<int>> download(String remotePath) async {
    if (!isConfigured) {
      throw Exception('WebDAV未配置');
    }

    try {
      final response = await _dio!.get<List<int>>(
        remotePath,
        options: Options(responseType: ResponseType.bytes),
      );

      return response.data ?? [];
    } catch (e) {
      AppLog.instance.put('从WebDAV下载文件失败', error: e);
      rethrow;
    }
  }

  /// 下载文件到本地
  Future<void> downloadTo(String remotePath, String localPath) async {
    if (!isConfigured) {
      throw Exception('WebDAV未配置');
    }

    try {
      final bytes = await download(remotePath);
      final file = File(localPath);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
    } catch (e) {
      AppLog.instance.put('下载文件到本地失败', error: e);
      rethrow;
    }
  }

  /// 检查文件是否存在
  Future<bool> exists(String remotePath) async {
    if (!isConfigured) {
      return false;
    }

    try {
      final response = await _dio!.head(remotePath);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 删除文件
  Future<void> delete(String remotePath) async {
    if (!isConfigured) {
      throw Exception('WebDAV未配置');
    }

    try {
      await _dio!.delete(remotePath);
    } catch (e) {
      AppLog.instance.put('删除WebDAV文件失败', error: e);
      rethrow;
    }
  }

  /// 解析最后修改时间
  DateTime _parseLastModified(String lastModified) {
    if (lastModified.isEmpty) {
      return DateTime.now();
    }

    try {
      return DateTime.parse(lastModified);
    } catch (e) {
      return DateTime.now();
    }
  }

  // ========== 书籍进度同步 ==========

  /// 获取书籍进度 URL
  String _getBookProgressUrl() {
    return '${rootUrl}bookProgress/';
  }

  /// 获取导出书籍 URL
  String _getExportsUrl() {
    return '${rootUrl}books/';
  }

  /// 获取背景图片 URL
  String _getBackgroundUrl() {
    return '${rootUrl}background/';
  }

  /// 获取进度文件名
  /// 参考项目：AppWebDav.getProgressFileName()
  String _getProgressFileName(String name, String author) {
    // 规范化文件名（移除特殊字符）
    final fileName = '${name}_$author'
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return '$fileName.json';
  }

  /// 获取进度文件 URL
  String _getProgressUrl(String name, String author) {
    return '${_getBookProgressUrl()}${_getProgressFileName(name, author)}';
  }

  /// 上传书籍进度
  /// 参考项目：AppWebDav.uploadBookProgress()
  Future<void> uploadBookProgress({
    required String name,
    required String author,
    required int durChapterIndex,
    required int durChapterPos,
    String? durChapterTitle,
    int? durChapterTime,
    String? contentType,
  }) async {
    if (!isConfigured) return;
    if (!AppConfig.getSyncBookProgress()) return;

    try {
      final progressData = {
        'name': name,
        'author': author,
        'durChapterIndex': durChapterIndex,
        'durChapterPos': durChapterPos,
        'durChapterTitle': durChapterTitle,
        'durChapterTime': durChapterTime ?? DateTime.now().millisecondsSinceEpoch,
      };

      final json = jsonEncode(progressData);
      final url = _getProgressUrl(name, author);
      final bytes = utf8.encode(json);

      await _dio!.put(
        url,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType ?? 'application/json',
            'Content-Length': bytes.length.toString(),
          },
        ),
      );

      AppLog.instance.put('上传书籍进度成功: $name');
    } catch (e) {
      AppLog.instance.put('上传书籍进度失败: $name', error: e);
      rethrow;
    }
  }

  /// 获取书籍进度
  /// 参考项目：AppWebDav.getBookProgress()
  Future<Map<String, dynamic>?> getBookProgress(String name, String author) async {
    if (!isConfigured) return null;

    try {
      final url = _getProgressUrl(name, author);
      final bytes = await download(url);
      final json = String.fromCharCodes(bytes);

      // 检查是否是有效的 JSON
      try {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return decoded;
      } catch (e) {
        AppLog.instance.put('解析书籍进度 JSON 失败: $name', error: e);
        return null;
      }
    } catch (e) {
      AppLog.instance.put('获取书籍进度失败: $name', error: e);
      return null;
    }
  }

  /// 下载所有书籍进度
  /// 参考项目：AppWebDav.downloadAllBookProgress()
  Future<void> downloadAllBookProgress({
    required List<Map<String, dynamic>> books,
    required Future<void> Function(String bookUrl, Map<String, dynamic> progress) onProgressUpdate,
  }) async {
    if (!isConfigured) return;
    if (!AppConfig.getSyncBookProgress()) return;

    try {
      // 获取所有进度文件
      final progressFiles = await listFiles(path: 'bookProgress/');
      final progressMap = <String, WebDavFile>{};
      for (final file in progressFiles) {
        if (!file.isDirectory) {
          progressMap[file.name] = file;
        }
      }

      // 遍历所有书籍，检查是否需要同步
      for (final book in books) {
        final name = book['name'] as String? ?? '';
        final author = book['author'] as String? ?? '';
        final bookUrl = book['bookUrl'] as String? ?? '';
        final syncTime = book['syncTime'] as int? ?? 0;

        if (name.isEmpty || author.isEmpty || bookUrl.isEmpty) continue;

        final progressFileName = _getProgressFileName(name, author);
        final webDavFile = progressMap[progressFileName];
        if (webDavFile == null) continue;

        // 检查是否需要同步（云端时间大于本地同步时间）
        final cloudTime = webDavFile.lastModified.millisecondsSinceEpoch;
        if (cloudTime <= syncTime) {
          continue; // 本地已是最新
        }

        // 获取云端进度
        final progress = await getBookProgress(name, author);
        if (progress != null) {
          // 检查云端进度是否更新
          final cloudChapterIndex = progress['durChapterIndex'] as int? ?? 0;
          final cloudChapterPos = progress['durChapterPos'] as int? ?? 0;
          final localChapterIndex = book['durChapterIndex'] as int? ?? 0;
          final localChapterPos = book['durChapterPos'] as int? ?? 0;

          if (cloudChapterIndex > localChapterIndex ||
              (cloudChapterIndex == localChapterIndex && cloudChapterPos > localChapterPos)) {
            // 云端进度更新，更新本地
            await onProgressUpdate(bookUrl, progress);
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('下载所有书籍进度失败', error: e);
    }
  }

  /// 导出书籍到 WebDAV
  /// 参考项目：AppWebDav.exportWebDav()
  Future<void> exportBook(String fileName, List<int> bytes) async {
    if (!isConfigured) return;

    try {
      final url = '${_getExportsUrl()}$fileName';
      await uploadBytes(bytes, url);
      AppLog.instance.put('导出书籍到WebDAV成功: $fileName');
    } catch (e) {
      AppLog.instance.put('导出书籍到WebDAV失败: $fileName', error: e);
      rethrow;
    }
  }

  /// 上传背景图片
  /// 参考项目：AppWebDav.upBgs()
  Future<void> uploadBackgrounds(List<File> files) async {
    if (!isConfigured) return;

    try {
      // 获取云端已有的背景图片
      final cloudFiles = await listFiles(path: 'background/');
      final cloudFileNames = cloudFiles
          .where((f) => !f.isDirectory)
          .map((f) => f.name)
          .toSet();

      // 上传新文件
      for (final file in files) {
        if (!await file.exists()) continue;
        if (cloudFileNames.contains(file.path.split('/').last)) {
          continue; // 已存在，跳过
        }

        final fileName = file.path.split('/').last;
        final url = '${_getBackgroundUrl()}$fileName';
        await upload(file.path, remotePath: url);
      }
    } catch (e) {
      AppLog.instance.put('上传背景图片失败', error: e);
    }
  }

  /// 下载背景图片
  /// 参考项目：AppWebDav.downBgs()
  Future<List<WebDavFile>> downloadBackgrounds() async {
    if (!isConfigured) return [];

    try {
      final files = await listFiles(path: 'background/');
      return files.where((f) => !f.isDirectory).toList();
    } catch (e) {
      AppLog.instance.put('下载背景图片列表失败', error: e);
      return [];
    }
  }

  // ========== 备份管理 ==========

  /// 获取备份文件名列表
  /// 参考项目：AppWebDav.getBackupNames()
  Future<List<String>> getBackupNames() async {
    if (!isConfigured) {
      throw Exception('WebDAV未配置');
    }

    try {
      final files = await listFiles();
      final backupFiles = files
          .where((f) => !f.isDirectory && f.name.startsWith('backup'))
          .toList();

      // 按文件名排序（倒序，最新的在前）
      backupFiles.sort((a, b) => b.name.compareTo(a.name));

      return backupFiles.map((f) => f.name).toList();
    } catch (e) {
      AppLog.instance.put('获取备份文件名列表失败', error: e);
      rethrow;
    }
  }

  /// 检查备份是否存在
  /// 参考项目：AppWebDav.hasBackUp()
  Future<bool> hasBackup(String backupName) async {
    if (!isConfigured) return false;

    try {
      return await exists(backupName);
    } catch (e) {
      return false;
    }
  }

  /// 获取最后备份文件
  /// 参考项目：AppWebDav.lastBackUp()
  Future<WebDavFile?> getLastBackup() async {
    if (!isConfigured) return null;

    try {
      final files = await listFiles();
      WebDavFile? lastBackupFile;

      // 遍历所有文件，找到最新的备份文件
      // 参考项目使用 reversed() 遍历，这里直接遍历并比较时间
      for (final file in files) {
        if (!file.isDirectory && file.name.startsWith('backup')) {
          if (lastBackupFile == null ||
              file.lastModified.isAfter(lastBackupFile.lastModified)) {
            lastBackupFile = file;
          }
        }
      }

      return lastBackupFile;
    } catch (e) {
      AppLog.instance.put('获取最后备份失败', error: e);
      return null;
    }
  }

  /// 检查是否是坚果云
  /// 参考项目：AppWebDav.isJianGuoYun
  bool get isJianGuoYun {
    final url = rootUrl.toLowerCase();
    return url.startsWith('https://dav.jianguoyun.com/dav/');
  }
}

