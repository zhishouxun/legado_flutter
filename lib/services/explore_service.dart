import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/base/base_service.dart';
import '../data/models/book_source.dart';
import '../data/models/book_source_rule.dart';
import '../data/models/explore_kind.dart';
import '../utils/app_log.dart';
import '../utils/parsers/rule_parser.dart';
import '../utils/js_engine.dart';
import '../utils/js_extensions.dart';
import 'network/network_service.dart' show NetworkService, NetworkError;

/// 发现服务
/// 参考项目：BookSourceExtensions.kt
class ExploreService extends BaseService {
  static final ExploreService instance = ExploreService._init();
  ExploreService._init();

  // 内存缓存发现分类（参考项目：exploreKindsMap）
  final Map<String, List<ExploreKind>> _exploreKindsCache = {};
  
  // 并发控制（参考项目：mutexMap）
  final Map<String, Completer<List<ExploreKind>>> _loadingCompleters = {};
  
  // SharedPreferences 用于持久化缓存（参考项目：ACache）
  SharedPreferences? _prefs;

  /// 初始化 SharedPreferences
  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 获取缓存key（参考项目：getExploreKindsKey，使用MD5）
  String _getExploreKindsKey(BookSource bookSource) {
    final key = '${bookSource.bookSourceUrl}${bookSource.exploreUrl}';
    final bytes = utf8.encode(key);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 获取发现分类列表
  /// 参考项目：BookSource.exploreKinds()
  Future<List<ExploreKind>> getExploreKinds(BookSource bookSource) async {
    if (bookSource.exploreUrl == null || bookSource.exploreUrl!.isEmpty) {
      AppLog.instance.put('书源 ${bookSource.bookSourceName} 的发现URL为空');
      return [];
    }

    final exploreKindsKey = _getExploreKindsKey(bookSource);
    
    // 检查内存缓存（参考项目：exploreKindsMap）
    if (_exploreKindsCache.containsKey(exploreKindsKey)) {
      final cached = _exploreKindsCache[exploreKindsKey]!;
      AppLog.instance.put(
          '使用内存缓存的发现分类: ${bookSource.bookSourceName}, 分类数: ${cached.length}');
      return cached;
    }

    // 并发控制：如果正在加载，等待加载完成（参考项目：mutex.withLock）
    if (_loadingCompleters.containsKey(exploreKindsKey)) {
      AppLog.instance.put('等待其他请求完成: ${bookSource.bookSourceName}');
      return await _loadingCompleters[exploreKindsKey]!.future;
    }

    // 创建 Completer 用于并发控制
    final completer = Completer<List<ExploreKind>>();
    _loadingCompleters[exploreKindsKey] = completer;

    try {
      final exploreUrl = bookSource.exploreUrl!;
      List<ExploreKind> kinds = [];

      AppLog.instance.put(
          '解析发现分类: ${bookSource.bookSourceName}, exploreUrl长度: ${exploreUrl.length}');

      // 参考项目：先检查是否是 HTTP URL，需要请求后解析
      // 如果 exploreUrl 是 HTTP URL，需要请求 HTML 并使用 exploreScreen 规则解析分类
      if (exploreUrl.startsWith('http://') || exploreUrl.startsWith('https://')) {
        try {
          AppLog.instance.put('exploreUrl 是 HTTP URL，需要请求并解析: ${bookSource.bookSourceName}');
          
          // 构建完整URL
          final fullUrl = NetworkService.joinUrl(bookSource.bookSourceUrl, exploreUrl);
          
          // 发送请求
          final headers = _getHeaders(bookSource);
          headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
          headers['Pragma'] = 'no-cache';
          headers['Expires'] = '0';
          
          final response = await NetworkService.instance.get(
            fullUrl,
            headers: headers,
            retryCount: 1,
            options: Options(
              extra: {'noCache': true},
              responseType: ResponseType.bytes,
            ),
          );
          
          final html = await NetworkService.getResponseText(response);
          
          if (html.isEmpty) {
            AppLog.instance.put('请求 exploreUrl 返回空内容: ${bookSource.bookSourceName}');
            completer.complete([]);
            return [];
          }
          
          // 使用 exploreScreen 规则解析分类列表
          // 参考项目：exploreScreen 规则用于从 HTML 中解析分类链接
          if (bookSource.exploreScreen != null && bookSource.exploreScreen!.isNotEmpty) {
            AppLog.instance.put('使用 exploreScreen 规则解析分类: ${bookSource.bookSourceName}, 规则=${bookSource.exploreScreen}');
            
            // 使用 RuleParser 解析分类链接
            // exploreScreen 规则应该返回链接列表，格式通常是 "a@text&&a@href"
            // 或者直接是选择器，返回链接元素的文本和 href
            try {
              // 解析分类链接列表
              // 参考项目：exploreScreen 规则通常返回链接元素列表
              // 格式可能是：选择器@text&&选择器@href 或 选择器（返回链接元素）
              final screenRule = bookSource.exploreScreen!;
              
              // 如果规则包含 &&，说明是组合规则（文本和链接分开）
              if (screenRule.contains('&&')) {
                final parts = screenRule.split('&&');
                if (parts.length >= 2) {
                  // 第一部分是文本选择器，第二部分是链接选择器
                  final textRule = parts[0].trim();
                  final urlRule = parts[1].trim();
                  
                  // 解析文本列表
                  final textList = RuleParser.parseListRule(html, textRule, baseUrl: fullUrl);
                  // 解析链接列表
                  final urlList = RuleParser.parseListRule(html, urlRule, baseUrl: fullUrl);
                  
                  // 合并文本和链接
                  final maxLength = textList.length > urlList.length ? textList.length : urlList.length;
                  for (int i = 0; i < maxLength; i++) {
                    final title = i < textList.length ? textList[i].trim() : '';
                    final url = i < urlList.length ? urlList[i].trim() : null;
                    if (title.isNotEmpty) {
                      kinds.add(ExploreKind(
                        title: title,
                        url: url?.isNotEmpty == true ? url : null,
                      ));
                    }
                  }
                }
              } else {
                // 单个规则，尝试解析链接元素
                // 如果规则包含 @text 或 @href，说明是属性选择器
                if (screenRule.contains('@text') || screenRule.contains('@href')) {
                  // 属性选择器，直接解析
                  final linkList = RuleParser.parseListRule(html, screenRule, baseUrl: fullUrl);
                  for (final link in linkList) {
                    if (link.trim().isNotEmpty) {
                      kinds.add(ExploreKind(
                        title: link.trim(),
                        url: link.trim(),
                      ));
                    }
                  }
                } else {
                  // 普通选择器，尝试获取链接元素的文本和 href
                  // 先获取链接元素列表
                  final linkElements = RuleParser.parseListRule(html, screenRule, baseUrl: fullUrl, returnHtml: true);
                  for (final linkHtml in linkElements) {
                    // 从链接 HTML 中提取文本和 href
                    final text = await RuleParser.parseRuleAsync(linkHtml, '@text', baseUrl: fullUrl);
                    final href = await RuleParser.parseRuleAsync(linkHtml, '@href', baseUrl: fullUrl);
                    if (text != null && text.trim().isNotEmpty) {
                      kinds.add(ExploreKind(
                        title: text.trim(),
                        url: href?.trim().isNotEmpty == true ? href!.trim() : null,
                      ));
                    }
                  }
                }
              }
              
              AppLog.instance.put('使用 exploreScreen 规则解析分类成功: ${bookSource.bookSourceName}, 分类数: ${kinds.length}');
            } catch (e) {
              AppLog.instance.put('使用 exploreScreen 规则解析分类失败: ${bookSource.bookSourceName}', error: e);
              completer.complete([ExploreKind(
                title: 'ERROR:解析失败 ${e.toString()}',
                url: e.toString(),
              )]);
              return completer.future;
            }
          } else {
            AppLog.instance.put('exploreScreen 规则为空，无法解析分类: ${bookSource.bookSourceName}');
            completer.complete([]);
            return [];
          }
        } catch (e) {
          AppLog.instance.put('请求 exploreUrl 失败: ${bookSource.bookSourceName}', error: e);
          completer.complete([ExploreKind(
            title: 'ERROR:${e.toString()}',
            url: e.toString(),
          )]);
          return completer.future;
        }
      }

      // 参考项目：先检查是否是 JavaScript 代码
      var ruleStr = exploreUrl;
      if (exploreUrl.startsWith('<js>', 0) ||
          exploreUrl.startsWith('@js:', 0)) {
        // JavaScript 代码，需要执行
        await _initPrefs();
        
        // 先检查持久化缓存（参考项目：aCache.getAsString）
        final cachedResult = _prefs!.getString('explore_$exploreKindsKey');
        if (cachedResult != null && cachedResult.isNotEmpty) {
          AppLog.instance.put('使用持久化缓存的JavaScript执行结果: ${bookSource.bookSourceName}');
          ruleStr = cachedResult;
        } else {
          // 执行 JavaScript（参考项目：runScriptWithContext）
          AppLog.instance.put('执行JavaScript发现规则: ${bookSource.bookSourceName}');
          try {
            String jsStr;
            if (exploreUrl.startsWith('@js:')) {
              jsStr = exploreUrl.substring(4);
            } else {
              // <js>...</js> 格式
              final startIndex = exploreUrl.indexOf('<js>') + 4;
              final endIndex = exploreUrl.lastIndexOf('</js>');
              if (endIndex > startIndex) {
                jsStr = exploreUrl.substring(startIndex, endIndex);
              } else {
                jsStr = exploreUrl.substring(4);
              }
            }

            // 执行 JavaScript（参考项目：evalJS）
            final extensions = JSExtensions(
              source: bookSource,
              baseUrl: bookSource.bookSourceUrl,
            );
            final jsBindings = extensions.createBindings();
            
            final jsResult = await JSEngine.evalJS(jsStr, bindings: jsBindings);
            ruleStr = jsResult.toString().trim();
            
            // 缓存执行结果（参考项目：aCache.put）
            await _prefs!.setString('explore_$exploreKindsKey', ruleStr);
            AppLog.instance.put('JavaScript执行成功，结果长度: ${ruleStr.length}');
          } catch (e) {
            AppLog.instance.put('JavaScript执行失败: ${bookSource.bookSourceName}', error: e);
            completer.complete([ExploreKind(
              title: 'ERROR:${e.toString()}',
              url: e.toString(),
            )]);
            _loadingCompleters.remove(exploreKindsKey);
            return completer.future;
          }
        }
      }

      // 解析规则字符串（参考项目逻辑）
      // 检查是否是 JSON 数组格式
      if (ruleStr.trim().startsWith('[')) {
        try {
          final List<dynamic> jsonList = jsonDecode(ruleStr);
          kinds = jsonList.map((item) {
            if (item is Map<String, dynamic>) {
              return ExploreKind.fromJson(item);
            } else if (item is String) {
              // 如果是字符串，尝试解析为 "title::url" 格式
              final parts = item.split('::');
              return ExploreKind(
                title: parts.isNotEmpty ? parts[0] : '',
                url: parts.length > 1 ? parts[1] : null,
              );
            }
            return ExploreKind(title: item.toString());
          }).toList();
          AppLog.instance.put(
              '解析JSON格式发现分类成功: ${bookSource.bookSourceName}, 分类数: ${kinds.length}');
        } catch (e) {
          AppLog.instance
              .put('解析发现分类 JSON 失败: ${bookSource.bookSourceName}', error: e);
        }
      } else {
        // 文本格式：每行一个分类，格式为 "title::url" 或 "title"
        // 参考项目：使用正则 (&&|\n)+ 分割
        final lines = ruleStr.split(RegExp(r'(&&|\n)+'));
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;

          final parts = trimmed.split('::');
          kinds.add(ExploreKind(
            title: parts.isNotEmpty ? parts[0].trim() : '',
            url: parts.length > 1 ? parts[1].trim() : null,
          ));
        }
        AppLog.instance.put(
            '解析文本格式发现分类成功: ${bookSource.bookSourceName}, 分类数: ${kinds.length}');
      }

      // 缓存结果到内存（参考项目：exploreKindsMap）
      _exploreKindsCache[exploreKindsKey] = kinds;
      
      completer.complete(kinds);
      return kinds;
    } catch (e) {
      final errorKinds = [ExploreKind(
        title: 'ERROR:${e.toString()}',
        url: e.toString(),
      )];
      completer.complete(errorKinds);
      AppLog.instance.put('获取发现分类失败: ${bookSource.bookSourceName}', error: e);
      return errorKinds;
    } finally {
      _loadingCompleters.remove(exploreKindsKey);
    }
  }

  /// 清除发现分类缓存
  /// 参考项目：BookSource.clearExploreKindsCache()
  Future<void> clearExploreKindsCache(BookSource bookSource) async {
    if (bookSource.exploreUrl == null || bookSource.exploreUrl!.isEmpty) {
      return;
    }
    final exploreKindsKey = _getExploreKindsKey(bookSource);
    
    // 清除内存缓存（参考项目：exploreKindsMap.remove）
    _exploreKindsCache.remove(exploreKindsKey);
    
    // 清除持久化缓存（参考项目：aCache.remove）
    await _initPrefs();
    await _prefs!.remove('explore_$exploreKindsKey');
    
    AppLog.instance.put('清除发现分类缓存: ${bookSource.bookSourceName}');
  }

  /// 获取发现书籍列表
  Future<List<Map<String, String?>>> exploreBooks(
    BookSource bookSource,
    String exploreUrl, {
    int page = 1,
  }) async {
    String fullUrl = exploreUrl;

    try {
      // 先替换分页变量（在URL解析之前）
      // 支持 {{page}} 格式和 <1,2,3> 格式
      if (fullUrl.contains('{{page}}')) {
        fullUrl = fullUrl.replaceAll('{{page}}', page.toString());
      } else if (fullUrl.contains('<') && fullUrl.contains('>')) {
        // 处理 <1,2,3> 格式的分页变量
        final pagePattern = RegExp(r'<([^>]+)>');
        fullUrl = fullUrl.replaceAllMapped(pagePattern, (match) {
          final pages = match.group(1)!.split(',');
          if (page <= pages.length) {
            return pages[page - 1].trim();
          } else {
            return pages.last.trim();
          }
        });
      }

      // 构建完整URL（处理相对路径）
      // 使用 NetworkService.joinUrl 来保持与参考项目一致
      // 即使URL是绝对的，也通过 joinUrl 来规范化（对于绝对URL，joinUrl 会直接返回）
      fullUrl = NetworkService.joinUrl(bookSource.bookSourceUrl, fullUrl);

      // 确保URL格式正确（移除末尾多余的斜杠，但保留路径中的斜杠）
      // 注意：某些URL可能需要末尾斜杠，所以这里不做处理

      // 发送请求（确保使用正确的请求头）
      final headers = _getHeaders(bookSource);
      // 确保禁用缓存
      headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      headers['Pragma'] = 'no-cache';
      headers['Expires'] = '0';

      // 记录到 AppLog
      AppLog.instance.put(
          'exploreBooks: 请求URL=$fullUrl, 页码=$page, 请求头数量=${headers.length}');

      final response = await NetworkService.instance.get(
        fullUrl,
        headers: headers,
        retryCount: 1,
        options: Options(
          // 禁用缓存
          extra: {'noCache': true},
          // 确保返回原始字节，以便手动处理编码
          responseType: ResponseType.bytes,
        ),
      );

      final html = await NetworkService.getResponseText(response);
      
      // 记录到 AppLog
      AppLog.instance.put(
          'exploreBooks: 响应状态码=${response.statusCode}, 内容长度=${html.length}, URL=$fullUrl');

      if (html.isEmpty) {
        return [];
      }

      // 解析发现规则
      // 参考项目逻辑：如果发现规则的bookList为空，使用搜索规则
      ExploreRule? ruleToUse = bookSource.ruleExplore;
      if (ruleToUse == null ||
          ruleToUse.bookList == null ||
          ruleToUse.bookList!.isEmpty) {
        AppLog.instance.put(
            'exploreBooks: 发现规则为空或bookList为空, 尝试使用搜索规则 (书源: ${bookSource.bookSourceName})');
        // 如果发现规则为空或bookList为空，尝试使用搜索规则
        if (bookSource.ruleSearch != null &&
            bookSource.ruleSearch!.bookList != null) {
          AppLog.instance.put(
              'exploreBooks: 使用搜索规则解析发现书籍 (书源: ${bookSource.bookSourceName}, bookList=${bookSource.ruleSearch!.bookList})');
          // 使用搜索规则解析，但传入的是发现URL
          final results = await RuleParser.parseSearchRule(html, bookSource.ruleSearch!,
              baseUrl: fullUrl);
          AppLog.instance.put(
              'exploreBooks: 使用搜索规则解析完成, 找到 ${results.length} 本书籍 (书源: ${bookSource.bookSourceName})');
          return results;
        } else {
          AppLog.instance.put(
              'exploreBooks: 搜索规则也为空, 返回空列表 (书源: ${bookSource.bookSourceName})');
          return [];
        }
      }

      // 使用 RuleParser 解析
      // 使用实际请求的URL作为baseUrl（参考项目中的做法）
      try {
        AppLog.instance.put(
            'exploreBooks: 使用发现规则解析书籍列表 (书源: ${bookSource.bookSourceName}, bookList=${ruleToUse.bookList}, HTML长度=${html.length})');
        final results = await _parseExploreBooks(html, ruleToUse, fullUrl);
        AppLog.instance.put(
            'exploreBooks: 解析完成, 找到 ${results.length} 本书籍 (书源: ${bookSource.bookSourceName})');
        return results;
      } catch (e) {
        final errorMsg =
            '解析发现书籍列表失败: $e (书源: ${bookSource.bookSourceName}, URL: $fullUrl)';
        AppLog.instance.put(errorMsg, error: e);
        throw Exception(errorMsg);
      }
    } on NetworkError catch (e) {
      final errorMsg =
          '网络请求失败: ${e.message} (书源: ${bookSource.bookSourceName}, 原始URL: $exploreUrl, 处理后URL: $fullUrl)';
      throw Exception(errorMsg);
    } catch (e) {
      final errorMsg =
          '获取发现书籍列表失败: $e (书源: ${bookSource.bookSourceName}, 原始URL: $exploreUrl, 处理后URL: $fullUrl)';
      throw Exception(errorMsg);
    }
  }

  /// 解析发现书籍列表
  Future<List<Map<String, String?>>> _parseExploreBooks(
    String html,
    ExploreRule rule,
    String baseUrl,
  ) async {
    return await RuleParser.parseExploreRule(html, rule, baseUrl: baseUrl);
  }

  /// 获取请求头（参考 BaseSource.getHeaderMap）
  Map<String, String> _getHeaders(BookSource bookSource) {
    final headers = <String, String>{};

    // 解析书源的 header 配置
    if (bookSource.header != null && bookSource.header!.isNotEmpty) {
      var headerString = bookSource.header!.trim();

      // 如果 headerString 是一个 JSON 字符串（被引号包裹），先去掉外层引号
      if (headerString.startsWith('"') && headerString.endsWith('"')) {
        try {
          headerString = jsonDecode(headerString) as String;
        } catch (e) {
          // 如果解析失败，继续使用原始字符串
        }
      }

      // 首先尝试 JSON 格式解析
      try {
        final headerJson = jsonDecode(headerString);
        if (headerJson is Map<String, dynamic>) {
          headerJson.forEach((key, value) {
            // 清理键名：移除引号和其他无效字符
            var cleanKey = key.trim();
            if (cleanKey.startsWith('"') && cleanKey.endsWith('"')) {
              cleanKey = cleanKey.substring(1, cleanKey.length - 1);
            } else if (cleanKey.startsWith("'") && cleanKey.endsWith("'")) {
              cleanKey = cleanKey.substring(1, cleanKey.length - 1);
            }
            if (cleanKey.isNotEmpty) {
              // 清理值：移除引号（如果存在）
              var cleanValue = value.toString().trim();
              if (cleanValue.startsWith('"') && cleanValue.endsWith('"')) {
                cleanValue = cleanValue.substring(1, cleanValue.length - 1);
              } else if (cleanValue.startsWith("'") &&
                  cleanValue.endsWith("'")) {
                cleanValue = cleanValue.substring(1, cleanValue.length - 1);
              }
              headers[cleanKey] = cleanValue;
            }
          });
        } else if (headerJson is String) {
          // 如果解析后仍然是字符串，尝试再次解析
          try {
            final nestedJson = jsonDecode(headerJson);
            if (nestedJson is Map<String, dynamic>) {
              nestedJson.forEach((key, value) {
                var cleanKey = key.trim();
                if (cleanKey.startsWith('"') && cleanKey.endsWith('"')) {
                  cleanKey = cleanKey.substring(1, cleanKey.length - 1);
                } else if (cleanKey.startsWith("'") && cleanKey.endsWith("'")) {
                  cleanKey = cleanKey.substring(1, cleanKey.length - 1);
                }
                if (cleanKey.isNotEmpty) {
                  var cleanValue = value.toString().trim();
                  if (cleanValue.startsWith('"') && cleanValue.endsWith('"')) {
                    cleanValue = cleanValue.substring(1, cleanValue.length - 1);
                  } else if (cleanValue.startsWith("'") &&
                      cleanValue.endsWith("'")) {
                    cleanValue = cleanValue.substring(1, cleanValue.length - 1);
                  }
                  headers[cleanKey] = cleanValue;
                }
              });
            }
          } catch (e) {
            // 嵌套解析失败，使用字符串格式解析
            final parsedHeaders = NetworkService.parseHeaders(headerJson);
            if (parsedHeaders.isNotEmpty) {
              headers.addAll(parsedHeaders);
            }
          }
        }
      } catch (e) {
        // JSON 解析失败，尝试使用字符串格式解析（key:value\n格式）
        try {
          final parsedHeaders = NetworkService.parseHeaders(headerString);
          if (parsedHeaders.isNotEmpty) {
            headers.addAll(parsedHeaders);
          }
        } catch (e2) {
          AppLog.instance.put('解析请求头失败: $headerString', error: e2);
        }
      }
    }

    // 确保 User-Agent 存在（如果没有，使用默认值）
    // 注意：NetworkService 的 BaseOptions 中已经设置了默认 User-Agent
    // 但为了确保请求头正确传递，我们在这里也设置一个
    if (!headers.containsKey('User-Agent') &&
        !headers.containsKey('user-agent')) {
      headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }

    // 确保 Accept 存在
    if (!headers.containsKey('Accept') && !headers.containsKey('accept')) {
      headers['Accept'] =
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8';
    }

    // 确保 Accept-Language 存在
    if (!headers.containsKey('Accept-Language') &&
        !headers.containsKey('accept-language')) {
      headers['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8';
    }

    return headers;
  }
}
