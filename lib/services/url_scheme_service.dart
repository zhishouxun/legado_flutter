import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/base/base_service.dart';
import '../data/models/rss_source.dart';
import '../data/models/replace_rule.dart';
import '../data/models/dict_rule.dart';
import 'rss_service.dart';
import 'replace_rule_service.dart';
import 'dict_rule_service.dart';
import 'theme_service.dart';
import 'network/network_service.dart';
import '../utils/app_log.dart';
import '../config/app_config.dart';
import 'qrcode_result_handler.dart';

// 条件导入 app_links（仅非Web平台）
import 'package:app_links/app_links.dart' if (dart.library.html) '../services/url_scheme_service_stub.dart';

/// URL Scheme 服务
class UrlSchemeService extends BaseService {
  static final UrlSchemeService instance = UrlSchemeService._init();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  UrlSchemeService._init();

  /// 初始化URL Scheme监听
  @override
  Future<void> onInit() async {
    if (kIsWeb) {
      // Web平台不支持URL Scheme
      return;
    }

    // 监听应用启动时的URL
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleUrl(uri);
      }
    });

    // 监听应用运行时的URL
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleUrl(uri);
      },
      onError: (err) {
        AppLog.instance.put('URL Scheme监听错误: $err', error: err);
      },
    );
  }

  /// 处理URL
  Future<void> _handleUrl(Uri uri) async {
    try {
      AppLog.instance.put('收到URL Scheme: ${uri.toString()}');

      // 解析URL格式: legado://import/{path}?src={url}&name={name}&author={author}
      if (uri.scheme != 'legado') {
        return;
      }

      // 支持路径格式: /import/{type} 或 /{type}
      final pathSegments = uri.pathSegments;
      final path = pathSegments.isNotEmpty ? pathSegments.first : '';
      final queryParams = uri.queryParameters;

      // 支持多种路径格式
      switch (path) {
        case 'import':
        case 'importonline':
          // legado://import/{type}?src={url} 或 legado://importonline?src={url}
          await _handleImport(queryParams, uri.host);
          break;
        case 'book':
        case 'addToBookshelf':
          // legado://book?url={bookUrl}&origin={sourceUrl}&name={name}&author={author}
          await _handleAddBook(queryParams);
          break;
        case 'source':
        case 'bookSource':
          // legado://source?src={url} 或 legado://bookSource?src={url}
          await _handleImportSource(queryParams);
          break;
        case 'rssSource':
          // legado://rssSource?src={url}
          await _handleImportRssSource(queryParams);
          break;
        case 'replaceRule':
          // legado://replaceRule?src={url}
          await _handleImportReplaceRule(queryParams);
          break;
        case 'dictRule':
          // legado://dictRule?src={url}
          await _handleImportDictRule(queryParams);
          break;
        case 'theme':
          // 主题导入
          await _handleImportTheme(queryParams);
          break;
        case 'bookshelf':
          // 打开书架页面
          await _handleOpenBookshelf();
          break;
        case 'read':
          // 打开阅读页面
          await _handleOpenRead(queryParams);
          break;
        case 'readAloud':
          // 打开朗读功能
          await _handleOpenReadAloud();
          break;
        default:
          // 如果没有匹配的路径，尝试自动判断类型
          if (queryParams.containsKey('src')) {
            await _handleImport(queryParams, uri.host);
          } else {
            AppLog.instance.put('未知的URL Scheme路径: $path');
          }
      }
    } catch (e) {
      AppLog.instance.put('处理URL Scheme失败: $e', error: e);
    }
  }

  /// 处理导入
  Future<void> _handleImport(Map<String, String> params, [String? host]) async {
    final src = params['src'];
    if (src == null || src.isEmpty) {
      AppLog.instance.put('导入URL为空');
      return;
    }

    try {
      // 根据host判断类型（如果提供了host）
      if (host != null && host.isNotEmpty) {
        switch (host) {
          case 'booksource':
            await _handleImportSource(params);
            return;
          case 'rsssource':
            await _handleImportRssSource(params);
            return;
          case 'replace':
            await _handleImportReplaceRule(params);
            return;
        }
      }

      // 尝试从URL获取内容并自动判断类型
      final handled = await QrcodeResultHandler.instance.handleResult(src);
      if (!handled) {
        AppLog.instance.put('无法自动处理导入URL: $src');
      }
    } catch (e) {
      AppLog.instance.put('导入失败: $e', error: e);
    }
  }

  /// 处理添加到书架
  /// 参考项目：UrlSchemeService._handleAddBook()
  /// 使用AddToBookshelfDialog处理
  Future<void> _handleAddBook(Map<String, String> params) async {
    final bookUrl = params['url'] ?? params['bookUrl'] ?? '';

    if (bookUrl.isEmpty) {
      AppLog.instance.put('书籍URL为空');
      return;
    }

    // 通过AppConfig设置导航，由LegadoApp处理
    await AppConfig.setString('pending_navigation', 'addToBookshelf');
    await AppConfig.setString('pending_book_url', bookUrl);
    AppLog.instance.put('收到添加到书架请求: $bookUrl');
  }

  /// 处理导入书源
  Future<void> _handleImportSource(Map<String, String> params) async {
    final src = params['src'] ?? params['url'] ?? '';
    if (src.isEmpty) {
      AppLog.instance.put('书源URL为空');
      return;
    }

    try {
      // 使用二维码结果处理器处理书源导入
      final handled = await QrcodeResultHandler.instance.handleResult(src);
      if (!handled) {
        AppLog.instance.put('无法自动处理书源URL: $src');
      }
    } catch (e) {
      AppLog.instance.put('导入书源失败: $e', error: e);
    }
  }

  /// 处理导入RSS源
  Future<void> _handleImportRssSource(Map<String, String> params) async {
    final src = params['src'] ?? params['url'] ?? '';
    if (src.isEmpty) {
      AppLog.instance.put('RSS源URL为空');
      return;
    }

    try {
      // 从URL获取内容
      final response = await NetworkService.instance.get(src, retryCount: 1);
      final content = await NetworkService.getResponseText(response);
      
      if (content.isEmpty) {
        AppLog.instance.put('RSS源内容为空');
        return;
      }

      // 解析JSON
      final json = jsonDecode(content);
      
      if (json is Map) {
        // 单个RSS源
        final source = RssSource.fromJson(Map<String, dynamic>.from(json));
        await RssService.instance.addOrUpdateRssSource(source);
        AppLog.instance.put('RSS源导入成功: ${source.sourceName}');
      } else if (json is List) {
        // 批量导入
        for (final item in json) {
          if (item is Map) {
            final source = RssSource.fromJson(Map<String, dynamic>.from(item));
            await RssService.instance.addOrUpdateRssSource(source);
          }
        }
        AppLog.instance.put('RSS源批量导入成功: ${json.length} 个');
      }
    } catch (e) {
      AppLog.instance.put('导入RSS源失败: $e', error: e);
    }
  }

  /// 处理导入替换规则
  Future<void> _handleImportReplaceRule(Map<String, String> params) async {
    final src = params['src'] ?? params['url'] ?? '';
    if (src.isEmpty) {
      AppLog.instance.put('替换规则URL为空');
      return;
    }

    try {
      // 从URL获取内容
      final response = await NetworkService.instance.get(src, retryCount: 1);
      final content = await NetworkService.getResponseText(response);
      
      if (content.isEmpty) {
        AppLog.instance.put('替换规则内容为空');
        return;
      }

      // 解析JSON
      final json = jsonDecode(content);
      
      if (json is Map) {
        // 单个替换规则
        final rule = ReplaceRule.fromJson(Map<String, dynamic>.from(json));
        await ReplaceRuleService.instance.addOrUpdateRule(rule);
        AppLog.instance.put('替换规则导入成功: ${rule.name}');
      } else if (json is List) {
        // 批量导入
        for (final item in json) {
          if (item is Map) {
            final rule = ReplaceRule.fromJson(Map<String, dynamic>.from(item));
            await ReplaceRuleService.instance.addOrUpdateRule(rule);
          }
        }
        AppLog.instance.put('替换规则批量导入成功: ${json.length} 个');
      }
    } catch (e) {
      AppLog.instance.put('导入替换规则失败: $e', error: e);
    }
  }

  /// 处理导入主题
  Future<void> _handleImportTheme(Map<String, String> params) async {
    final src = params['src'] ?? params['url'] ?? '';
    if (src.isEmpty) {
      AppLog.instance.put('主题URL为空');
      return;
    }

    try {
      // 从URL获取内容
      final response = await NetworkService.instance.get(src, retryCount: 1);
      final content = await NetworkService.getResponseText(response);
      
      if (content.isEmpty) {
        AppLog.instance.put('主题内容为空');
        return;
      }

      // 解析JSON并导入主题
      final success = await ThemeService.instance.addConfigFromJson(content);
      
      if (success) {
        AppLog.instance.put('主题导入成功');
      } else {
        AppLog.instance.put('主题导入失败：格式不正确');
      }
    } catch (e) {
      AppLog.instance.put('导入主题失败: $e', error: e);
    }
  }

  /// 处理打开书架页面
  Future<void> _handleOpenBookshelf() async {
    try {
      // 使用 AppConfig 存储导航信息，主页面会监听并处理
      await AppConfig.setString('pending_navigation', 'bookshelf');
      AppLog.instance.put('导航到书架页面');
    } catch (e) {
      AppLog.instance.put('打开书架页面失败: $e', error: e);
    }
  }

  /// 处理打开阅读页面
  Future<void> _handleOpenRead(Map<String, String> params) async {
    try {
      final bookUrl = params['url'] ?? '';
      if (bookUrl.isEmpty) {
        AppLog.instance.put('书籍URL为空');
        return;
      }

      // 使用 AppConfig 存储导航信息
      await AppConfig.setString('pending_navigation', 'read');
      await AppConfig.setString('pending_navigation_book_url', bookUrl);
      AppLog.instance.put('导航到阅读页面: $bookUrl');
    } catch (e) {
      AppLog.instance.put('打开阅读页面失败: $e', error: e);
    }
  }

  /// 处理打开朗读功能
  Future<void> _handleOpenReadAloud() async {
    try {
      // 使用 AppConfig 存储导航信息
      await AppConfig.setString('pending_navigation', 'readAloud');
      AppLog.instance.put('导航到朗读功能');
    } catch (e) {
      AppLog.instance.put('打开朗读功能失败: $e', error: e);
    }
  }

  /// 处理导入字典规则
  Future<void> _handleImportDictRule(Map<String, String> params) async {
    final src = params['src'] ?? params['url'] ?? '';
    if (src.isEmpty) {
      AppLog.instance.put('字典规则URL为空');
      return;
    }

    try {
      // 从URL获取内容
      final response = await NetworkService.instance.get(src, retryCount: 1);
      final content = await NetworkService.getResponseText(response);
      
      if (content.isEmpty) {
        AppLog.instance.put('字典规则内容为空');
        return;
      }

      // 解析JSON
      final json = jsonDecode(content);
      
      if (json is Map) {
        // 单个字典规则
        final rule = DictRule.fromJson(Map<String, dynamic>.from(json));
        await DictRuleService.instance.addOrUpdateRule(rule);
        AppLog.instance.put('字典规则导入成功: ${rule.name}');
      } else if (json is List) {
        // 批量导入
        for (final item in json) {
          if (item is Map) {
            final rule = DictRule.fromJson(Map<String, dynamic>.from(item));
            await DictRuleService.instance.addOrUpdateRule(rule);
          }
        }
        AppLog.instance.put('字典规则批量导入成功: ${json.length} 个');
      }
    } catch (e) {
      AppLog.instance.put('导入字典规则失败: $e', error: e);
    }
  }

  /// 销毁服务
  @override
  Future<void> onDispose() async {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}

