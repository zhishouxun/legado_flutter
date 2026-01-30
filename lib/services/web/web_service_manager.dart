import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../../core/base/base_service.dart';
import '../../config/app_config.dart';
import '../book/book_service.dart';
import '../source/book_source_service.dart';
import '../replace_rule_service.dart';
import '../rss_service.dart';
import '../network/network_service.dart';
import '../book/local_book_service.dart';
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';
import '../../data/models/book_source.dart';
import '../../data/models/replace_rule.dart';
import '../../data/models/rss_source.dart';
import '../../utils/app_log.dart';
import 'websocket_debug_handler.dart';
import '../notification_service.dart';

/// Web服务管理器
/// 参考项目：io.legado.app.service.WebService
class WebServiceManager extends BaseService {
  static final WebServiceManager instance = WebServiceManager._init();
  WebServiceManager._init();

  HttpServer? _server;
  HttpServer? _wsServer;
  bool _isRunning = false;
  String? _hostAddress;
  int? _port;
  int? _wsPort;
  static const int notificationId = 105; // 参考项目：NotificationId.WebService

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 获取服务地址
  String? get hostAddress => _hostAddress;

  /// 获取端口
  int? get port => _port;

  /// 启动Web服务
  Future<bool> start() async {
    if (_isRunning) {
      return true;
    }

    try {
      final port = AppConfig.getInt('web_port', defaultValue: 1122);
      if (port < 1024 || port > 65535) {
        throw Exception('端口号必须在 1024-65535 之间');
      }

      final router = Router();

      // GET路由
      _setupGetRoutes(router);

      // POST路由
      _setupPostRoutes(router);

      // WebSocket路由（在HTTP服务器上处理升级）
      router.get('/bookSourceDebug', WebSocketDebugHandler.createHandler());

      // 创建处理器（添加CORS）
      final handler =
          Pipeline().addMiddleware(_corsMiddleware()).addHandler(router.call);

      // 启动HTTP服务器（同时支持WebSocket升级）
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        port,
      );

      _isRunning = true;
      _port = port;
      _wsPort = port; // WebSocket使用相同端口
      final localIP = await _getLocalIP();
      _hostAddress = 'http://$localIP:$port';

      // 显示通知（添加payload用于点击跳转）
      await NotificationService.instance.showNotification(
        id: notificationId,
        title: 'Web服务已启动',
        content: '地址: $_hostAddress',
        isOngoing: true,
        channelId: NotificationService.channelIdWebService,
        payload: 'web_service:$_hostAddress', // payload格式：action:data
      );

      AppLog.instance.put('Web服务已启动: $_hostAddress');
      AppLog.instance.put('WebSocket调试地址: ws://$localIP:$port/bookSourceDebug');
      return true;
    } catch (e) {
      AppLog.instance.put('启动Web服务失败', error: e);
      _isRunning = false;
      _hostAddress = null;
      _port = null;
      return false;
    }
  }

  /// 停止Web服务
  Future<void> stop() async {
    if (!_isRunning) {
      return;
    }

    try {
      if (_server != null) {
        await _server!.close(force: true);
        _server = null;
      }
      if (_wsServer != null) {
        await _wsServer!.close(force: true);
        _wsServer = null;
      }
      _isRunning = false;
      _hostAddress = null;
      _port = null;
      _wsPort = null;

      // 取消通知
      await NotificationService.instance.cancelNotification(notificationId);

      AppLog.instance.put('Web服务已停止');
    } catch (e) {
      AppLog.instance.put('停止Web服务失败', error: e);
    }
  }

  /// 获取WebSocket端口
  int? get wsPort => _wsPort;

  /// 获取WebSocket地址
  String? get wsAddress {
    if (_wsPort == null) return null;
    return 'ws://127.0.0.1:$_wsPort';
  }

  /// 设置GET路由
  void _setupGetRoutes(Router router) {
    // 获取书源列表
    router.get('/getBookSources', (Request request) async {
      try {
        final sources = await BookSourceService.instance.getAllBookSources();
        final data = sources.map((BookSource s) => s.toJson()).toList();
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': data}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取单个书源
    router.get('/getBookSource', (Request request) async {
      try {
        final url = request.url.queryParameters['url'];
        if (url == null || url.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '缺少url参数'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final source = await BookSourceService.instance.getBookSourceByUrl(url);
        if (source == null) {
          return Response.notFound(
            jsonEncode({'isSuccess': false, 'errorMsg': '书源不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': source.toJson()}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取书架
    router.get('/getBookshelf', (Request request) async {
      try {
        final books = await BookService.instance.getBookshelfBooks();
        final data = books.map((Book b) => b.toJson()).toList();
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': data}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取章节列表
    router.get('/getChapterList', (Request request) async {
      try {
        final url = request.url.queryParameters['url'];
        if (url == null || url.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '缺少url参数'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final book = await BookService.instance.getBookByUrl(url);
        if (book == null) {
          return Response.notFound(
            jsonEncode({'isSuccess': false, 'errorMsg': '书籍不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final chapters = await BookService.instance.getChapterList(book);
        final data = chapters.map((BookChapter c) => c.toJson()).toList();
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': data}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取章节内容
    router.get('/getBookContent', (Request request) async {
      try {
        final url = request.url.queryParameters['url'];
        final indexStr = request.url.queryParameters['index'];
        if (url == null || url.isEmpty || indexStr == null) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '缺少url或index参数'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final index = int.tryParse(indexStr);
        if (index == null) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': 'index参数格式错误'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final book = await BookService.instance.getBookByUrl(url);
        if (book == null) {
          return Response.notFound(
            jsonEncode({'isSuccess': false, 'errorMsg': '书籍不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final chapters = await BookService.instance.getChapterList(book);
        if (index < 0 || index >= chapters.length) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '章节索引超出范围'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final chapter = chapters[index];
        final source =
            await BookSourceService.instance.getBookSourceByUrl(book.origin);
        if (source == null) {
          return Response.internalServerError(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '书源不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final content = await BookService.instance.getChapterContent(
          chapter,
          source,
          bookName: book.name,
          bookOrigin: book.origin,
          book: book, // 传入 book 参数，启用缓存优化
        );
        if (content == null) {
          return Response.internalServerError(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '获取章节内容失败'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': content}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取封面
    router.get('/cover', (Request request) async {
      try {
        final path = request.url.queryParameters['path'];
        if (path == null || path.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '缺少path参数'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        // 获取封面图片
        final response = await NetworkService.instance.get(path);
        final bytes = await response.data;
        if (bytes == null) {
          return Response.notFound(
            jsonEncode({'isSuccess': false, 'errorMsg': '封面不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        // 根据文件扩展名确定Content-Type
        String contentType = 'image/jpeg';
        if (path.toLowerCase().endsWith('.png')) {
          contentType = 'image/png';
        } else if (path.toLowerCase().endsWith('.gif')) {
          contentType = 'image/gif';
        } else if (path.toLowerCase().endsWith('.webp')) {
          contentType = 'image/webp';
        }
        return Response.ok(
          bytes,
          headers: {'Content-Type': contentType},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取正文图片
    router.get('/image', (Request request) async {
      try {
        final bookUrl = request.url.queryParameters['url'];
        final picUrl = request.url.queryParameters['path'];
        // width参数暂未使用（可用于图片缩放，后续可扩展）
        if (picUrl == null || picUrl.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '缺少path参数'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        // 构建完整URL（如果是相对路径）
        String fullUrl = picUrl;
        if (bookUrl != null &&
            bookUrl.isNotEmpty &&
            !picUrl.startsWith('http')) {
          final book = await BookService.instance.getBookByUrl(bookUrl);
          if (book != null) {
            final source = await BookSourceService.instance
                .getBookSourceByUrl(book.origin);
            if (source != null) {
              fullUrl = NetworkService.joinUrl(source.bookSourceUrl, picUrl);
            }
          }
        }
        // 获取图片
        final response = await NetworkService.instance.get(fullUrl);
        final bytes = await response.data;
        if (bytes == null) {
          return Response.notFound(
            jsonEncode({'isSuccess': false, 'errorMsg': '图片不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        // 根据文件扩展名确定Content-Type
        String contentType = 'image/jpeg';
        if (picUrl.toLowerCase().endsWith('.png')) {
          contentType = 'image/png';
        } else if (picUrl.toLowerCase().endsWith('.gif')) {
          contentType = 'image/gif';
        } else if (picUrl.toLowerCase().endsWith('.webp')) {
          contentType = 'image/webp';
        }
        return Response.ok(
          bytes,
          headers: {'Content-Type': contentType},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取替换规则
    router.get('/getReplaceRules', (Request request) async {
      try {
        final rules = await ReplaceRuleService.instance.getAllRules();
        final data = rules.map((ReplaceRule r) => r.toJson()).toList();
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': data}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取RSS源列表
    router.get('/getRssSources', (Request request) async {
      try {
        final sources = await RssService.instance.getAllRssSources();
        final data = sources.map((s) => s.toJson()).toList();
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': data}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取单个RSS源
    router.get('/getRssSource', (Request request) async {
      try {
        final url = request.url.queryParameters['url'];
        if (url == null || url.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '缺少url参数'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final source = await RssService.instance.getRssSourceByUrl(url);
        if (source == null) {
          return Response.notFound(
            jsonEncode({'isSuccess': false, 'errorMsg': 'RSS源不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': source.toJson()}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取阅读配置
    router.get('/getReadConfig', (Request request) async {
      try {
        final sharedConfigJson = AppConfig.getSharedReadConfig();
        if (sharedConfigJson == null || sharedConfigJson.isEmpty) {
          return Response.ok(
            jsonEncode({'isSuccess': true, 'data': null}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final configMap = jsonDecode(sharedConfigJson) as Map<String, dynamic>;
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': configMap}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 获取Web阅读配置
    router.get('/getWebReadConfig', (Request request) async {
      try {
        final configJson = AppConfig.getString('webReadConfig');
        if (configJson.isEmpty) {
          return Response.ok(
            jsonEncode({'isSuccess': false, 'errorMsg': '没有配置'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': configJson}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });
  }

  /// 设置POST路由
  void _setupPostRoutes(Router router) {
    // 保存书源
    router.post('/saveBookSource', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final source = BookSource.fromJson(json);
        await BookSourceService.instance.addBookSource(source);
        return Response.ok(
          jsonEncode({'isSuccess': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 批量保存书源
    router.post('/saveBookSources', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body);
        if (json is! List) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '请求体应为数组格式'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        int successCount = 0;
        for (final item in json) {
          if (item is Map<String, dynamic>) {
            try {
              final source = BookSource.fromJson(item);
              await BookSourceService.instance.addBookSource(source);
              successCount++;
            } catch (e) {
              AppLog.instance.put('保存书源失败', error: e);
            }
          }
        }
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': successCount}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 批量删除书源
    router.post('/deleteBookSources', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body);
        if (json is! List) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '请求体应为数组格式'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        int successCount = 0;
        for (final item in json) {
          if (item is Map<String, dynamic>) {
            try {
              final sourceUrl = item['bookSourceUrl'] as String?;
              if (sourceUrl != null) {
                await BookSourceService.instance.deleteBookSource(sourceUrl);
                successCount++;
              }
            } catch (e) {
              AppLog.instance.put('删除书源失败', error: e);
            }
          }
        }
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': successCount}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 保存书籍
    router.post('/saveBook', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final book = Book.fromJson(json);
        await BookService.instance.saveBook(book);
        return Response.ok(
          jsonEncode({'isSuccess': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 删除书籍
    router.post('/deleteBook', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final bookUrl = json['bookUrl'] as String?;
        if (bookUrl != null) {
          await BookService.instance.deleteBook(bookUrl);
        }
        return Response.ok(
          jsonEncode({'isSuccess': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 保存阅读进度
    router.post('/saveBookProgress', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final bookUrl = json['bookUrl'] as String?;
        if (bookUrl == null) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '缺少bookUrl参数'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final book = await BookService.instance.getBookByUrl(bookUrl);
        if (book == null) {
          return Response.notFound(
            jsonEncode({'isSuccess': false, 'errorMsg': '书籍不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        // 更新阅读进度
        final durChapterIndex = json['durChapterIndex'] as int?;
        final durChapterPos = json['durChapterPos'] as int?;
        final updatedBook = book.copyWith(
          durChapterIndex: durChapterIndex ?? book.durChapterIndex,
          durChapterPos: durChapterPos ?? book.durChapterPos,
        );
        await BookService.instance.saveBook(updatedBook);
        return Response.ok(
          jsonEncode({'isSuccess': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 保存阅读配置
    router.post('/saveReadConfig', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body);
        if (json is! Map<String, dynamic>) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '请求体格式错误'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final configJson = jsonEncode(json);
        await AppConfig.setSharedReadConfig(configJson);
        return Response.ok(
          jsonEncode({'isSuccess': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 刷新目录
    router.get('/refreshToc', (Request request) async {
      try {
        final url = request.url.queryParameters['url'];
        if (url == null || url.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '缺少url参数'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final book = await BookService.instance.getBookByUrl(url);
        if (book == null) {
          return Response.notFound(
            jsonEncode({'isSuccess': false, 'errorMsg': '书籍不存在'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final success = await BookService.instance.updateChapterList(book);
        return Response.ok(
          jsonEncode({'isSuccess': success}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 保存替换规则
    router.post('/saveReplaceRule', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final rule = ReplaceRule.fromJson(json);
        await ReplaceRuleService.instance.addOrUpdateRule(rule);
        return Response.ok(
          jsonEncode({'isSuccess': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 删除替换规则
    router.post('/deleteReplaceRule', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body);
        ReplaceRule rule;
        if (json is Map<String, dynamic>) {
          rule = ReplaceRule.fromJson(json);
        } else if (json is List &&
            json.isNotEmpty &&
            json.first is Map<String, dynamic>) {
          rule = ReplaceRule.fromJson(json.first as Map<String, dynamic>);
        } else {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '请求体格式错误'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        await ReplaceRuleService.instance.deleteRuleById(rule.id);
        return Response.ok(
          jsonEncode({'isSuccess': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 测试替换规则
    router.post('/testReplaceRule', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final ruleJson = json['rule'] as Map<String, dynamic>?;
        final text = json['text'] as String?;
        if (ruleJson == null || text == null) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '缺少rule或text参数'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        final rule = ReplaceRule.fromJson(ruleJson);
        // 应用替换规则
        String result = text;
        if (rule.isRegex) {
          try {
            final pattern = RegExp(rule.pattern, multiLine: true);
            result = result.replaceAll(pattern, rule.replacement);
          } catch (e) {
            return Response.badRequest(
              body: jsonEncode({'isSuccess': false, 'errorMsg': '正则表达式错误: $e'}),
              headers: {'Content-Type': 'application/json'},
            );
          }
        } else {
          result = result.replaceAll(rule.pattern, rule.replacement);
        }
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': result}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 保存RSS源
    router.post('/saveRssSource', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final source = RssSource.fromJson(json);
        await RssService.instance.addOrUpdateRssSource(source);
        return Response.ok(
          jsonEncode({'isSuccess': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 批量保存RSS源
    router.post('/saveRssSources', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body);
        if (json is! List) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '请求体应为数组格式'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        int successCount = 0;
        for (final item in json) {
          if (item is Map<String, dynamic>) {
            try {
              final source = RssSource.fromJson(item);
              await RssService.instance.addOrUpdateRssSource(source);
              successCount++;
            } catch (e) {
              AppLog.instance.put('保存RSS源失败', error: e);
            }
          }
        }
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': successCount}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 批量删除RSS源
    router.post('/deleteRssSources', (Request request) async {
      try {
        final body = await request.readAsString();
        final json = jsonDecode(body);
        if (json is! List) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '请求体应为数组格式'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        int successCount = 0;
        for (final item in json) {
          if (item is Map<String, dynamic>) {
            try {
              final sourceUrl = item['sourceUrl'] as String?;
              if (sourceUrl != null) {
                await RssService.instance.deleteRssSource(sourceUrl);
                successCount++;
              }
            } catch (e) {
              AppLog.instance.put('删除RSS源失败', error: e);
            }
          }
        }
        return Response.ok(
          jsonEncode({'isSuccess': true, 'data': successCount}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 保存Web阅读配置
    router.post('/saveWebReadConfig', (Request request) async {
      try {
        final body = await request.readAsString();
        if (body.isEmpty) {
          // 如果请求体为空，删除配置
          await AppConfig.setString('webReadConfig', '');
        } else {
          // 保存配置（可以是JSON字符串或普通字符串）
          await AppConfig.setString('webReadConfig', body);
        }
        return Response.ok(
          jsonEncode({'isSuccess': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // 添加本地书籍（文件上传）
    router.post('/addLocalBook', (Request request) async {
      try {
        // 检查 Content-Type
        final contentType = request.headers['content-type'] ?? '';
        if (!contentType.contains('multipart/form-data')) {
          return Response.badRequest(
            body: jsonEncode({
              'isSuccess': false,
              'errorMsg': 'Content-Type必须是multipart/form-data'
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 解析 multipart 数据
        final boundary = _extractBoundary(contentType);
        if (boundary == null) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': '无法解析boundary'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 读取请求体
        final bodyBytes = <int>[];
        await for (final chunk in request.read()) {
          bodyBytes.addAll(chunk);
        }
        final parts = _parseMultipart(bodyBytes, boundary);

        String? fileName;
        List<int>? fileData;

        for (final part in parts) {
          final headers = part['headers'] as Map<String, String>?;
          final content = part['content'] as List<int>?;

          if (headers == null || content == null) continue;

          // 查找 Content-Disposition 头
          final contentDisposition = headers['content-disposition'] ?? '';

          // 提取字段名和文件名
          final nameMatch =
              RegExp(r'name="([^"]+)"').firstMatch(contentDisposition);
          final filenameMatch =
              RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);

          if (nameMatch != null) {
            final fieldName = nameMatch.group(1);
            if (fieldName == 'fileName' && filenameMatch != null) {
              fileName = filenameMatch.group(1);
            } else if (fieldName == 'fileData') {
              fileData = content;
            }
          }
        }

        if (fileName == null || fileName.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': 'fileName 不能为空'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        if (fileData == null || fileData.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'isSuccess': false, 'errorMsg': 'fileData 不能为空'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 保存文件到临时目录
        final tempDir = await Directory.systemTemp.createTemp('legado_upload_');
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(fileData);

        try {
          // 导入书籍
          final book =
              await LocalBookService.instance.importBook(tempFile.path);
          if (book == null) {
            return Response.internalServerError(
              body: jsonEncode({'isSuccess': false, 'errorMsg': '导入书籍失败'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // 清理临时文件
          await tempFile.delete();
          await tempDir.delete();

          return Response.ok(
            jsonEncode({'isSuccess': true, 'data': true}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          // 清理临时文件
          try {
            await tempFile.delete();
            await tempDir.delete();
          } catch (_) {}

          return Response.internalServerError(
            body: jsonEncode(
                {'isSuccess': false, 'errorMsg': '保存书籍错误: ${e.toString()}'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'isSuccess': false, 'errorMsg': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });
  }

  /// 从 Content-Type 中提取 boundary
  String? _extractBoundary(String contentType) {
    final match = RegExp(r'boundary=([^;]+)').firstMatch(contentType);
    return match?.group(1)?.trim();
  }

  /// 解析 multipart/form-data
  List<Map<String, dynamic>> _parseMultipart(List<int> data, String boundary) {
    final parts = <Map<String, dynamic>>[];
    final boundaryBytes = utf8.encode('--$boundary');
    final endBoundaryBytes = utf8.encode('--$boundary--');

    int start = 0;
    while (start < data.length) {
      // 查找下一个 boundary
      int boundaryIndex = _findBytes(data, boundaryBytes, start);
      if (boundaryIndex == -1) {
        // 查找结束 boundary
        boundaryIndex = _findBytes(data, endBoundaryBytes, start);
        if (boundaryIndex == -1) break;
      }

      if (start < boundaryIndex) {
        // 提取 part 内容
        final partData = data.sublist(start, boundaryIndex);
        final part = _parsePart(partData);
        if (part.isNotEmpty) {
          parts.add(part);
        }
      }

      start = boundaryIndex + boundaryBytes.length;
      // 跳过 CRLF
      if (start < data.length && data[start] == 13) start++;
      if (start < data.length && data[start] == 10) start++;
    }

    return parts;
  }

  /// 在字节数组中查找子数组
  int _findBytes(List<int> data, List<int> pattern, int start) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  /// 解析单个 part
  Map<String, dynamic> _parsePart(List<int> partData) {
    final result = <String, dynamic>{};

    // 查找 header 和 body 的分隔符（两个 CRLF）
    int headerEnd = -1;
    for (int i = 0; i < partData.length - 3; i++) {
      if (partData[i] == 13 &&
          partData[i + 1] == 10 &&
          partData[i + 2] == 13 &&
          partData[i + 3] == 10) {
        headerEnd = i;
        break;
      }
    }

    if (headerEnd == -1) return result;

    // 解析 headers
    final headerBytes = partData.sublist(0, headerEnd);
    final headerText = utf8.decode(headerBytes);
    final headers = <String, String>{};

    for (final line in headerText.split('\r\n')) {
      if (line.isEmpty) continue;
      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final key = line.substring(0, colonIndex).trim().toLowerCase();
        final value = line.substring(colonIndex + 1).trim();
        headers[key] = value;
      }
    }

    // 提取 body（跳过两个 CRLF）
    final bodyStart = headerEnd + 4;
    // 移除末尾的 CRLF（如果有）
    int bodyEnd = partData.length;
    if (bodyEnd > bodyStart + 2 &&
        partData[bodyEnd - 2] == 13 &&
        partData[bodyEnd - 1] == 10) {
      bodyEnd -= 2;
    }

    final body = partData.sublist(bodyStart, bodyEnd);

    result['headers'] = headers;
    result['content'] = body;
    return result;
  }

  /// CORS中间件
  Middleware _corsMiddleware() {
    return createMiddleware(
      requestHandler: (Request request) {
        if (request.method == 'OPTIONS') {
          return Response.ok(
            '',
            headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
              'Access-Control-Allow-Headers': 'Content-Type',
            },
          );
        }
        return null;
      },
      responseHandler: (Response response) {
        return response.change(
          headers: {
            ...response.headers,
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
          },
        );
      },
    );
  }

  /// 获取本地IP地址
  Future<String> _getLocalIP() async {
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('获取本地IP失败', error: e);
    }
    return '127.0.0.1';
  }
}
