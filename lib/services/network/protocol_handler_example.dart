import '../../data/models/book_source.dart';
import 'protocol_handler.dart';

/// 多源协议处理器使用示例
///
/// 展示如何使用ProtocolHandler处理不同协议类型的书源

// ==================== 示例1: HTTP协议 (常规网页) ====================

class HttpProtocolExample {
  /// 使用HTTP协议搜索书籍
  static Future<void> searchWithHttp() async {
    final source = BookSource(
      bookSourceUrl: 'https://www.example.com',
      bookSourceName: '示例书源',
      searchUrl: 'https://www.example.com/search?q={{key}}',
    );

    try {
      // 自动检测为HTTP协议
      final html = await ProtocolHandler.instance.request(
        url: 'https://www.example.com/search?q=武侠',
        source: source,
      );

      print('获取HTML内容: ${html.length}字');
      // 然后使用RuleParser解析HTML...
    } catch (e) {
      print('HTTP请求失败: $e');
    }
  }
}

// ==================== 示例2: JSON/API协议 ====================

class JsonProtocolExample {
  /// 使用JSON协议调用API
  static Future<void> searchWithJson() async {
    final source = BookSource(
      bookSourceUrl: 'https://api.example.com',
      bookSourceName: 'API书源',
      // 使用@json标记指定JSON协议
      searchUrl: 'https://api.example.com/books/search@json',
    );

    try {
      // 自动检测为JSON协议,设置正确的Content-Type
      final jsonResponse = await ProtocolHandler.instance.request(
        url: 'https://api.example.com/books/search@json?keyword=武侠',
        source: source,
        method: 'GET',
      );

      print('获取JSON响应: $jsonResponse');
      // 直接使用jsonDecode解析...
    } catch (e) {
      print('JSON请求失败: $e');
    }
  }

  /// POST JSON数据
  static Future<void> postJsonData() async {
    final source = BookSource(
      bookSourceUrl: 'https://api.example.com',
      bookSourceName: 'API书源',
    );

    try {
      final response = await ProtocolHandler.instance.request(
        url: 'https://api.example.com/books/search',
        source: source,
        method: 'POST',
        data: {
          'keyword': '武侠',
          'page': 1,
          'size': 20,
        },
        forceProtocol: ProtocolType.json,
      );

      print('POST响应: $response');
    } catch (e) {
      print('POST失败: $e');
    }
  }
}

// ==================== 示例3: WebView协议 (反爬处理) ====================

class WebViewProtocolExample {
  /// 使用WebView处理反爬网站
  static Future<void> loadWithWebView() async {
    final source = BookSource(
      bookSourceUrl: 'https://protected.example.com',
      bookSourceName: '反爬书源',
      // 使用@webview标记启用WebView
      searchUrl: 'https://protected.example.com/search?q={{key}}@webview',
    );

    try {
      // 自动检测为WebView协议,启动静默WebView
      final html = await ProtocolHandler.instance.request(
        url: 'https://protected.example.com/search?q=武侠@webview',
        source: source,
      );

      print('WebView获取内容: ${html.length}字');
      // Cookie已自动保存...
    } catch (e) {
      print('WebView请求失败: $e');
    }
  }

  /// 带验证码的网站
  static Future<void> handleCaptcha() async {
    final source = BookSource(
      bookSourceUrl: 'https://captcha.example.com',
      bookSourceName: '验证码网站',
      searchUrl: 'https://captcha.example.com/search@webview',
    );

    try {
      // WebView会自动处理验证码页面
      // 用户需要在WebView中手动完成验证码
      final html = await ProtocolHandler.instance.request(
        url: 'https://captcha.example.com/search?q=武侠@webview',
        source: source,
      );

      print('验证码处理后获取内容');
    } catch (e) {
      print('验证码处理失败: $e');
    }
  }
}

// ==================== 示例4: 协议检测与判断 ====================

class ProtocolDetectionExample {
  /// 检测URL的协议类型
  static void detectProtocol() {
    final urls = [
      'https://www.example.com/search',
      'https://api.example.com/books@json',
      'https://protected.example.com@webview',
      'https://api.example.com/data.json',
    ];

    for (final url in urls) {
      final type = ProtocolHandler.instance.detectProtocolType(url);
      final desc = ProtocolHandler.instance.getProtocolDescription(type);
      print('$url → $desc');
    }

    // 输出:
    // https://www.example.com/search → HTTP/HTTPS - 常规网页
    // https://api.example.com/books@json → JSON/API - 现代API
    // https://protected.example.com@webview → WebView - 反爬处理
    // https://api.example.com/data.json → JSON/API - 现代API
  }

  /// 检查书源的协议类型
  static void checkSourceProtocol() {
    final source1 = BookSource(
      bookSourceUrl: 'https://www.example.com',
      searchUrl: 'https://www.example.com/search',
    );

    final source2 = BookSource(
      bookSourceUrl: 'https://api.example.com',
      searchUrl: 'https://api.example.com/search@json',
    );

    final source3 = BookSource(
      bookSourceUrl: 'https://protected.example.com',
      searchUrl: 'https://protected.example.com/search@webview',
    );

    print(
        'source1使用WebView: ${ProtocolHandler.instance.isWebViewSource(source1)}');
    print('source2使用JSON: ${ProtocolHandler.instance.isJsonSource(source2)}');
    print(
        'source3使用WebView: ${ProtocolHandler.instance.isWebViewSource(source3)}');
  }
}

// ==================== 示例5: 批量请求 ====================

class BatchRequestExample {
  /// 批量请求多个URL(自动检测协议)
  static Future<void> batchLoad() async {
    final source = BookSource(
      bookSourceUrl: 'https://www.example.com',
      bookSourceName: '混合协议书源',
    );

    final urls = [
      'https://www.example.com/page1', // HTTP
      'https://api.example.com/data@json', // JSON
      'https://protected.example.com@webview', // WebView
    ];

    try {
      // 自动检测每个URL的协议并并发请求
      final results = await ProtocolHandler.instance.batchRequest(
        urls: urls,
        source: source,
      );

      for (int i = 0; i < urls.length; i++) {
        print('URL ${i + 1}: ${results[i].length}字');
      }
    } catch (e) {
      print('批量请求失败: $e');
    }
  }
}

// ==================== 示例6: 实际应用场景 ====================

/// 在BookService中集成协议处理
class BookServiceIntegrationExample {
  /// 搜索书籍(支持多协议)
  static Future<List<dynamic>> searchBooks(
    String keyword,
    BookSource source,
  ) async {
    try {
      // 构造搜索URL
      final searchUrl = source.searchUrl?.replaceAll('{{key}}', keyword) ?? '';

      // 使用协议处理器请求
      final response = await ProtocolHandler.instance.request(
        url: searchUrl,
        source: source,
      );

      // 根据协议类型解析响应
      final protocolType =
          ProtocolHandler.instance.detectProtocolType(searchUrl);

      if (protocolType == ProtocolType.json) {
        // JSON响应 - 直接解析
        // return parseJsonResponse(response);
      } else {
        // HTML响应 - 使用规则解析
        // return parseHtmlResponse(response, source.ruleSearch);
      }

      return [];
    } catch (e) {
      print('搜索失败: $e');
      return [];
    }
  }
}

// ==================== 书源配置示例 ====================

/// 如何在书源JSON中配置协议
/// 
/// ```json
/// {
///   "bookSourceName": "HTTP书源",
///   "searchUrl": "https://www.example.com/search?q={{key}}"
/// }
/// 
/// {
///   "bookSourceName": "JSON API书源",
///   "searchUrl": "https://api.example.com/search?q={{key}}@json"
/// }
/// 
/// {
///   "bookSourceName": "WebView书源",
///   "searchUrl": "https://protected.example.com/search?q={{key}}@webview"
/// }
/// ```

// ==================== 性能对比 ====================

/// **协议性能对比:**
/// 
/// | 协议类型 | 速度 | 资源占用 | 适用场景 |
/// |---------|------|---------|---------|
/// | HTTP | 快 (50-200ms) | 低 | 常规网站 |
/// | JSON | 最快 (30-100ms) | 最低 | 现代API |
/// | WebView | 慢 (1-5秒) | 高 | 反爬网站 |
/// 
/// **选择建议:**
/// 1. 优先使用 HTTP/JSON 协议
/// 2. 只在必要时使用 WebView (严格反爬)
/// 3. WebView会显著增加内存占用和响应时间

// ==================== 注意事项 ====================

/// **使用WebView协议的注意事项:**
/// 
/// 1. **性能影响:**
///    - 首次启动需要1-2秒初始化
///    - 每次请求需要加载完整页面
///    - 内存占用增加50-100MB
/// 
/// 2. **平台限制:**
///    - Web平台不支持WebView
///    - 需要添加 webview_flutter 依赖
/// 
/// 3. **安全考虑:**
///    - WebView会执行网站的所有JavaScript
///    - 需要注意XSS等安全风险
/// 
/// 4. **Cookie管理:**
///    - Cookie会自动保存到内存
///    - 需要定期清理避免泄露
/// 
/// 5. **最佳实践:**
///    - 只在HTTP/JSON无法使用时才用WebView
///    - 设置合理的超时时间(30秒)
///    - 使用完毕后及时释放资源
