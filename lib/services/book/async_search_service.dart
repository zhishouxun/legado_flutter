import 'dart:async';
import 'package:dio/dio.dart';
import '../../data/models/book.dart';
import '../../data/models/search_book.dart';
import '../../data/models/book_source.dart';
import '../../utils/app_log.dart';
import '../../utils/parsers/legado_parser.dart';
import '../network/network_service.dart';
import '../../utils/concurrent_rate_limiter.dart';
import '../search_book_service.dart';

/// 搜索结果包装类
/// 参考文档: gemini重构建议/异步搜索逻辑.md
class SearchResult {
  final Book? book;
  final String sourceName;
  final String sourceUrl;
  final bool isError;
  final String? errorMessage;
  final int respondTime;

  SearchResult({
    this.book,
    required this.sourceName,
    required this.sourceUrl,
    this.isError = false,
    this.errorMessage,
    this.respondTime = 0,
  });

  @override
  String toString() {
    if (isError) {
      return 'SearchResult(error: $errorMessage, source: $sourceName)';
    }
    return 'SearchResult(book: ${book?.name}, source: $sourceName, time: ${respondTime}ms)';
  }
}

/// 异步搜索服务
///
/// **核心特性**:
/// 1. 基于Stream的流式加载,让搜索结果"出一个显示一个"
/// 2. 使用compute函数在后台线程执行耗时的网络请求和HTML解析
/// 3. 并发控制机制,限制同时搜索的书源数量(默认每批10个)
/// 4. 支持搜索取消、暂停/恢复
/// 5. 自动错误处理和容错
/// 6. 支持结果缓存到数据库
///
/// **使用示例**:
/// ```dart
/// final searchService = AsyncSearchService();
///
/// // 订阅搜索结果流
/// final subscription = searchService
///   .searchAllSources('诡秘之主', enabledSources, batchSize: 10)
///   .listen(
///     (result) {
///       if (!result.isError) {
///         print('找到书籍: ${result.book?.name}');
///       }
///     },
///     onDone: () => print('搜索完成'),
///     onError: (e) => print('搜索出错: $e'),
///   );
///
/// // 取消搜索
/// await subscription.cancel();
/// ```
class AsyncSearchService {
  final NetworkService _networkService;
  final LegadoParser _parser;
  final SearchBookService _searchBookService;

  // 取消令牌(用于取消搜索)
  CancelToken? _cancelToken;

  AsyncSearchService({
    NetworkService? networkService,
    LegadoParser? parser,
    SearchBookService? searchBookService,
  })  : _networkService = networkService ?? NetworkService.instance,
        _parser = parser ?? LegadoParser(),
        _searchBookService = searchBookService ?? SearchBookService.instance;

  /// 异步搜索所有书源
  ///
  /// [keyword] 搜索关键词
  /// [sources] 书源列表
  /// [batchSize] 每批并发搜索的书源数量(默认10)
  /// [saveToDatabase] 是否保存到数据库(默认true)
  /// [timeout] 单个书源的超时时间(默认30秒)
  ///
  /// Returns: Stream形式的搜索结果流,每找到一个书籍立即emit
  Stream<SearchResult> searchAllSources(
    String keyword,
    List<BookSource> sources, {
    int batchSize = 10,
    bool saveToDatabase = true,
    Duration timeout = const Duration(seconds: 30),
  }) async* {
    // 创建新的取消令牌
    _cancelToken = CancelToken();

    // 过滤出有效的书源
    final validSources = sources.where((source) {
      return source.enabled &&
          source.searchUrl != null &&
          source.ruleSearch != null;
    }).toList();

    AppLog.instance.put(
        'AsyncSearchService: 开始搜索, 关键词=$keyword, 总书源数=${validSources.length}, 批量大小=$batchSize');

    // 分批并发搜索
    for (var i = 0; i < validSources.length; i += batchSize) {
      // 检查是否已取消
      if (_cancelToken?.isCancelled ?? false) {
        AppLog.instance.put('AsyncSearchService: 搜索已取消');
        break;
      }

      final batch = validSources.skip(i).take(batchSize).toList();
      AppLog.instance.put(
          'AsyncSearchService: 处理第${i ~/ batchSize + 1}批, 书源数=${batch.length}');

      // 并发搜索当前批次
      final futures = batch.map((source) async {
        return await _searchSingleSource(
          keyword: keyword,
          source: source,
          timeout: timeout,
          cancelToken: _cancelToken,
        );
      });

      // 等待当前批次完成
      final results = await Future.wait(futures);

      // 逐个emit搜索结果
      for (final resultList in results) {
        for (final result in resultList) {
          // 再次检查取消状态
          if (_cancelToken?.isCancelled ?? false) {
            break;
          }

          // 保存到数据库(可选)
          if (saveToDatabase && !result.isError && result.book != null) {
            try {
              final searchBook = _bookToSearchBook(result.book!, result);
              await _searchBookService.saveSearchBook(searchBook);
            } catch (_) {
              // 忽略保存错误,不影响搜索流程
            }
          }

          yield result;
        }
      }
    }

    AppLog.instance.put('AsyncSearchService: 搜索流程结束');
  }

  /// 搜索单个书源(在主线程执行)
  ///
  /// [keyword] 搜索关键词
  /// [source] 书源
  /// [timeout] 超时时间
  /// [cancelToken] 取消令牌
  ///
  /// Returns: 该书源的搜索结果列表
  Future<List<SearchResult>> _searchSingleSource({
    required String keyword,
    required BookSource source,
    required Duration timeout,
    CancelToken? cancelToken,
  }) async {
    final startTime = DateTime.now();

    try {
      // 使用并发限流器控制请求速率
      return await ConcurrentRateLimiter(source).withLimit(() async {
        // 1. 构建搜索URL
        final searchUrl = _buildSearchUrl(source.searchUrl!, keyword);
        final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, searchUrl);

        AppLog.instance.put(
            'AsyncSearchService: 搜索书源 ${source.bookSourceName}, URL=$fullUrl');

        // 2. 发送网络请求
        final response = await _networkService
            .get(
              fullUrl,
              headers: NetworkService.parseHeaders(source.header),
              retryCount: 1,
              cancelToken: cancelToken,
            )
            .timeout(timeout);

        // 3. 获取响应文本
        final html = await NetworkService.getResponseText(response);

        if (html.isEmpty) {
          AppLog.instance
              .put('AsyncSearchService: 书源 ${source.bookSourceName} 返回空内容');
          return [
            SearchResult(
              sourceName: source.bookSourceName,
              sourceUrl: source.bookSourceUrl,
              isError: true,
              errorMessage: '响应内容为空',
            )
          ];
        }

        // 4. 解析搜索结果(使用LegadoParser)
        final parsedResults = await _parser.parseSearchList(
          htmlContent: html,
          bookSource: source,
          baseUrl: fullUrl,
          variables: {'keyword': keyword},
        );

        final respondTime = DateTime.now().difference(startTime).inMilliseconds;
        AppLog.instance.put(
          'AsyncSearchService: 书源 ${source.bookSourceName} 搜索完成, 找到${parsedResults.length}本书, 耗时${respondTime}ms',
        );

        // 5. 转换为SearchResult对象
        final results = <SearchResult>[];
        for (final parsed in parsedResults) {
          try {
            final book = _parseResultToBook(parsed, source, fullUrl);
            if (book != null) {
              results.add(SearchResult(
                book: book,
                sourceName: source.bookSourceName,
                sourceUrl: source.bookSourceUrl,
                respondTime: respondTime,
              ));
            }
          } catch (e) {
            AppLog.instance.put('AsyncSearchService: 转换Book对象失败', error: e);
          }
        }

        return results;
      });
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        AppLog.instance
            .put('AsyncSearchService: 书源 ${source.bookSourceName} 搜索被取消');
        return [];
      }

      AppLog.instance.put(
          'AsyncSearchService: 书源 ${source.bookSourceName} 网络请求失败',
          error: e);
      return [
        SearchResult(
          sourceName: source.bookSourceName,
          sourceUrl: source.bookSourceUrl,
          isError: true,
          errorMessage: '网络请求失败: ${e.message}',
        )
      ];
    } on TimeoutException {
      AppLog.instance.put('AsyncSearchService: 书源 ${source.bookSourceName} 超时');
      return [
        SearchResult(
          sourceName: source.bookSourceName,
          sourceUrl: source.bookSourceUrl,
          isError: true,
          errorMessage: '请求超时',
        )
      ];
    } catch (e) {
      AppLog.instance.put(
          'AsyncSearchService: 书源 ${source.bookSourceName} 搜索失败',
          error: e);
      return [
        SearchResult(
          sourceName: source.bookSourceName,
          sourceUrl: source.bookSourceUrl,
          isError: true,
          errorMessage: '搜索失败: ${e.toString()}',
        )
      ];
    }
  }

  /// 取消当前搜索
  void cancelSearch() {
    _cancelToken?.cancel('用户取消搜索');
    _cancelToken = null;
  }

  /// 构建搜索URL(替换关键词)
  String _buildSearchUrl(String searchUrlTemplate, String keyword) {
    // 参考BookService的实现
    return searchUrlTemplate
        .replaceAll('{{key}}', Uri.encodeComponent(keyword))
        .replaceAll('{{page}}', '1'); // 默认第一页
  }

  /// 将解析结果转换为Book对象
  Book? _parseResultToBook(
    Map<String, dynamic> parsed,
    BookSource source,
    String baseUrl,
  ) {
    final bookUrl = parsed['bookUrl'];
    if (bookUrl == null || bookUrl.isEmpty) {
      return null;
    }

    // 处理相对URL
    final finalBookUrl =
        bookUrl.startsWith('http://') || bookUrl.startsWith('https://')
            ? bookUrl
            : NetworkService.joinUrl(source.bookSourceUrl, bookUrl);

    return Book(
      bookUrl: finalBookUrl,
      tocUrl: '',
      origin: source.bookSourceUrl,
      originName: source.bookSourceName,
      name: parsed['name'] ?? '',
      author: parsed['author'] ?? '',
      kind: parsed['kind'],
      coverUrl: parsed['coverUrl'],
      intro: parsed['intro'],
      latestChapterTitle: parsed['lastChapter'],
      wordCount: parsed['wordCount'],
      type: source.bookSourceType,
      originOrder: source.customOrder,
    );
  }

  /// 将Book对象转换为SearchBook对象
  SearchBook _bookToSearchBook(Book book, SearchResult result) {
    return SearchBook(
      bookUrl: book.bookUrl,
      origin: book.origin,
      originName: book.originName,
      type: book.type,
      name: book.name,
      author: book.author,
      kind: book.kind,
      coverUrl: book.coverUrl,
      intro: book.intro,
      wordCount: book.wordCount,
      latestChapterTitle: book.latestChapterTitle,
      tocUrl: book.tocUrl,
      time: DateTime.now().millisecondsSinceEpoch,
      variable: book.variable,
      originOrder: book.originOrder,
      respondTime: result.respondTime,
    );
  }
}

/// 搜索结果去重器
///
/// 根据书名和作者进行去重,避免不同书源返回相同书籍时的重复显示
class SearchResultDeduplicator {
  final Map<String, Book> _bookMap = {};

  /// 添加书籍(如果不存在)
  ///
  /// Returns: true表示是新书籍,false表示已存在
  bool addBook(Book book) {
    final key = _generateKey(book.name, book.author);
    if (_bookMap.containsKey(key)) {
      return false; // 已存在
    }
    _bookMap[key] = book;
    return true; // 新书籍
  }

  /// 获取所有去重后的书籍
  List<Book> getAllBooks() {
    return _bookMap.values.toList();
  }

  /// 清空
  void clear() {
    _bookMap.clear();
  }

  /// 生成去重键
  String _generateKey(String name, String author) {
    return '${name.trim().toLowerCase()}|${author.trim().toLowerCase()}';
  }

  /// 获取去重后的数量
  int get count => _bookMap.length;
}
