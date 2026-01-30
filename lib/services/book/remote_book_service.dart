import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart' as xml;
import '../../core/base/base_service.dart';
import '../../data/models/remote_book.dart';
import '../../utils/app_log.dart';

/// 远程书籍服务 - 处理WebDAV连接和操作
class RemoteBookService extends BaseService {
  static final RemoteBookService instance = RemoteBookService._init();
  RemoteBookService._init();

  Dio? _dio;
  String? _baseUrl;
  String? _username;
  String? _password;

  /// 配置WebDAV连接
  void configure({
    required String baseUrl,
    String? username,
    String? password,
  }) {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _username = username;
    _password = password;

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl!,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // 设置认证
    if (_username != null && _password != null) {
      final auth = base64Encode(utf8.encode('$_username:$_password'));
      _dio!.options.headers['Authorization'] = 'Basic $auth';
    }
  }

  /// 检查是否已配置
  bool get isConfigured => _baseUrl != null && _dio != null;

  /// 获取远程书籍列表
  Future<List<RemoteBook>> getRemoteBookList(String path) async {
    if (!isConfigured) {
      throw Exception('WebDAV未配置');
    }

    try {
      // 构建完整路径
      final fullPath = path.startsWith('/') ? path : '/$path';

      // 发送PROPFIND请求
      final response = await _dio!.request(
        fullPath,
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
    <getcontenttype/>
  </prop>
</propfind>''',
      );

      // 解析XML响应
      final xmlDoc = xml.XmlDocument.parse(response.data.toString());
      final remoteBooks = <RemoteBook>[];

      // 解析每个文件/目录
      final responses = xmlDoc.findAllElements('response');
      for (final response in responses) {
        final href = response.findElements('href').firstOrNull?.text ?? '';
        if (href.isEmpty || href == fullPath || href == '$fullPath/') {
          continue; // 跳过当前目录本身
        }

        // 提取文件名
        final pathParts = href.split('/').where((p) => p.isNotEmpty).toList();
        final filename = pathParts.isNotEmpty ? pathParts.last : '';

        // 检查是否为目录
        final resourcetype = response.findElements('resourcetype').firstOrNull;
        final isDir = resourcetype?.findElements('collection').isNotEmpty ?? false;

        // 获取文件大小
        final contentLength = response.findElements('getcontentlength').firstOrNull?.text ?? '0';
        final size = int.tryParse(contentLength) ?? 0;

        // 获取最后修改时间
        final lastModified = response.findElements('getlastmodified').firstOrNull?.text ?? '';
        final lastModify = _parseLastModified(lastModified);

        // 获取内容类型
        final contentType = response.findElements('getcontenttype').firstOrNull?.text ?? 
            (isDir ? 'folder' : 'application/octet-stream');

        // 只添加目录或书籍文件
        if (isDir || _isBookFile(filename)) {
          remoteBooks.add(RemoteBook(
            filename: filename,
            path: href,
            size: size,
            lastModify: lastModify,
            contentType: contentType,
          ));
        }
      }

      return remoteBooks;
    } catch (e) {
      AppLog.instance.put('获取远程书籍列表失败', error: e);
      rethrow;
    }
  }

  /// 下载远程书籍
  Future<List<int>> downloadRemoteBook(RemoteBook remoteBook) async {
    if (!isConfigured) {
      throw Exception('WebDAV未配置');
    }

    try {
      final response = await _dio!.get<List<int>>(
        remoteBook.path,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      return response.data ?? [];
    } catch (e) {
      AppLog.instance.put('下载远程书籍失败: ${remoteBook.filename}', error: e);
      rethrow;
    }
  }

  /// 判断是否为书籍文件
  bool _isBookFile(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return ['txt', 'epub', 'pdf', 'mobi', 'azw', 'azw3', 'fb2', 'zip', 'rar', '7z'].contains(ext);
  }

  /// 解析最后修改时间
  int _parseLastModified(String lastModified) {
    if (lastModified.isEmpty) return DateTime.now().millisecondsSinceEpoch;
    
    try {
      // WebDAV时间格式: "Wed, 01 Jan 2020 12:00:00 GMT"
      final dateTime = DateTime.parse(lastModified);
      return dateTime.millisecondsSinceEpoch;
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }
}

