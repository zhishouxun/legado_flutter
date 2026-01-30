import 'dart:typed_data';
import 'dart:convert';
import '../data/models/book.dart';
import '../data/models/book_source.dart';
import '../data/models/rss_source.dart';
import '../data/models/interfaces/base_source.dart';
import '../utils/js_engine.dart';
import '../utils/app_log.dart';

/// 图片解密工具类
/// 参考项目：io.legado.app.utils.ImageUtils.kt
class ImageUtils {
  ImageUtils._();

  /// 解密图片（从字节数组）
  /// 参考项目：ImageUtils.decode(bytes: ByteArray)
  /// 
  /// [src] 图片URL
  /// [bytes] 待解密的图片字节数组
  /// [isCover] 是否为封面图片（决定使用哪个解密规则）
  /// [source] 书源或RSS源
  /// [book] 书籍对象（可选）
  /// 返回解密后的字节数组，解密失败或无需解密则返回原字节数组
  static Future<Uint8List?> decode(
    String src,
    List<int> bytes,
    bool isCover,
    BaseSource? source,
    Book? book,
  ) async {
    final ruleJs = _getRuleJs(source, isCover);
    if (ruleJs == null || ruleJs.isEmpty) {
      return Uint8List.fromList(bytes);
    }

    try {
      // 执行JavaScript解密规则
      // 参考项目：source?.evalJS(ruleJs) { put("book", book); put("result", bytes); put("src", src) }
      final bindings = <String, dynamic>{
        'book': book,
        'result': Uint8List.fromList(bytes),
        'src': src,
      };

      // 添加 java 对象（支持加密解密等操作）
      // 注意：需要在 JSEngine 中注册 java 对象
      final result = await JSEngine.evalJS(ruleJs, bindings: bindings);

      // 处理返回结果
      if (result == null) {
        return null;
      }

      // 如果返回的是字符串，尝试解析为字节数组
      if (result is String) {
        // 可能是Base64编码
        try {
          return Uint8List.fromList(base64Decode(result));
        } catch (e) {
          // 不是Base64，返回null
          return null;
        }
      }

      // 如果返回的是List<int>或Uint8List，直接使用
      if (result is List<int>) {
        return Uint8List.fromList(result);
      }
      if (result is Uint8List) {
        return result;
      }

      // 其他类型，返回null
      return null;
    } catch (e) {
      AppLog.instance.put('图片解密错误: $src', error: e);
      return null;
    }
  }

  /// 解密图片（从输入流）
  /// 参考项目：ImageUtils.decode(inputStream: InputStream)
  /// 
  /// 注意：Flutter中没有InputStream，这里简化为从字节数组解密
  /// 如果需要从流解密，可以先读取流为字节数组，然后调用 decode(bytes) 方法
  static Future<Uint8List?> decodeFromStream(
    String src,
    Stream<List<int>> stream,
    bool isCover,
    BaseSource? source,
    Book? book,
  ) async {
    // 将流转换为字节数组
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return decode(src, bytes, isCover, source, book);
  }

  /// 跳过解密检查
  /// 参考项目：ImageUtils.skipDecode()
  static bool skipDecode(BaseSource? source, bool isCover) {
    final ruleJs = _getRuleJs(source, isCover);
    return ruleJs == null || ruleJs.isEmpty;
  }

  /// 获取解密规则JavaScript代码
  /// 参考项目：ImageUtils.getRuleJs()
  static String? _getRuleJs(BaseSource? source, bool isCover) {
    if (source == null) return null;

    // 使用类型检查来访问特定类型的属性
    if (source is BookSource) {
      final bookSource = source as BookSource;
      if (isCover) {
        return bookSource.coverDecodeJs;
      } else {
        // 获取内容规则中的图片解密规则
        final contentRule = bookSource.ruleContent;
        return contentRule?.imageDecode;
      }
    } else if (source is RssSource) {
      final rssSource = source as RssSource;
      return rssSource.coverDecodeJs;
    }

    return null;
  }
}

