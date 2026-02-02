import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../data/models/book_source.dart';
import '../../utils/app_log.dart';
import 'protocol_handler.dart';

/// WebView协议处理器
///
/// **设计思路:**
/// 处理带有严格反爬虫措施的网站:
/// - 验证码识别
/// - 动态Token生成
/// - JavaScript加密
/// - Cookie依赖
///
/// **实现策略:**
/// 1. Mobile/Desktop: 使用webview_flutter静默加载
/// 2. Web平台: 使用iframe + postMessage通信
/// 3. 自动Cookie管理: 提取并保存
/// 4. 超时控制: 避免无限等待
///
/// **安全措施:**
/// - 隐藏WebView (不显示UI)
/// - 限制加载时间 (默认30秒)
/// - 自动清理资源
///
/// 参考项目: io.legado.app.help.http.WebViewHelper
class WebViewProtocolHandler {
  static final WebViewProtocolHandler instance = WebViewProtocolHandler._init();
  WebViewProtocolHandler._init();

  // WebView实例池 (复用WebView提升性能)
  final Map<String, dynamic> _webViewPool = {};

  // Cookie存储
  final Map<String, Map<String, String>> _cookieStore = {};

  /// 加载页面并获取内容
  ///
  /// [url] 目标URL
  /// [source] 书源配置
  /// [headers] 请求头
  /// [timeout] 超时时间 (默认30秒)
  /// [jsCode] 可选的JavaScript代码,用于提取内容
  ///
  /// 返回: ProtocolResult包含内容和Cookie
  Future<ProtocolResult> loadPage({
    required String url,
    required BookSource source,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
    String? jsCode,
  }) async {
    final startTime = DateTime.now();

    try {
      // Web平台不支持WebView
      if (kIsWeb) {
        AppLog.instance.put('警告: Web平台不支持WebView协议,回退到HTTP');
        return ProtocolResult.failure(
          error: 'Web平台不支持WebView',
          duration: DateTime.now().difference(startTime),
        );
      }

      AppLog.instance.put('WebView: 开始加载页面 - $url');

      // 创建 WebViewController
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000));

      // 设置请求头中的 User-Agent (如果书源有自定义UA)
      final mergedHeaders = <String, String>{
        if (headers != null) ...headers,
      };

      // 监听页面加载完成
      final contentCompleter = Completer<String>();

      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (finishedUrl) async {
            try {
              String js = jsCode ??
                  // 默认返回整个HTML
                  'document.documentElement.outerHTML';

              final result = await controller.runJavaScriptReturningResult(js);

              // runJavaScriptReturningResult 在不同平台返回类型不同,统一转为字符串
              final content = _normalizeJsResult(result);

              if (!contentCompleter.isCompleted) {
                contentCompleter.complete(content);
              }
            } catch (e) {
              if (!contentCompleter.isCompleted) {
                contentCompleter.completeError(e);
              }
            }
          },
        ),
      );

      // 加载页面
      await controller.loadRequest(
        Uri.parse(url),
        headers: mergedHeaders,
      );

      // 等待内容或超时
      String content;
      try {
        content = await contentCompleter.future.timeout(timeout,
            onTimeout: () => throw TimeoutException('WebView加载超时'));
      } catch (e) {
        AppLog.instance.put('WebView: 加载超时或出错 - $url', error: e);
        return ProtocolResult.failure(
          error: e.toString(),
          duration: DateTime.now().difference(startTime),
        );
      }

      // 目前 webview_flutter 不提供直接读取 Cookie 的API
      // 这里保留Cookie扩展点,暂时返回空
      final cookies = <String, String>{};

      final duration = DateTime.now().difference(startTime);

      AppLog.instance.put(
        'WebView: 加载完成 (耗时${duration.inMilliseconds}ms, 内容长度=${content.length})',
      );

      return ProtocolResult.success(
        content: content,
        cookies: cookies,
        duration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      AppLog.instance.put('WebView加载失败: $url', error: e);

      return ProtocolResult.failure(
        error: e.toString(),
        duration: duration,
      );
    }
  }

  /// 模拟WebView加载 (备用/测试用)
  ///
  /// 实际运行时优先使用 loadPage 中的真实实现
  Future<String> _simulateWebViewLoad(
    String url,
    BookSource source,
    String? jsCode,
  ) async {
    AppLog.instance.put('临时实现: 模拟WebView加载');

    // 这里应该:
    // 1. 创建WebView实例
    // 2. 设置User-Agent和Headers
    // 3. 加载URL
    // 4. 等待页面加载完成
    // 5. 执行JavaScript提取内容
    // 6. 提取Cookie

    return '''
<!DOCTYPE html>
<html>
<head><title>WebView加载</title></head>
<body>
<p>此处应该是WebView加载的真实内容</p>
<p>URL: $url</p>
<p>需要集成 webview_flutter 包</p>
</body>
</html>
''';
  }

  /// 执行JavaScript代码
  ///
  /// 这里作为占位实现,实际执行由 loadPage 中的 controller 负责
  Future<String?> executeJavaScript(String url, String jsCode) async {
    try {
      AppLog.instance.put('WebView: 执行JavaScript占位实现');
      return null;
    } catch (e) {
      AppLog.instance.put('JavaScript执行失败', error: e);
      return null;
    }
  }

  /// 将 runJavaScriptReturningResult 的返回值转为字符串
  String _normalizeJsResult(Object? result) {
    if (result == null) return '';
    if (result is String) return result;
    // Android 通常返回 JSON 编码的字符串,尝试去掉包裹的引号
    final text = result.toString();
    if (text.startsWith('"') && text.endsWith('"')) {
      return text.substring(1, text.length - 1);
    }
    return text;
  }

  /// 提取Cookie
  ///
  /// [url] 目标URL
  ///
  /// 返回: Cookie键值对
  Map<String, String> _extractCookies(String url) {
    try {
      // 从Cookie存储中获取
      final domain = Uri.parse(url).host;
      return _cookieStore[domain] ?? {};
    } catch (e) {
      return {};
    }
  }

  /// 保存Cookie
  ///
  /// [url] 目标URL
  /// [cookies] Cookie键值对
  void saveCookies(String url, Map<String, String> cookies) {
    try {
      final domain = Uri.parse(url).host;
      _cookieStore[domain] = {
        ..._cookieStore[domain] ?? {},
        ...cookies,
      };

      AppLog.instance.put('WebView: 保存Cookie - $domain (${cookies.length}个)');
    } catch (e) {
      AppLog.instance.put('保存Cookie失败', error: e);
    }
  }

  /// 清除Cookie
  ///
  /// [url] 目标URL (可选,不传则清除所有)
  void clearCookies([String? url]) {
    if (url != null) {
      try {
        final domain = Uri.parse(url).host;
        _cookieStore.remove(domain);
        AppLog.instance.put('WebView: 清除Cookie - $domain');
      } catch (e) {
        AppLog.instance.put('清除Cookie失败', error: e);
      }
    } else {
      _cookieStore.clear();
      AppLog.instance.put('WebView: 清除所有Cookie');
    }
  }

  /// 预热WebView (提前创建实例)
  ///
  /// 用于提升首次加载速度
  Future<void> warmup() async {
    if (kIsWeb) return;

    try {
      AppLog.instance.put('WebView: 预热WebView实例');
      // TODO: 创建一个隐藏的WebView实例
    } catch (e) {
      AppLog.instance.put('WebView预热失败', error: e);
    }
  }

  /// 释放资源
  void dispose() {
    _webViewPool.clear();
    _cookieStore.clear();
    AppLog.instance.put('WebView: 释放所有资源');
  }

  /// 获取Cookie存储统计
  Map<String, int> getCookieStats() {
    final stats = <String, int>{};
    for (final entry in _cookieStore.entries) {
      stats[entry.key] = entry.value.length;
    }
    return stats;
  }
}

/// WebView配置
class WebViewConfig {
  /// User-Agent
  final String? userAgent;

  /// 是否启用JavaScript
  final bool enableJavaScript;

  /// 是否启用DOM存储
  final bool enableDomStorage;

  /// 超时时间
  final Duration timeout;

  /// 是否自动保存Cookie
  final bool saveCookies;

  const WebViewConfig({
    this.userAgent,
    this.enableJavaScript = true,
    this.enableDomStorage = true,
    this.timeout = const Duration(seconds: 30),
    this.saveCookies = true,
  });

  static const WebViewConfig defaultConfig = WebViewConfig();
}
