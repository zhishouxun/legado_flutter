import 'dart:async';
import '../../core/base/base_service.dart';
import '../../data/models/book_source.dart';
import '../../data/models/book.dart';
import '../book/book_service.dart';
import '../network/network_service.dart';
import '../explore_service.dart';
import '../../utils/parsers/rule_parser.dart';
import '../../utils/app_log.dart';
import '../../utils/cache_manager.dart';
import '../../config/app_config.dart';
import '../../core/constants/prefer_key.dart';
import '../notification_service.dart';

/// 校验结果
class CheckSourceResult {
  final String sourceUrl;
  final String sourceName;
  final bool success;
  final int respondTime; // 响应时间（毫秒）
  final Map<String, bool> checkItems; // 各项校验结果
  final String? errorMessage;

  CheckSourceResult({
    required this.sourceUrl,
    required this.sourceName,
    required this.success,
    required this.respondTime,
    required this.checkItems,
    this.errorMessage,
  });

  /// 获取校验摘要
  String getSummary() {
    final items = <String>[];
    checkItems.forEach((key, value) {
      if (value) {
        items.add(key);
      }
    });
    return items.join('、');
  }
}

/// 校验配置
class CheckSourceConfig {
  /// 校验关键字（用于搜索测试）
  String keyword = '我的';

  /// 超时时间（毫秒）
  int timeout = 180000; // 3分钟

  /// 是否校验搜索
  bool checkSearch = true;

  /// 是否校验发现
  bool checkDiscovery = true;

  /// 是否校验详情
  bool checkInfo = true;

  /// 是否校验目录
  bool checkCategory = true;

  /// 是否校验正文
  bool checkContent = true;

  /// 获取配置摘要
  String getSummary() {
    final items = <String>[];
    if (checkSearch) items.add('搜索');
    if (checkDiscovery) items.add('发现');
    if (checkInfo) items.add('详情');
    if (checkCategory) items.add('目录');
    if (checkContent) items.add('正文');
    return '超时: ${timeout ~/ 1000}秒, 校验项: ${items.join('、')}';
  }

  /// 保存配置
  Future<void> save() async {
    // 保存到AppConfig（优先）
    if (keyword.isNotEmpty) {
      await AppConfig.setString(PreferKey.checkSourceKeyword, keyword);
    }
    await AppConfig.setInt(PreferKey.checkSourceTimeout, timeout);
    await AppConfig.setBool(PreferKey.checkSourceSearch, checkSearch);
    await AppConfig.setBool(PreferKey.checkSourceDiscovery, checkDiscovery);
    await AppConfig.setBool(PreferKey.checkSourceInfo, checkInfo);
    await AppConfig.setBool(PreferKey.checkSourceCategory, checkCategory);
    await AppConfig.setBool(PreferKey.checkSourceContent, checkContent);

    // 同时保存到CacheManager（兼容旧代码）
    await CacheManager.instance.put('checkSourceKeyword', keyword);
    await CacheManager.instance.put('checkSourceTimeout', timeout);
    await CacheManager.instance.put('checkSearch', checkSearch.toString());
    await CacheManager.instance
        .put('checkDiscovery', checkDiscovery.toString());
    await CacheManager.instance.put('checkInfo', checkInfo.toString());
    await CacheManager.instance.put('checkCategory', checkCategory.toString());
    await CacheManager.instance.put('checkContent', checkContent.toString());
  }

  /// 加载配置
  static Future<CheckSourceConfig> load() async {
    final config = CheckSourceConfig();

    // 优先从AppConfig加载，如果没有则从CacheManager加载（兼容旧配置）
    final cacheManager = CacheManager.instance;

    // 关键字：优先从AppConfig加载
    String keyword = AppConfig.getString(PreferKey.checkSourceKeyword);
    if (keyword.isEmpty) {
      final keywordValue = await cacheManager.get('checkSourceKeyword');
      keyword = keywordValue ?? '我的';
    }

    // 超时时间：优先从AppConfig加载
    int timeoutMs =
        AppConfig.getInt(PreferKey.checkSourceTimeout, defaultValue: 0);
    if (timeoutMs == 0) {
      // 如果AppConfig中没有配置，从CacheManager加载（兼容旧配置）
      final timeoutValue = await cacheManager.getLong('checkSourceTimeout');
      timeoutMs = timeoutValue ?? 180000;
    }

    // 检查项：优先从AppConfig加载
    bool checkSearch =
        AppConfig.getBool(PreferKey.checkSourceSearch, defaultValue: true);
    bool checkDiscovery =
        AppConfig.getBool(PreferKey.checkSourceDiscovery, defaultValue: true);
    bool checkInfo =
        AppConfig.getBool(PreferKey.checkSourceInfo, defaultValue: false);
    bool checkCategory =
        AppConfig.getBool(PreferKey.checkSourceCategory, defaultValue: false);
    bool checkContent =
        AppConfig.getBool(PreferKey.checkSourceContent, defaultValue: false);

    // 如果AppConfig中没有配置，尝试从CacheManager加载（兼容旧配置）
    if (!AppConfig.getString(PreferKey.checkSourceSearch).isNotEmpty) {
      final checkSearchValue = await cacheManager.get('checkSearch');
      if (checkSearchValue != null) {
        checkSearch = checkSearchValue.toLowerCase() == 'true';
      }
    }
    if (!AppConfig.getString(PreferKey.checkSourceDiscovery).isNotEmpty) {
      final checkDiscoveryValue = await cacheManager.get('checkDiscovery');
      if (checkDiscoveryValue != null) {
        checkDiscovery = checkDiscoveryValue.toLowerCase() == 'true';
      }
    }
    if (!AppConfig.getString(PreferKey.checkSourceInfo).isNotEmpty) {
      final checkInfoValue = await cacheManager.get('checkInfo');
      if (checkInfoValue != null) {
        checkInfo = checkInfoValue.toLowerCase() == 'true';
      }
    }
    if (!AppConfig.getString(PreferKey.checkSourceCategory).isNotEmpty) {
      final checkCategoryValue = await cacheManager.get('checkCategory');
      if (checkCategoryValue != null) {
        checkCategory = checkCategoryValue.toLowerCase() == 'true';
      }
    }
    if (!AppConfig.getString(PreferKey.checkSourceContent).isNotEmpty) {
      final checkContentValue = await cacheManager.get('checkContent');
      if (checkContentValue != null) {
        checkContent = checkContentValue.toLowerCase() == 'true';
      }
    }

    config.keyword = keyword;
    config.timeout = timeoutMs;
    config.checkSearch = checkSearch;
    config.checkDiscovery = checkDiscovery;
    config.checkInfo = checkInfo;
    config.checkCategory = checkCategory;
    config.checkContent = checkContent;

    return config;
  }
}

/// 书源批量校验服务
/// 参考项目：io.legado.app.model.CheckSource 和 CheckSourceService
class CheckSourceService extends BaseService {
  static final CheckSourceService instance = CheckSourceService._init();
  final BookService _bookService = BookService.instance;
  final NetworkService _networkService = NetworkService.instance;
  final ExploreService _exploreService = ExploreService.instance;

  static const int notificationId = 100; // 参考项目：NotificationId.CheckSource

  CheckSourceService._init();

  /// 校验配置
  late final CheckSourceConfig config;

  /// 初始化配置
  @override
  Future<void> init() async {
    config = await CheckSourceConfig.load();
  }

  /// 是否正在校验
  bool _isChecking = false;

  /// 是否已暂停
  bool _isPaused = false;

  /// 当前校验的书源列表
  final List<BookSource> _sources = [];

  /// 校验结果列表
  final List<CheckSourceResult> _results = [];

  /// 进度回调
  Function(int current, int total, CheckSourceResult? result)? onProgress;

  /// 完成回调
  Function(List<CheckSourceResult> results)? onComplete;

  /// 开始批量校验
  /// [sources] 要校验的书源列表
  /// [showNotification] 是否显示通知
  Future<void> startCheck(
    List<BookSource> sources, {
    bool showNotification = false,
  }) async {
    if (_isChecking) {
      AppLog.instance.put('校验已在进行中');
      return;
    }

    _isChecking = true;
    _isPaused = false;
    _sources.clear();
    _sources.addAll(sources);
    _results.clear();

    // 显示通知（如果启用）
    if (showNotification) {
      await NotificationService.instance.showProgressNotification(
        id: notificationId,
        title: '校验书源',
        content: '正在校验 ${sources.length} 个书源',
        progress: 0.0,
        max: sources.length,
        current: 0,
        isOngoing: true,
        channelId: NotificationService.channelIdCheckSource,
      );
    }

    try {
      for (int i = 0; i < _sources.length; i++) {
        // 检查是否已暂停
        while (_isPaused) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // 检查是否已停止
        if (!_isChecking) {
          break;
        }

        final source = _sources[i];
        final result = await _checkSource(source);
        _results.add(result);

        // 通知进度
        onProgress?.call(i + 1, _sources.length, result);

        // 更新通知
        if (showNotification) {
          final progress = (i + 1) / _sources.length;
          final successCount = _results.where((r) => r.success).length;
          await NotificationService.instance.showProgressNotification(
            id: notificationId,
            title: '校验书源',
            content: '已校验: $successCount/${i + 1} 成功',
            progress: progress,
            max: _sources.length,
            current: i + 1,
            isOngoing: true,
            channelId: NotificationService.channelIdCheckSource,
          );
        }
      }

      // 校验完成
      final successCount = _results.where((r) => r.success).length;

      // 完成通知
      if (showNotification) {
        await NotificationService.instance.showNotification(
          id: notificationId,
          title: '校验完成',
          content: '$successCount/${_sources.length} 个书源校验成功',
          isOngoing: false,
          channelId: NotificationService.channelIdCheckSource,
        );
      }

      onComplete?.call(_results);
    } catch (e) {
      // 错误通知
      if (showNotification) {
        await NotificationService.instance.showNotification(
          id: notificationId,
          title: '校验失败',
          content: '批量校验失败: ${e.toString()}',
          isOngoing: false,
          channelId: NotificationService.channelIdCheckSource,
        );
      }
      AppLog.instance.put('批量校验失败', error: e);
    } finally {
      _isChecking = false;
      _isPaused = false;
    }
  }

  /// 校验单个书源
  Future<CheckSourceResult> _checkSource(BookSource source) async {
    final startTime = DateTime.now();
    final checkItems = <String, bool>{};
    String? errorMessage;

    try {
      // 校验搜索
      if (config.checkSearch) {
        try {
          final success = await _checkSearch(source);
          checkItems['搜索'] = success;
        } catch (e) {
          checkItems['搜索'] = false;
          errorMessage = '搜索校验失败: $e';
        }
      }

      // 校验发现
      if (config.checkDiscovery) {
        try {
          final success = await _checkDiscovery(source);
          checkItems['发现'] = success;
        } catch (e) {
          checkItems['发现'] = false;
          errorMessage ??= '发现校验失败: $e';
        }
      }

      // 校验详情
      if (config.checkInfo) {
        try {
          final success = await _checkInfo(source);
          checkItems['详情'] = success;
        } catch (e) {
          checkItems['详情'] = false;
          errorMessage ??= '详情校验失败: $e';
        }
      }

      // 校验目录
      if (config.checkCategory) {
        try {
          final success = await _checkCategory(source);
          checkItems['目录'] = success;
        } catch (e) {
          checkItems['目录'] = false;
          errorMessage ??= '目录校验失败: $e';
        }
      }

      // 校验正文
      if (config.checkContent) {
        try {
          final success = await _checkContent(source);
          checkItems['正文'] = success;
        } catch (e) {
          checkItems['正文'] = false;
          errorMessage ??= '正文校验失败: $e';
        }
      }

      final endTime = DateTime.now();
      final respondTime = endTime.difference(startTime).inMilliseconds;

      // 判断是否成功（至少有一项成功）
      final success = checkItems.values.any((value) => value);

      return CheckSourceResult(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        success: success,
        respondTime: respondTime,
        checkItems: checkItems,
        errorMessage: errorMessage,
      );
    } catch (e) {
      final endTime = DateTime.now();
      final respondTime = endTime.difference(startTime).inMilliseconds;

      return CheckSourceResult(
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        success: false,
        respondTime: respondTime,
        checkItems: checkItems,
        errorMessage: '校验异常: $e',
      );
    }
  }

  /// 校验搜索
  Future<bool> _checkSearch(BookSource source) async {
    if (source.searchUrl == null || source.ruleSearch == null) {
      return false;
    }

    try {
      // 构建搜索URL
      final searchUrl = source.searchUrl!
          .replaceAll('{{key}}', Uri.encodeComponent(config.keyword));
      final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, searchUrl);

      // 发送请求（带超时）
      final response = await _networkService
          .get(
            fullUrl,
            headers: NetworkService.parseHeaders(source.header),
            retryCount: 1,
          )
          .timeout(Duration(milliseconds: config.timeout));

      final html = await NetworkService.getResponseText(response);

      // 解析搜索结果
      final results = await RuleParser.parseSearchRule(
        html,
        source.ruleSearch!,
        variables: {'keyword': config.keyword},
        baseUrl: source.bookSourceUrl,
      );

      return results.isNotEmpty;
    } catch (e) {
      AppLog.instance.put('搜索校验失败: ${source.bookSourceName}', error: e);
      return false;
    }
  }

  /// 校验发现
  Future<bool> _checkDiscovery(BookSource source) async {
    if (source.exploreUrl == null || source.ruleExplore == null) {
      return false;
    }

    try {
      // 获取发现书籍
      final books = await _exploreService
          .exploreBooks(
            source,
            source.exploreUrl!,
            page: 1,
          )
          .timeout(Duration(milliseconds: config.timeout));

      return books.isNotEmpty;
    } catch (e) {
      AppLog.instance.put('发现校验失败: ${source.bookSourceName}', error: e);
      return false;
    }
  }

  /// 校验详情
  Future<bool> _checkInfo(BookSource source) async {
    if (source.ruleBookInfo == null) {
      return false;
    }

    try {
      // 先搜索一本书
      if (source.searchUrl == null || source.ruleSearch == null) {
        return false;
      }

      final searchUrl = source.searchUrl!
          .replaceAll('{{key}}', Uri.encodeComponent(config.keyword));
      final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, searchUrl);

      final response = await _networkService
          .get(
            fullUrl,
            headers: NetworkService.parseHeaders(source.header),
            retryCount: 1,
          )
          .timeout(Duration(milliseconds: config.timeout));

      final html = await NetworkService.getResponseText(response);

      final searchResults = await RuleParser.parseSearchRule(
        html,
        source.ruleSearch!,
        variables: {'keyword': config.keyword},
        baseUrl: source.bookSourceUrl,
      );

      if (searchResults.isEmpty) {
        return false;
      }

      // 获取第一本书的详情
      final firstResult = searchResults.first;
      final bookUrl = firstResult['bookUrl'];
      if (bookUrl == null || bookUrl.isEmpty) {
        return false;
      }

      final fullBookUrl = NetworkService.joinUrl(source.bookSourceUrl, bookUrl);

      // 创建临时Book对象
      final book = Book(
        bookUrl: fullBookUrl,
        origin: source.bookSourceUrl,
        originName: source.bookSourceName,
      );

      // 获取书籍详情
      final bookInfo = await _bookService.getBookInfo(book).timeout(
            Duration(milliseconds: config.timeout),
          );

      return bookInfo != null && bookInfo.name.isNotEmpty;
    } catch (e) {
      AppLog.instance.put('详情校验失败: ${source.bookSourceName}', error: e);
      return false;
    }
  }

  /// 校验目录
  Future<bool> _checkCategory(BookSource source) async {
    if (source.ruleToc == null) {
      return false;
    }

    try {
      // 先获取一本书的详情
      if (source.searchUrl == null || source.ruleSearch == null) {
        return false;
      }

      final searchUrl = source.searchUrl!
          .replaceAll('{{key}}', Uri.encodeComponent(config.keyword));
      final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, searchUrl);

      final response = await _networkService
          .get(
            fullUrl,
            headers: NetworkService.parseHeaders(source.header),
            retryCount: 1,
          )
          .timeout(Duration(milliseconds: config.timeout));

      final html = await NetworkService.getResponseText(response);

      final searchResults = await RuleParser.parseSearchRule(
        html,
        source.ruleSearch!,
        variables: {'keyword': config.keyword},
        baseUrl: source.bookSourceUrl,
      );

      if (searchResults.isEmpty) {
        return false;
      }

      // 获取第一本书的详情
      final firstResult = searchResults.first;
      final bookUrl = firstResult['bookUrl'];
      if (bookUrl == null || bookUrl.isEmpty) {
        return false;
      }

      final fullBookUrl = NetworkService.joinUrl(source.bookSourceUrl, bookUrl);

      final book = Book(
        bookUrl: fullBookUrl,
        origin: source.bookSourceUrl,
        originName: source.bookSourceName,
      );

      final bookInfo = await _bookService.getBookInfo(book).timeout(
            Duration(milliseconds: config.timeout),
          );

      if (bookInfo == null) {
        return false;
      }

      // 获取章节列表
      final chapters = await _bookService.getChapterList(bookInfo).timeout(
            Duration(milliseconds: config.timeout),
          );

      return chapters.isNotEmpty;
    } catch (e) {
      AppLog.instance.put('目录校验失败: ${source.bookSourceName}', error: e);
      return false;
    }
  }

  /// 校验正文
  Future<bool> _checkContent(BookSource source) async {
    if (source.ruleContent == null) {
      return false;
    }

    try {
      // 先获取一本书的章节
      if (source.searchUrl == null || source.ruleSearch == null) {
        return false;
      }

      final searchUrl = source.searchUrl!
          .replaceAll('{{key}}', Uri.encodeComponent(config.keyword));
      final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, searchUrl);

      final response = await _networkService
          .get(
            fullUrl,
            headers: NetworkService.parseHeaders(source.header),
            retryCount: 1,
          )
          .timeout(Duration(milliseconds: config.timeout));

      final html = await NetworkService.getResponseText(response);

      final searchResults = await RuleParser.parseSearchRule(
        html,
        source.ruleSearch!,
        variables: {'keyword': config.keyword},
        baseUrl: source.bookSourceUrl,
      );

      if (searchResults.isEmpty) {
        return false;
      }

      // 获取第一本书的详情
      final firstResult = searchResults.first;
      final bookUrl = firstResult['bookUrl'];
      if (bookUrl == null || bookUrl.isEmpty) {
        return false;
      }

      final fullBookUrl = NetworkService.joinUrl(source.bookSourceUrl, bookUrl);

      final book = Book(
        bookUrl: fullBookUrl,
        origin: source.bookSourceUrl,
        originName: source.bookSourceName,
      );

      final bookInfo = await _bookService.getBookInfo(book).timeout(
            Duration(milliseconds: config.timeout),
          );

      if (bookInfo == null) {
        return false;
      }

      // 获取章节列表
      final chapters = await _bookService.getChapterList(bookInfo).timeout(
            Duration(milliseconds: config.timeout),
          );

      if (chapters.isEmpty) {
        return false;
      }

      // 获取第一个章节的内容
      final firstChapter = chapters.first;
      final content = await _bookService
          .getChapterContent(
            firstChapter,
            source,
            bookName: bookInfo.name,
            bookOrigin: bookInfo.origin,
          )
          .timeout(Duration(milliseconds: config.timeout));

      return content != null && content.isNotEmpty;
    } catch (e) {
      AppLog.instance.put('正文校验失败: ${source.bookSourceName}', error: e);
      return false;
    }
  }

  /// 停止校验
  void stop() {
    _isChecking = false;
    _isPaused = false;
  }

  /// 暂停校验
  void pause() {
    _isPaused = true;
  }

  /// 恢复校验
  void resume() {
    _isPaused = false;
  }

  /// 是否正在校验
  bool get isChecking => _isChecking;

  /// 是否已暂停
  bool get isPaused => _isPaused;

  /// 获取校验结果
  List<CheckSourceResult> get results => List.unmodifiable(_results);

  /// 获取校验统计
  Map<String, dynamic> getStatistics() {
    final total = _results.length;
    final success = _results.where((r) => r.success).length;
    final failed = total - success;
    final avgRespondTime = total > 0
        ? _results.map((r) => r.respondTime).reduce((a, b) => a + b) ~/ total
        : 0;

    return {
      'total': total,
      'success': success,
      'failed': failed,
      'avgRespondTime': avgRespondTime,
    };
  }
}
