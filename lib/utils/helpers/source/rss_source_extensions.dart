import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/rss_source.dart';
import '../../../utils/app_log.dart';
import '../../../utils/js_engine.dart';
import '../../../utils/network_utils.dart';

/// RSS 源扩展方法
/// 参考项目：io.legado.app.help.source.RssSourceExtensions
extension RssSourceExtensions on RssSource {
  /// 获取缓存 key
  String _getSortUrlsKey() {
    final key = '$sourceUrl${sortUrl ?? ''}';
    final bytes = utf8.encode(key);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 获取分类 URL 列表
  /// 参考项目：RssSource.sortUrls()
  ///
  /// 返回分类名称和 URL 的配对列表
  Future<List<MapEntry<String, String>>> sortUrls() async {
    if (sortUrl == null || sortUrl!.isEmpty) {
      return [MapEntry('', sourceUrl)];
    }

    try {
      var str = sortUrl!;
      
      // 检查是否是 JavaScript 代码
      if (str.startsWith('<js>', 0) || str.startsWith('@js:', 0)) {
        final sortUrlsKey = _getSortUrlsKey();
        final prefs = await SharedPreferences.getInstance();
        
        // 先检查持久化缓存
        final cachedResult = prefs.getString('rssSortUrl_$sortUrlsKey');
        if (cachedResult != null && cachedResult.isNotEmpty) {
          str = cachedResult;
        } else {
          // 执行 JavaScript
          String jsStr;
          if (str.startsWith('@js:')) {
            jsStr = str.substring(4);
          } else {
            // <js>...</js> 格式
            final startIndex = str.indexOf('<js>') + 4;
            final endIndex = str.lastIndexOf('<');
            if (endIndex > startIndex) {
              jsStr = str.substring(startIndex, endIndex);
            } else {
              jsStr = str.substring(startIndex);
            }
          }
          
          try {
            final result = await JSEngine.evalJS(jsStr);
            str = result?.toString() ?? '';
            
            // 缓存结果
            if (str.isNotEmpty) {
              await prefs.setString('rssSortUrl_$sortUrlsKey', str);
            }
          } catch (e) {
            AppLog.instance.put('执行 RSS 分类 URL JavaScript 失败', error: e);
            return [MapEntry('', sourceUrl)];
          }
        }
      }

      // 解析分类 URL（使用 && 或换行符分割）
      final results = <MapEntry<String, String>>[];
      final lines = str.split(RegExp(r'(&&|\n)+'));
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final parts = trimmed.split('::');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          var url = parts[1].trim();
          
          // 如果是模板变量（{{...}}），直接使用
          if (url.startsWith('{{')) {
            results.add(MapEntry(name, url));
          } else {
            // 转换为绝对 URL
            url = NetworkUtils.getAbsoluteURL(sourceUrl, url);
            results.add(MapEntry(name, url));
          }
        }
      }

      // 如果没有结果，返回默认 URL
      if (results.isEmpty) {
        results.add(MapEntry('', sourceUrl));
      }

      return results;
    } catch (e) {
      AppLog.instance.put('获取 RSS 分类 URL 失败', error: e);
      return [MapEntry('', sourceUrl)];
    }
  }

  /// 清除分类 URL 缓存
  /// 参考项目：RssSource.removeSortCache()
  Future<void> removeSortCache() async {
    try {
      final sortUrlsKey = _getSortUrlsKey();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rssSortUrl_$sortUrlsKey');
    } catch (e) {
      AppLog.instance.put('清除 RSS 分类 URL 缓存失败', error: e);
    }
  }
}

