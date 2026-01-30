/// 后台 WebView 服务
/// 参考项目：io.legado.app.help.http.BackstageWebView
///
/// 用于在后台执行 WebView 请求，获取 JavaScript 渲染后的页面内容
/// 支持：
/// - 加载 URL 并执行 JavaScript
/// - 加载 HTML 内容并执行 JavaScript
/// - 等待特定资源加载
/// - 等待页面跳转
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../utils/app_log.dart';
import '../../services/network/network_service.dart';

/// 后台 WebView 响应
class BackstageWebViewResponse {
  final String body;
  final String url;
  final int statusCode;
  final Map<String, String> headers;

  BackstageWebViewResponse({
    required this.body,
    required this.url,
    this.statusCode = 200,
    this.headers = const {},
  });
}

/// 后台 WebView 服务
///
/// 注意：Flutter 中 WebView 需要在 Widget 中渲染，真正的后台 WebView 实现较复杂
/// 当前实现提供以下策略：
/// 1. 对于简单请求，直接使用 HTTP 请求获取内容
/// 2. 对于需要 JavaScript 渲染的请求，返回提示信息（需要用户使用浏览器验证）
/// 3. 未来可以通过 flutter_inappwebview 的 HeadlessInAppWebView 实现真正的后台 WebView
class BackstageWebView {
  /// 要加载的 URL
  final String? url;

  /// 要加载的 HTML 内容
  final String? html;

  /// 要执行的 JavaScript
  final String? javaScript;

  /// 请求头
  final Map<String, String>? headerMap;

  /// 源标签（用于 Cookie 管理）
  final String? tag;

  /// 资源匹配正则（用于等待特定资源加载）
  final String? sourceRegex;

  /// 跳转 URL 匹配正则（用于等待页面跳转）
  final String? overrideUrlRegex;

  /// 超时时间
  final Duration timeout;

  BackstageWebView({
    this.url,
    this.html,
    this.javaScript,
    this.headerMap,
    this.tag,
    this.sourceRegex,
    this.overrideUrlRegex,
    this.timeout = const Duration(seconds: 30),
  });

  /// 获取字符串响应
  /// 参考项目：BackstageWebView.getStrResponse()
  Future<BackstageWebViewResponse> getStrResponse() async {
    try {
      // 如果没有 JavaScript 且没有需要等待的资源，直接使用 HTTP 请求
      if (html == null &&
          javaScript == null &&
          sourceRegex == null &&
          overrideUrlRegex == null) {
        return await _getSimpleResponse();
      }

      // 需要 WebView 渲染的情况
      // 当前使用占位实现，返回提示信息
      // TODO: 使用 flutter_inappwebview 的 HeadlessInAppWebView 实现真正的后台 WebView
      return await _getWebViewResponse();
    } catch (e) {
      AppLog.instance.put('BackstageWebView.getStrResponse error: $e');
      return BackstageWebViewResponse(
        body: e.toString(),
        url: url ?? '',
        statusCode: 0,
      );
    }
  }

  /// 简单 HTTP 请求
  Future<BackstageWebViewResponse> _getSimpleResponse() async {
    if (url == null || url!.isEmpty) {
      return BackstageWebViewResponse(
        body: '',
        url: '',
        statusCode: 400,
      );
    }

    final response = await NetworkService.instance.get(
      url!,
      headers: headerMap,
    );

    final body = await NetworkService.getResponseText(response);

    return BackstageWebViewResponse(
      body: body,
      url: url!,
      statusCode: response.statusCode ?? 200,
      headers: response.headers.map.map((k, v) => MapEntry(k, v.join('; '))),
    );
  }

  /// WebView 渲染请求
  ///
  /// 当前实现策略：
  /// 1. 如果提供了 HTML 内容，直接返回（后续可以在前端渲染时执行 JS）
  /// 2. 如果需要执行 JavaScript，尝试使用 HTTP 请求获取原始内容
  /// 3. 对于复杂的 JavaScript 渲染需求，记录日志并返回原始内容
  Future<BackstageWebViewResponse> _getWebViewResponse() async {
    String resultBody = '';
    String resultUrl = url ?? '';

    // 如果提供了 HTML，使用 HTML 作为基础内容
    if (html != null && html!.isNotEmpty) {
      resultBody = html!;

      // 如果需要执行 JavaScript，在客户端执行时处理
      if (javaScript != null && javaScript!.isNotEmpty) {
        AppLog.instance
            .put('BackstageWebView: HTML 内容需要执行 JavaScript: $javaScript');
        // 将 JavaScript 嵌入到 HTML 中（供后续前端执行）
        // 注意：这里只是标记，实际执行需要在前端
        resultBody = _injectJavaScript(resultBody, javaScript!);
      }
    } else if (url != null && url!.isNotEmpty) {
      // 通过 HTTP 请求获取原始内容
      final response = await NetworkService.instance.get(
        url!,
        headers: headerMap,
      );
      resultBody = await NetworkService.getResponseText(response);

      // 如果需要执行 JavaScript
      if (javaScript != null && javaScript!.isNotEmpty) {
        AppLog.instance
            .put('BackstageWebView: URL 内容需要执行 JavaScript: $javaScript');
        // 尝试简单的 JavaScript 执行
        resultBody = await _executeSimpleJavaScript(resultBody, javaScript!);
      }
    }

    // 如果需要等待特定资源
    if (sourceRegex != null && sourceRegex!.isNotEmpty) {
      AppLog.instance.put('BackstageWebView: 需要等待资源匹配: $sourceRegex');
      // 从内容中提取匹配的资源 URL
      final matchedUrl = _extractMatchingResource(resultBody, sourceRegex!);
      if (matchedUrl != null) {
        resultBody = matchedUrl;
      }
    }

    // 如果需要等待页面跳转
    if (overrideUrlRegex != null && overrideUrlRegex!.isNotEmpty) {
      AppLog.instance.put('BackstageWebView: 需要等待跳转 URL 匹配: $overrideUrlRegex');
      // 从内容中提取跳转 URL
      final overrideUrl = _extractOverrideUrl(resultBody, overrideUrlRegex!);
      if (overrideUrl != null) {
        resultBody = overrideUrl;
      }
    }

    return BackstageWebViewResponse(
      body: resultBody,
      url: resultUrl,
      statusCode: 200,
    );
  }

  /// 将 JavaScript 注入到 HTML 中
  String _injectJavaScript(String html, String js) {
    // 在 </body> 或 </html> 前插入脚本
    final script = '<script>$js</script>';

    if (html.contains('</body>')) {
      return html.replaceFirst('</body>', '$script</body>');
    } else if (html.contains('</html>')) {
      return html.replaceFirst('</html>', '$script</html>');
    } else {
      return '$html$script';
    }
  }

  /// 执行简单的 JavaScript
  ///
  /// 注意：这里只能处理简单的 DOM 查询
  /// 复杂的 JavaScript 需要真正的 WebView 环境
  Future<String> _executeSimpleJavaScript(String html, String js) async {
    // 简化实现：尝试解析常见的 JavaScript 模式
    // 例如：document.querySelector('...').innerHTML

    // 如果 JS 只是简单的返回语句，提取内容
    if (js.trim().startsWith('return ')) {
      // 可能是简单的返回表达式
      AppLog.instance.put('BackstageWebView: 检测到 return 语句');
    }

    // 当前返回原始内容，标记需要前端处理
    return html;
  }

  /// 从内容中提取匹配的资源 URL
  String? _extractMatchingResource(String content, String regex) {
    try {
      final pattern = RegExp(regex);
      final matches = pattern.allMatches(content);

      for (final match in matches) {
        final matchedStr = match.group(0);
        if (matchedStr != null && matchedStr.isNotEmpty) {
          // 检查是否是 URL
          if (matchedStr.startsWith('http://') ||
              matchedStr.startsWith('https://')) {
            return matchedStr;
          }
          // 尝试从 src 或 href 属性中提取
          final srcMatch =
              RegExp(r'''(?:src|href)=["']([^"']+)["']''').firstMatch(content);
          if (srcMatch != null) {
            final src = srcMatch.group(1);
            if (src != null && pattern.hasMatch(src)) {
              return src;
            }
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('BackstageWebView: 资源匹配失败: $e');
    }
    return null;
  }

  /// 从内容中提取跳转 URL
  String? _extractOverrideUrl(String content, String regex) {
    try {
      final pattern = RegExp(regex);

      // 从 meta refresh 中提取
      final metaMatch = RegExp(
              r'''<meta[^>]+http-equiv=["']refresh["'][^>]+content=["'][\d;]*url=([^"']+)["']''',
              caseSensitive: false)
          .firstMatch(content);
      if (metaMatch != null) {
        final url = metaMatch.group(1);
        if (url != null && pattern.hasMatch(url)) {
          return url;
        }
      }

      // 从 location.href 或 window.location 中提取
      final locationMatch = RegExp(
              r'''(?:location\.href|window\.location)\s*=\s*["']([^"']+)["']''')
          .firstMatch(content);
      if (locationMatch != null) {
        final url = locationMatch.group(1);
        if (url != null && pattern.hasMatch(url)) {
          return url;
        }
      }

      // 从 a 标签中提取
      final linkMatches =
          RegExp(r'''<a[^>]+href=["']([^"']+)["']''').allMatches(content);
      for (final match in linkMatches) {
        final url = match.group(1);
        if (url != null && pattern.hasMatch(url)) {
          return url;
        }
      }
    } catch (e) {
      AppLog.instance.put('BackstageWebView: 跳转 URL 提取失败: $e');
    }
    return null;
  }

  /// 获取 WebView 默认 User-Agent
  /// 参考项目：JsExtensions.getWebViewUA()
  ///
  /// 注意：在 Flutter 中，我们返回一个通用的 WebView User-Agent
  static String getWebViewUA() {
    // 返回类似 Android WebView 的 User-Agent
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      return 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }
    return 'Mozilla/5.0 (compatible; Legado Flutter/1.0)';
  }
}
