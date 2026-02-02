import 'dart:convert';
import 'package:dio/dio.dart';
import '../../data/models/book_source.dart';
import '../../utils/app_log.dart';
import '../network/network_service.dart';
import 'webview_protocol_handler.dart';

/// 协议类型枚举
///
/// 定义支持的书源协议类型
enum ProtocolType {
  /// HTTP/HTTPS协议 - 常规网页解析
  http,

  /// JSON/API协议 - 现代小说网站API
  json,

  /// WebView协议 - 处理严格反爬网站(验证码、动态Token等)
  webview,
}

/// 多源协议处理器
///
/// **设计思路:**
/// 统一处理不同协议类型的书源请求,根据协议类型自动选择合适的处理策略
///
/// **支持的协议:**
/// 1. HTTP/HTTPS: 常规网页解析 (默认)
/// 2. JSON/API: JSON响应直接解析
/// 3. WebView: 处理严格反爬虫网站
///
/// **使用场景:**
/// - 搜索书籍
/// - 获取书籍详情
/// - 获取章节列表
/// - 获取章节内容
///
/// 参考项目: io.legado.app.model.webBook
class ProtocolHandler {
  static final ProtocolHandler instance = ProtocolHandler._init();
  ProtocolHandler._init();

  final _networkService = NetworkService.instance;

  /// 根据URL判断协议类型
  ///
  /// 规则:
  /// - URL包含 '@webview' 标记 → WebView协议
  /// - URL包含 '@json' 标记或以 '.json' 结尾 → JSON协议
  /// - 其他 → HTTP协议
  ProtocolType detectProtocolType(String url) {
    final lowerUrl = url.toLowerCase();

    // WebView协议标记
    if (lowerUrl.contains('@webview') ||
        lowerUrl.contains('webview:') ||
        lowerUrl.contains('<webview>')) {
      return ProtocolType.webview;
    }

    // JSON协议标记
    if (lowerUrl.contains('@json') ||
        lowerUrl.endsWith('.json') ||
        lowerUrl.contains('api/') ||
        lowerUrl.contains('/api.')) {
      return ProtocolType.json;
    }

    // 默认HTTP协议
    return ProtocolType.http;
  }

  /// 清理URL中的协议标记
  ///
  /// 移除 @webview, @json 等标记,返回纯净的URL
  String cleanProtocolMarkers(String url) {
    return url
        .replaceAll('@webview', '')
        .replaceAll('@json', '')
        .replaceAll('webview:', '')
        .replaceAll('<webview>', '')
        .replaceAll('</webview>', '')
        .trim();
  }

  /// 执行网络请求 (根据协议类型自动选择处理方式)
  ///
  /// [url] 请求URL (可包含协议标记)
  /// [source] 书源配置
  /// [method] HTTP方法 (GET/POST)
  /// [headers] 请求头
  /// [data] POST数据
  /// [forceProtocol] 强制使用指定协议
  ///
  /// 返回: HTTP响应文本
  Future<String> request({
    required String url,
    required BookSource source,
    String method = 'GET',
    Map<String, String>? headers,
    dynamic data,
    ProtocolType? forceProtocol,
  }) async {
    // 1. 检测或使用强制指定的协议类型
    final protocolType = forceProtocol ?? detectProtocolType(url);

    // 2. 清理URL中的协议标记
    final cleanUrl = cleanProtocolMarkers(url);

    AppLog.instance.put('协议处理: $protocolType, URL: $cleanUrl');

    // 3. 根据协议类型处理请求
    switch (protocolType) {
      case ProtocolType.http:
        return await _handleHttpProtocol(
          cleanUrl,
          source,
          method,
          headers,
          data,
        );

      case ProtocolType.json:
        return await _handleJsonProtocol(
          cleanUrl,
          source,
          method,
          headers,
          data,
        );

      case ProtocolType.webview:
        return await _handleWebViewProtocol(
          cleanUrl,
          source,
          headers,
        );
    }
  }

  /// 处理HTTP/HTTPS协议
  ///
  /// 常规网页解析,使用Dio直接请求
  Future<String> _handleHttpProtocol(
    String url,
    BookSource source,
    String method,
    Map<String, String>? headers,
    dynamic data,
  ) async {
    try {
      // 合并书源配置的请求头
      final mergedHeaders = {
        ...NetworkService.parseHeaders(source.header),
        if (headers != null) ...headers,
      };

      Response response;

      if (method.toUpperCase() == 'POST') {
        response = await _networkService.post(
          url,
          data: data,
          headers: mergedHeaders,
        );
      } else {
        response = await _networkService.get(
          url,
          headers: mergedHeaders,
        );
      }

      return await NetworkService.getResponseText(response);
    } catch (e) {
      AppLog.instance.put('HTTP请求失败: $url', error: e);
      rethrow;
    }
  }

  /// 处理JSON/API协议
  ///
  /// 针对现代小说网站API,直接返回JSON响应
  ///
  /// **特性:**
  /// - 自动设置 Content-Type: application/json
  /// - 自动解析JSON响应
  /// - 支持POST JSON数据
  Future<String> _handleJsonProtocol(
    String url,
    BookSource source,
    String method,
    Map<String, String>? headers,
    dynamic data,
  ) async {
    try {
      // 合并请求头,确保包含JSON类型
      final mergedHeaders = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...NetworkService.parseHeaders(source.header),
        if (headers != null) ...headers,
      };

      Response response;

      if (method.toUpperCase() == 'POST') {
        // POST数据自动JSON序列化
        final jsonData = data is String ? data : jsonEncode(data);
        response = await _networkService.post(
          url,
          data: jsonData,
          headers: mergedHeaders,
        );
      } else {
        response = await _networkService.get(
          url,
          headers: mergedHeaders,
        );
      }

      // 验证响应是否为JSON
      final responseText = await NetworkService.getResponseText(response);

      try {
        // 尝试解析JSON以验证格式
        jsonDecode(responseText);
        AppLog.instance.put('JSON协议: 成功解析JSON响应');
      } catch (e) {
        AppLog.instance.put('警告: 响应不是有效的JSON格式', error: e);
      }

      return responseText;
    } catch (e) {
      AppLog.instance.put('JSON请求失败: $url', error: e);
      rethrow;
    }
  }

  /// 处理WebView协议
  ///
  /// 针对带有严苛反爬的网站:
  /// - 验证码
  /// - 动态Token
  /// - JavaScript加密
  /// - Cookie依赖
  ///
  /// **策略:**
  /// 1. 静默启动WebView
  /// 2. 加载目标页面
  /// 3. 执行JavaScript获取内容
  /// 4. 自动保存Cookie
  ///
  /// 参考项目: io.legado.app.help.http.WebViewHelper
  Future<String> _handleWebViewProtocol(
    String url,
    BookSource source,
    Map<String, String>? headers,
  ) async {
    try {
      AppLog.instance.put('WebView协议: 启动静默WebView');

      // 调用WebView处理器
      final result = await WebViewProtocolHandler.instance.loadPage(
        url: url,
        source: source,
        headers: headers,
      );

      if (result.success) {
        AppLog.instance
            .put('WebView协议: 成功获取内容 (${result.content?.length ?? 0}字)');
        return result.content ?? '';
      } else {
        throw Exception('WebView加载失败: ${result.error}');
      }
    } catch (e) {
      AppLog.instance.put('WebView请求失败: $url', error: e);
      rethrow;
    }
  }

  /// 批量请求 (支持多协议混合)
  ///
  /// 自动检测每个URL的协议类型并并发请求
  Future<List<String>> batchRequest({
    required List<String> urls,
    required BookSource source,
    Map<String, String>? headers,
  }) async {
    final futures = urls.map((url) async {
      try {
        return await request(
          url: url,
          source: source,
          headers: headers,
        );
      } catch (e) {
        AppLog.instance.put('批量请求失败: $url', error: e);
        return '';
      }
    }).toList();

    return await Future.wait(futures);
  }

  /// 获取协议类型的可读描述
  String getProtocolDescription(ProtocolType type) {
    switch (type) {
      case ProtocolType.http:
        return 'HTTP/HTTPS - 常规网页';
      case ProtocolType.json:
        return 'JSON/API - 现代API';
      case ProtocolType.webview:
        return 'WebView - 反爬处理';
    }
  }

  /// 检查书源是否使用WebView协议
  bool isWebViewSource(BookSource source) {
    // 检查各个URL字段
    final urls = [
      source.searchUrl,
      source.exploreUrl,
      source.bookSourceUrl,
    ].whereType<String>();

    return urls.any((url) => detectProtocolType(url) == ProtocolType.webview);
  }

  /// 检查书源是否使用JSON协议
  bool isJsonSource(BookSource source) {
    final urls = [
      source.searchUrl,
      source.exploreUrl,
      source.bookSourceUrl,
    ].whereType<String>();

    return urls.any((url) => detectProtocolType(url) == ProtocolType.json);
  }
}

/// 协议请求结果
class ProtocolResult {
  final bool success;
  final String? content;
  final String? error;
  final Map<String, String>? cookies;
  final Duration? duration;

  ProtocolResult({
    required this.success,
    this.content,
    this.error,
    this.cookies,
    this.duration,
  });

  factory ProtocolResult.success({
    required String content,
    Map<String, String>? cookies,
    Duration? duration,
  }) {
    return ProtocolResult(
      success: true,
      content: content,
      cookies: cookies,
      duration: duration,
    );
  }

  factory ProtocolResult.failure({
    required String error,
    Duration? duration,
  }) {
    return ProtocolResult(
      success: false,
      error: error,
      duration: duration,
    );
  }
}
