/// URL 分析工具类
/// 参考项目：io.legado.app.model.analyzeRule.AnalyzeUrl
///
/// 提供 URL 解析、参数替换和网络请求功能：
/// - 解析带选项的 URL（url,{method:"POST", body:"xxx", ...}）
/// - 替换关键字和页码参数（<page,1,2,3>）
/// - 执行 JavaScript
/// - 发起网络请求
library;

import 'dart:convert';

import '../services/network/network_service.dart';
import 'app_log.dart';
import 'js_engine.dart';

/// 函数调用回调类型
typedef JSFunctionCallback = Future<dynamic> Function(List<dynamic> args);

/// URL 选项配置
/// 参考项目：AnalyzeUrl.UrlOption
class UrlOption {
  /// 请求方法 (GET/POST)
  String? method;

  /// 字符编码
  String? charset;

  /// 请求头
  Map<String, String>? headers;

  /// 请求体
  String? body;

  /// 重试次数
  int retry;

  /// 响应类型
  String? type;

  /// 是否使用 WebView
  bool useWebView;

  /// WebView 中执行的 JS
  String? webJs;

  /// 解析完 URL 后执行的 JS
  String? js;

  /// WebView 延迟时间（毫秒）
  int webViewDelayTime;

  UrlOption({
    this.method,
    this.charset,
    this.headers,
    this.body,
    this.retry = 0,
    this.type,
    this.useWebView = false,
    this.webJs,
    this.js,
    this.webViewDelayTime = 0,
  });

  factory UrlOption.fromJson(Map<String, dynamic>? json) {
    if (json == null) return UrlOption();

    Map<String, String>? headers;
    final headersValue = json['headers'];
    if (headersValue is Map) {
      headers =
          headersValue.map((k, v) => MapEntry(k.toString(), v.toString()));
    } else if (headersValue is String && headersValue.isNotEmpty) {
      try {
        final decoded = jsonDecode(headersValue);
        if (decoded is Map) {
          headers = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }

    String? body;
    final bodyValue = json['body'];
    if (bodyValue is String) {
      body = bodyValue;
    } else if (bodyValue is Map || bodyValue is List) {
      body = jsonEncode(bodyValue);
    }

    return UrlOption(
      method: json['method'] as String?,
      charset: json['charset'] as String?,
      headers: headers,
      body: body,
      retry: json['retry'] as int? ?? 0,
      type: json['type'] as String?,
      useWebView: _parseBool(json['webView']),
      webJs: json['webJs'] as String?,
      js: json['js'] as String?,
      webViewDelayTime: json['webViewDelayTime'] as int? ?? 0,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return value == 1;
  }

  Map<String, dynamic> toJson() {
    return {
      if (method != null) 'method': method,
      if (charset != null) 'charset': charset,
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
      if (retry > 0) 'retry': retry,
      if (type != null) 'type': type,
      if (useWebView) 'webView': useWebView,
      if (webJs != null) 'webJs': webJs,
      if (js != null) 'js': js,
      if (webViewDelayTime > 0) 'webViewDelayTime': webViewDelayTime,
    };
  }
}

/// URL 分析结果
class AnalyzeUrlResult {
  /// 最终 URL
  final String url;

  /// 请求方法
  final String method;

  /// 请求头
  final Map<String, String> headers;

  /// 请求体
  final String? body;

  /// 是否使用 WebView
  final bool useWebView;

  /// WebView JS
  final String? webJs;

  /// 重试次数
  final int retry;

  /// 响应类型
  final String? type;

  /// 字符编码
  final String? charset;

  AnalyzeUrlResult({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.useWebView = false,
    this.webJs,
    this.retry = 0,
    this.type,
    this.charset,
  });
}

/// URL 分析工具类
class AnalyzeUrl {
  // 参数分隔正则：URL 与 JSON 选项的分隔符
  static final RegExp _paramPattern = RegExp(r'\s*,\s*(?=\{)');

  // 页码模板正则：<page,1,2,3>
  static final RegExp _pagePattern = RegExp(r'<([^>]+)>');

  // JS 正则：@js:xxx 或 <js>xxx</js>
  static final RegExp _jsPattern = RegExp(
    r'@js:([^@]+)|<js>([\s\S]*?)</js>',
    caseSensitive: false,
  );

  // 内嵌 JS 正则：{{xxx}}
  static final RegExp _innerJsPattern = RegExp(r'\{\{([^}]+)\}\}');

  /// 分析 URL
  /// [ruleUrl] 规则 URL，可能包含选项和 JS
  /// [baseUrl] 基础 URL
  /// [key] 搜索关键字
  /// [page] 页码
  /// [variables] 变量
  /// [headerMap] 请求头
  static Future<AnalyzeUrlResult> analyze(
    String ruleUrl, {
    String? baseUrl,
    String? key,
    int? page,
    Map<String, dynamic>? variables,
    Map<String, String>? headerMap,
  }) async {
    var url = ruleUrl;
    UrlOption option = UrlOption();
    final headers = <String, String>{};

    // 添加默认请求头
    if (headerMap != null) {
      headers.addAll(headerMap);
    }

    try {
      // 1. 执行 @js: 和 <js></js>
      url = await _analyzeJs(url,
          baseUrl: baseUrl, key: key, page: page, variables: variables);

      // 2. 替换内嵌 {{js}}
      url = await _replaceInnerJs(url,
          baseUrl: baseUrl, key: key, page: page, variables: variables);

      // 3. 替换页码参数 <page,1,2,3>
      url = _replacePageParams(url, page);

      // 4. 替换关键字
      if (key != null) {
        url = url.replaceAll('{{key}}', Uri.encodeComponent(key));
        url = url.replaceAll('{{KEY}}', key);
        url = url.replaceAll('\$keyword', Uri.encodeComponent(key));
        url = url.replaceAll('\${keyword}', Uri.encodeComponent(key));
      }

      // 5. 替换页码变量
      if (page != null) {
        url = url.replaceAll('{{page}}', page.toString());
        url = url.replaceAll('\$page', page.toString());
        url = url.replaceAll('\${page}', page.toString());
      }

      // 6. 分离 URL 和选项
      final paramMatch = _paramPattern.firstMatch(url);
      if (paramMatch != null) {
        final urlPart = url.substring(0, paramMatch.start);
        final optionStr = url.substring(paramMatch.end);

        url = urlPart;

        // 解析选项 JSON
        try {
          final optionJson = jsonDecode(optionStr);
          if (optionJson is Map<String, dynamic>) {
            option = UrlOption.fromJson(optionJson);
          }
        } catch (e) {
          AppLog.instance.put('解析 URL 选项失败: $e');
        }
      }

      // 7. 处理相对 URL
      if (baseUrl != null && !url.startsWith('http')) {
        url = NetworkService.joinUrl(baseUrl, url);
      }

      // 8. 合并请求头
      if (option.headers != null) {
        headers.addAll(option.headers!);
      }

      // 9. 执行选项中的 JS
      if (option.js != null && option.js!.isNotEmpty) {
        final jsResult = await _executeJs(
          option.js!,
          url: url,
          baseUrl: baseUrl,
          key: key,
          page: page,
          variables: variables,
        );
        if (jsResult is String && jsResult.isNotEmpty) {
          url = jsResult;
        }
      }
    } catch (e) {
      AppLog.instance.put('分析 URL 失败: $e');
    }

    return AnalyzeUrlResult(
      url: url,
      method: option.method?.toUpperCase() ?? 'GET',
      headers: headers,
      body: option.body,
      useWebView: option.useWebView,
      webJs: option.webJs,
      retry: option.retry,
      type: option.type,
      charset: option.charset,
    );
  }

  /// 执行 @js: 和 <js></js>
  static Future<String> _analyzeJs(
    String ruleUrl, {
    String? baseUrl,
    String? key,
    int? page,
    Map<String, dynamic>? variables,
  }) async {
    var result = ruleUrl;
    var start = 0;

    final matches = _jsPattern.allMatches(ruleUrl).toList();
    for (final match in matches) {
      if (match.start > start) {
        final prefix = ruleUrl.substring(start, match.start).trim();
        if (prefix.isNotEmpty) {
          result = prefix.replaceAll('@result', result);
        }
      }

      final jsCode = match.group(2) ?? match.group(1) ?? '';
      if (jsCode.isNotEmpty) {
        final jsResult = await _executeJs(
          jsCode,
          result: result,
          baseUrl: baseUrl,
          key: key,
          page: page,
          variables: variables,
        );
        result = jsResult?.toString() ?? result;
      }

      start = match.end;
    }

    if (ruleUrl.length > start) {
      final suffix = ruleUrl.substring(start).trim();
      if (suffix.isNotEmpty) {
        result = suffix.replaceAll('@result', result);
      }
    }

    return result;
  }

  /// 替换内嵌 {{js}}
  static Future<String> _replaceInnerJs(
    String url, {
    String? baseUrl,
    String? key,
    int? page,
    Map<String, dynamic>? variables,
  }) async {
    if (!url.contains('{{') || !url.contains('}}')) {
      return url;
    }

    var result = url;
    final matches = _innerJsPattern.allMatches(url).toList();

    // 从后向前替换，避免位置偏移
    for (var i = matches.length - 1; i >= 0; i--) {
      final match = matches[i];
      final jsCode = match.group(1) ?? '';

      if (jsCode.isNotEmpty) {
        try {
          final jsResult = await _executeJs(
            jsCode,
            baseUrl: baseUrl,
            key: key,
            page: page,
            variables: variables,
          );

          String replacement;
          if (jsResult is String) {
            replacement = jsResult;
          } else if (jsResult is num) {
            // 如果是整数，不显示小数点
            if (jsResult == jsResult.toInt()) {
              replacement = jsResult.toInt().toString();
            } else {
              replacement = jsResult.toString();
            }
          } else {
            replacement = jsResult?.toString() ?? '';
          }

          result = result.substring(0, match.start) +
              replacement +
              result.substring(match.end);
        } catch (e) {
          AppLog.instance.put('执行内嵌 JS 失败: $e');
        }
      }
    }

    return result;
  }

  /// 替换页码参数 <page,1,2,3>
  static String _replacePageParams(String url, int? page) {
    if (page == null) return url;

    var result = url;
    final matches = _pagePattern.allMatches(url).toList();

    for (var i = matches.length - 1; i >= 0; i--) {
      final match = matches[i];
      final content = match.group(1) ?? '';
      final pages = content.split(',').map((e) => e.trim()).toList();

      String replacement;
      if (page <= pages.length) {
        replacement = pages[page - 1];
      } else {
        replacement = pages.isNotEmpty ? pages.last : '';
      }

      result = result.substring(0, match.start) +
          replacement +
          result.substring(match.end);
    }

    return result;
  }

  /// 执行 JS
  static Future<dynamic> _executeJs(
    String jsCode, {
    dynamic result,
    String? url,
    String? baseUrl,
    String? key,
    int? page,
    Map<String, dynamic>? variables,
  }) async {
    try {
      final bindings = <String, dynamic>{};

      if (result != null) {
        bindings['result'] = result;
      }
      if (url != null) {
        bindings['url'] = url;
      }
      if (baseUrl != null) {
        bindings['baseUrl'] = baseUrl;
      }
      if (key != null) {
        bindings['key'] = key;
      }
      if (page != null) {
        bindings['page'] = page;
      }
      if (variables != null) {
        bindings.addAll(variables);
      }

      // 使用 JSEngine 执行
      return await JSEngine.evalJS(jsCode, bindings: bindings);
    } catch (e) {
      AppLog.instance.put('执行 JS 失败: $e');
      return result;
    }
  }

  /// 快捷方法：分析 URL 并发起请求
  static Future<String?> getStrResponse(
    String ruleUrl, {
    String? baseUrl,
    String? key,
    int? page,
    Map<String, dynamic>? variables,
    Map<String, String>? headerMap,
  }) async {
    final result = await analyze(
      ruleUrl,
      baseUrl: baseUrl,
      key: key,
      page: page,
      variables: variables,
      headerMap: headerMap,
    );

    try {
      final networkService = NetworkService.instance;
      await networkService.init();

      if (result.method == 'POST') {
        final response = await networkService.post(
          result.url,
          headers: result.headers,
          data: result.body,
        );
        return response.data?.toString();
      } else {
        final response = await networkService.get(
          result.url,
          headers: result.headers,
        );
        return response.data?.toString();
      }
    } catch (e) {
      AppLog.instance.put('请求失败: $e');
      return null;
    }
  }

  /// 编码 URL 参数
  static String encodeUrlParams(String params, {String? charset}) {
    // 简单实现：URL 编码
    return Uri.encodeComponent(params);
  }

  /// 判断是否已编码
  static bool isEncoded(String value) {
    try {
      return Uri.decodeComponent(value) != value;
    } catch (_) {
      return true;
    }
  }
}
