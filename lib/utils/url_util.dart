import 'dart:io';
import 'app_log.dart';

/// URL工具类
/// 参考项目：UrlUtil.kt
class UrlUtil {
  // 不期望的文件后缀（如 php, html）
  static const List<String> _unExpectFileSuffixs = ['php', 'html'];

  /// 替换URL保留字符
  /// 参考项目：UrlUtil.replaceReservedChar
  static String replaceReservedChar(String text) {
    return text
        .replaceAll('%', '%25')
        .replaceAll(' ', '%20')
        .replaceAll('"', '%22')
        .replaceAll('#', '%23')
        .replaceAll('&', '%26')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29')
        .replaceAll('+', '%2B')
        .replaceAll(',', '%2C')
        .replaceAll('/', '%2F')
        .replaceAll(':', '%3A')
        .replaceAll(';', '%3B')
        .replaceAll('<', '%3C')
        .replaceAll('=', '%3D')
        .replaceAll('>', '%3E')
        .replaceAll('?', '%3F')
        .replaceAll('@', '%40')
        .replaceAll('\\', '%5C')
        .replaceAll('|', '%7C');
  }

  /// 根据网络url获取文件信息 文件名
  /// 参考项目：UrlUtil.getFileName
  static Future<String?> getFileName(
    String fileUrl, {
    Map<String, String>? headerMap,
  }) async {
    try {
      final uri = Uri.parse(fileUrl);
      var fileName = _getFileNameFromPath(uri);
      fileName ??= await _getFileNameFromResponseHeader(uri, headerMap);
      return fileName;
    } catch (e) {
      AppLog.instance.put('getFileName error: $e');
      return null;
    }
  }

  /// 从响应头获取文件名
  /// 参考项目：UrlUtil.getFileNameFromResponseHeader
  static Future<String?> _getFileNameFromResponseHeader(
    Uri url,
    Map<String, String>? headerMap,
  ) async {
    try {
      // 使用 HEAD 请求获取响应头
      final client = HttpClient();
      try {
        final request = await client.openUrl('HEAD', url);

        // 添加自定义请求头
        if (headerMap != null) {
          headerMap.forEach((key, value) {
            request.headers.set(key, value);
          });
        }

        // 禁止重定向
        request.followRedirects = false;

        final response = await request.close();

        // 获取 Content-Disposition 头
        final contentDisposition =
            response.headers.value('content-disposition');
        // 获取 Location 头（重定向）
        final redirectUrl = response.headers.value('location');

        if (contentDisposition != null) {
          // 解析 Content-Disposition
          final fileNames = contentDisposition
              .split(RegExp(r'[;,]'))
              .where((part) => part.toLowerCase().contains('filename'))
              .toList();

          final names = <String>{};
          for (final part in fileNames) {
            var fileName =
                part.split('=').length > 1 ? part.split('=')[1].trim() : '';

            // 移除引号
            if (fileName.startsWith('"') || fileName.startsWith("'")) {
              fileName = fileName.substring(1);
            }
            if (fileName.endsWith('"') || fileName.endsWith("'")) {
              fileName = fileName.substring(0, fileName.length - 1);
            }

            if (part.toLowerCase().contains('filename*')) {
              // 处理 filename*=charset''filename 格式
              final data = fileName.split("''");
              if (data.length >= 2) {
                // final charset = data[0]; // 字符集，暂时不使用
                final encodedName = data[1];
                try {
                  // URL 解码
                  fileName = Uri.decodeComponent(encodedName);
                } catch (e) {
                  fileName = encodedName;
                }
              }
            }

            if (fileName.isNotEmpty) {
              names.add(fileName);
            }
          }

          if (names.isNotEmpty) {
            return names.first;
          }
        } else if (redirectUrl != null) {
          // 处理重定向
          final decodedUrl = Uri.decodeComponent(redirectUrl);
          final newUri = Uri.parse(decodedUrl);
          return _getFileNameFromPath(newUri);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      AppLog.instance.put('getFileNameFromResponseHeader error: $e');
    }
    return null;
  }

  /// 从路径获取文件名
  /// 参考项目：UrlUtil.getFileNameFromPath
  static String? _getFileNameFromPath(Uri uri) {
    try {
      final path = uri.path;
      if (path.isEmpty) return null;

      final suffix = getSuffix(path, '');
      if (suffix.isNotEmpty && !_unExpectFileSuffixs.contains(suffix)) {
        // 获取路径的最后一部分
        final parts = path.split('/');
        if (parts.isNotEmpty) {
          return parts.last;
        }
      }
    } catch (e) {
      AppLog.instance.put('getFileNameFromPath error: $e');
    }
    return null;
  }

  /// 获取合法的文件后缀
  /// 参考项目：UrlUtil.getSuffix
  static String getSuffix(String str, String? defaultSuffix) {
    try {
      final uri = Uri.parse(str);
      var path = uri.path;

      // 移除查询参数和锚点
      path = path.split('?').first.split('#').first;

      // 获取最后一个点之后的部分
      final lastDotIndex = path.lastIndexOf('.');
      if (lastDotIndex == -1 || lastDotIndex == path.length - 1) {
        if (defaultSuffix == null) {
          AppLog.instance.put('Cannot find legal suffix: $str');
        }
        return defaultSuffix ?? 'ext';
      }

      final suffix = path.substring(lastDotIndex + 1).toLowerCase();

      // 检查后缀是否合法 [a-zA-Z0-9]，长度不超过5
      final suffixRegex = RegExp(r'^[a-z0-9]+$', caseSensitive: false);
      if (suffix.length > 5 || !suffixRegex.hasMatch(suffix)) {
        if (defaultSuffix == null) {
          AppLog.instance
              .put('Cannot find legal suffix: target=$str, suffix=$suffix');
        }
        return defaultSuffix ?? 'ext';
      }

      return suffix;
    } catch (e) {
      AppLog.instance.put('getSuffix error: $e');
      return defaultSuffix ?? 'ext';
    }
  }
}
