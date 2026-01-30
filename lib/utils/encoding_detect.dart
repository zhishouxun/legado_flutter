import 'dart:io';
import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;
import 'app_log.dart';

/// 编码检测工具类
/// 参考项目：EncodingDetect.kt
class EncodingDetect {
  static final RegExp _headTagRegex = RegExp(r'(?i)<head>[\s\S]*?</head>');
  static final List<int> _headOpenBytes = '<head>'.codeUnits;
  static final List<int> _headCloseBytes = '</head>'.codeUnits;

  /// 从HTML中检测编码
  /// 参考项目：EncodingDetect.getHtmlEncode
  static String getHtmlEncode(Uint8List bytes) {
    try {
      String? head;
      
      // 查找 <head> 标签
      final startIndex = _indexOf(bytes, _headOpenBytes);
      if (startIndex > -1) {
        final endIndex = _indexOf(bytes, _headCloseBytes, startIndex);
        if (endIndex > -1) {
          // 提取 head 部分
          final headBytes = bytes.sublist(startIndex, endIndex + _headCloseBytes.length);
          head = String.fromCharCodes(headBytes);
        }
      }

      // 如果没有找到，尝试使用正则表达式
      if (head == null) {
        try {
          final htmlText = String.fromCharCodes(bytes);
          final match = _headTagRegex.firstMatch(htmlText);
          if (match != null) {
            head = match.group(0);
          }
        } catch (e) {
          // 忽略错误
        }
      }

      if (head != null) {
        // 解析HTML
        final document = html_parser.parse(head);
        final metaTags = document.querySelectorAll('meta');

        for (final metaTag in metaTags) {
          // 检查 charset 属性
          final charset = metaTag.attributes['charset'];
          if (charset != null && charset.isNotEmpty) {
            return charset;
          }

          // 检查 http-equiv="content-type"
          final httpEquiv = metaTag.attributes['http-equiv'];
          if (httpEquiv != null &&
              httpEquiv.toLowerCase() == 'content-type') {
            final content = metaTag.attributes['content'] ?? '';
            final charsetIndex = content.toLowerCase().indexOf('charset=');
            if (charsetIndex > -1) {
              final charsetStr = content
                  .substring(charsetIndex + 'charset='.length)
                  .split(';')
                  .first
                  .trim();
              if (charsetStr.isNotEmpty) {
                return charsetStr;
              }
            }
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('EncodingDetect.getHtmlEncode error: $e');
    }

    // 如果HTML解析失败，使用通用编码检测
    return getEncode(bytes);
  }

  /// 检测编码
  /// 参考项目：EncodingDetect.getEncode
  static String getEncode(Uint8List bytes) {
    try {
      // 使用 charset_converter 包检测编码
      // 注意：charset_converter 可能不直接支持编码检测
      // 这里使用简化的检测逻辑
      
      // 检查UTF-8 BOM
      if (bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        return 'UTF-8';
      }

      // 检查UTF-16 BOM
      if (bytes.length >= 2) {
        if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
          return 'UTF-16BE';
        }
        if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
          return 'UTF-16LE';
        }
      }

      // 尝试检测常见的中文编码
      // 这里使用简化的检测逻辑，实际应该使用更完善的编码检测库
      if (_isLikelyGBK(bytes)) {
        return 'GBK';
      }
      if (_isLikelyBig5(bytes)) {
        return 'Big5';
      }

      // 默认返回UTF-8
      return 'UTF-8';
    } catch (e) {
      AppLog.instance.put('EncodingDetect.getEncode error: $e');
      return 'UTF-8';
    }
  }

  /// 检测文件编码
  /// 参考项目：EncodingDetect.getEncode(File)
  static Future<String> getEncodeFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return 'UTF-8';
      }
      final bytes = await _getFileBytes(file);
      if (bytes.isEmpty) {
        return 'UTF-8';
      }
      return getEncode(bytes);
    } catch (e) {
      AppLog.instance.put('EncodingDetect.getEncodeFromFile error: $e');
      return 'UTF-8';
    }
  }

  /// 获取文件的前几个字节（用于编码检测）
  /// 参考项目：EncodingDetect.getFileBytes
  static Future<Uint8List> _getFileBytes(File file) async {
    try {
      final bytes = <int>[];
      final stream = file.openRead();
      int pos = 0;
      const maxBytes = 8000;

      await for (final chunk in stream) {
        for (final byte in chunk) {
          if (pos >= maxBytes) break;
          if (byte < 0) {
            // 只处理非ASCII字符
            bytes.add(byte);
            pos++;
          }
          if (pos >= maxBytes) break;
        }
        if (pos >= maxBytes) break;
      }

      return Uint8List.fromList(bytes);
    } catch (e) {
      AppLog.instance.put('EncodingDetect._getFileBytes error: $e');
      return Uint8List(0);
    }
  }

  /// 在字节数组中查找子数组
  static int _indexOf(Uint8List bytes, List<int> pattern, [int start = 0]) {
    if (pattern.isEmpty) return start;
    if (start + pattern.length > bytes.length) return -1;

    for (int i = start; i <= bytes.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  /// 简单检测是否可能是GBK编码
  static bool _isLikelyGBK(Uint8List bytes) {
    // 简化实现：检查是否包含GBK编码的常见字节模式
    // 实际应该使用更完善的检测算法
    int gbkCount = 0;
    for (int i = 0; i < bytes.length - 1 && i < 1000; i++) {
      final byte1 = bytes[i];
      final byte2 = bytes[i + 1];
      // GBK编码范围：0x81-0xFE, 0x40-0xFE
      if (byte1 >= 0x81 && byte1 <= 0xFE && byte2 >= 0x40 && byte2 <= 0xFE) {
        gbkCount++;
      }
    }
    return gbkCount > 10; // 如果找到足够多的GBK模式，可能是GBK编码
  }

  /// 简单检测是否可能是Big5编码
  static bool _isLikelyBig5(Uint8List bytes) {
    // 简化实现：检查是否包含Big5编码的常见字节模式
    int big5Count = 0;
    for (int i = 0; i < bytes.length - 1 && i < 1000; i++) {
      final byte1 = bytes[i];
      final byte2 = bytes[i + 1];
      // Big5编码范围：0xA1-0xFE, 0x40-0x7E 或 0xA1-0xFE
      if (byte1 >= 0xA1 &&
          byte1 <= 0xFE &&
          ((byte2 >= 0x40 && byte2 <= 0x7E) ||
              (byte2 >= 0xA1 && byte2 <= 0xFE))) {
        big5Count++;
      }
    }
    return big5Count > 10; // 如果找到足够多的Big5模式，可能是Big5编码
  }
}

