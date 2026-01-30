import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import '../../core/base/base_service.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../data/database/app_database.dart';
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';
import '../../data/models/book_source.dart';
import '../../data/models/book_source_rule.dart';
import '../network/network_service.dart';
import '../../utils/parsers/rule_parser.dart';
import '../../utils/parsers/html_parser.dart';
import '../../utils/app_log.dart';
import '../../utils/concurrent_rate_limiter.dart';
import '../../utils/extensions/string_extensions.dart';
import '../../utils/js_engine.dart';
import '../../utils/helpers/book_extensions.dart';
import '../../utils/network_utils.dart';
import '../source/book_source_service.dart';
import '../reader/cache_service.dart';
import '../reader/chapter_content_service.dart';
import '../reader/content_processor.dart';

/// 书籍服务 - 处理搜索、详情、章节、正文等功能
class BookService extends BaseService {
  static final BookService instance = BookService._init();
  final AppDatabase _db = AppDatabase.instance;
  final NetworkService _networkService = NetworkService.instance;
  final BookSourceService _bookSourceService = BookSourceService.instance;

  // 正在请求的章节（用于防止重复请求）
  // Key: 章节URL，Value: 请求的Future
  final Map<String, Future<String?>> _loadingChapters = {};

  BookService._init();

  /// 比较两个 URL 是否相等（规范化后比较）
  /// 参考项目：NetworkUtils.getAbsoluteURL 的比较逻辑
  /// 处理 URL 末尾的旜杠、大小写等差异
  bool _urlEquals(String url1, String url2) {
    if (url1 == url2) return true;
    if (url1.isEmpty || url2.isEmpty) return false;

    // 规范化 URL：移除末尾的 /
    String normalize(String url) {
      var normalized = url.trim();
      while (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }
      return normalized;
    }

    final normalized1 = normalize(url1);
    final normalized2 = normalize(url2);

    // 直接比较
    if (normalized1 == normalized2) return true;

    // 尝试解析 URI 后比较
    try {
      final uri1 = Uri.parse(normalized1);
      final uri2 = Uri.parse(normalized2);

      // 比较 scheme、host、port 和 path
      return uri1.scheme == uri2.scheme &&
          uri1.host == uri2.host &&
          uri1.port == uri2.port &&
          uri1.path == uri2.path;
    } catch (e) {
      return false;
    }
  }

  /// 从单个书源搜索书籍
  /// 供SearchModel使用
  Future<List<Book>> searchBooksFromSource(
    BookSource source,
    String keyword,
    bool precisionSearch,
  ) async {
    final results = <Book>[];

    try {
      await ConcurrentRateLimiter(source).withLimit(() async {
        final searchUrl = _buildSearchUrl(source.searchUrl!, keyword);
        final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, searchUrl);

        final response = await _networkService.get(
          fullUrl,
          headers: NetworkService.parseHeaders(source.header),
          retryCount: 1,
        );

        final html = await NetworkService.getResponseText(response);
        final searchResults = await RuleParser.parseSearchRule(
          html,
          source.ruleSearch,
          variables: {'keyword': keyword},
          baseUrl: fullUrl,
        );

        for (final result in searchResults) {
          final bookUrl = result['bookUrl'];
          if (bookUrl == null || bookUrl.isEmpty) continue;

          if (source.ruleSearch?.checkKeyWord != null &&
              source.ruleSearch!.checkKeyWord!.isNotEmpty) {
            final checkKeyWordValue = result['checkKeyWord'];
            if (checkKeyWordValue == null || checkKeyWordValue.isEmpty) {
              continue;
            }
          }

          final finalBookUrl =
              bookUrl.startsWith('http://') || bookUrl.startsWith('https://')
                  ? bookUrl
                  : NetworkService.joinUrl(source.bookSourceUrl, bookUrl);

          final book = Book(
            bookUrl: finalBookUrl,
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            name: result['name'] ?? '',
            author: result['author'] ?? '',
            kind: result['kind'],
            coverUrl: result['coverUrl'],
            intro: result['intro'],
            wordCount: result['wordCount'],
            latestChapterTitle: result['lastChapter'],
            canUpdate: true,
          );

          if (precisionSearch) {
            final keywordLower = keyword.toLowerCase();
            final nameLower = book.name.toLowerCase();
            final authorLower = book.author.toLowerCase();

            if (nameLower != keywordLower &&
                authorLower != keywordLower &&
                !(nameLower.contains(keywordLower) &&
                    authorLower.contains(keywordLower))) {
              continue;
            }
          }

          results.add(book);
        }
      });
    } catch (e) {
      AppLog.instance.put('书源搜索失败: ${source.bookSourceName}', error: e);
    }

    return results;
  }

  /// 搜索书籍
  Future<List<Book>> searchBooks(
    String keyword, {
    List<BookSource>? sources,
    bool precisionSearch = false,
    Function(int current, int total)? onProgress,
    Function(Book book)? onResult, // 新增：找到结果时的回调
  }) async {
    if (keyword.isEmpty) return [];

    // 如果没有指定书源，获取所有启用的书源
    sources ??= await _bookSourceService.getAllBookSources(enabledOnly: true);

    // 过滤出有效的书源（启用且有搜索规则）
    final validSources = sources.where((source) {
      return source.enabled &&
          source.searchUrl != null &&
          source.ruleSearch != null;
    }).toList();

    final totalSources = validSources.length;
    final results = <Book>[];
    int currentIndex = 0;

    for (final source in validSources) {
      currentIndex++;

      // 报告进度
      if (onProgress != null) {
        onProgress(currentIndex, totalSources);
      }

      try {
        // 使用并发限流器（参考项目：ConcurrentRateLimiter）
        await ConcurrentRateLimiter(source).withLimit(() async {
          // 构建搜索URL（替换关键字）
          final searchUrl = _buildSearchUrl(source.searchUrl!, keyword);
          // 构建完整URL（处理相对路径）
          final fullUrl =
              NetworkService.joinUrl(source.bookSourceUrl, searchUrl);

          // 发送请求
          final response = await _networkService.get(
            fullUrl,
            headers: NetworkService.parseHeaders(source.header),
            retryCount: 1,
          );

          final html = await NetworkService.getResponseText(response);
          AppLog.instance.put(
              '搜索响应: 状态码=${response.statusCode}, 内容长度=${html.length}, URL=$fullUrl');

          // 输出响应内容的前500个字符用于调试
          if (html.isNotEmpty) {
            final preview =
                html.length > 500 ? '${html.substring(0, 500)}...' : html;
            AppLog.instance.put(
                '搜索响应内容预览 (前${html.length > 500 ? 500 : html.length}字符):\n$preview');
          }

          // 解析搜索结果
          // 使用实际请求的URL作为baseUrl（参考项目中的做法）
          final searchResults = await RuleParser.parseSearchRule(
            html,
            source.ruleSearch,
            variables: {'keyword': keyword},
            baseUrl: fullUrl, // 使用实际请求的URL，而不是书源的基础URL
          );

          // 转换为Book对象
          for (final result in searchResults) {
            final bookUrl = result['bookUrl'];
            if (bookUrl == null || bookUrl.isEmpty) continue;

            // 检查 checkKeyWord 规则（如果存在）
            // 参考项目：checkKeyWord 用于验证搜索结果是否包含关键词
            // 如果规则存在且解析结果为空，说明搜索结果无效，跳过
            if (source.ruleSearch?.checkKeyWord != null &&
                source.ruleSearch!.checkKeyWord!.isNotEmpty) {
              final checkKeyWordValue = result['checkKeyWord'];
              // 如果 checkKeyWord 规则存在但解析结果为空，说明搜索结果不匹配，跳过
              if (checkKeyWordValue == null || checkKeyWordValue.isEmpty) {
                AppLog.instance.put('搜索结果未通过checkKeyWord验证，跳过');
                continue;
              }
            }

            // 如果bookUrl已经是绝对URL，直接使用；否则相对于书源URL处理
            final finalBookUrl =
                bookUrl.startsWith('http://') || bookUrl.startsWith('https://')
                    ? bookUrl
                    : NetworkService.joinUrl(source.bookSourceUrl, bookUrl);

            final kindValue = result['kind'];
            // 添加调试日志（仅前3个结果）
            if (results.length < 3) {
              AppLog.instance.put(
                  'searchBooks: 创建Book对象 - name=${result['name']}, author=${result['author']}, kind=$kindValue, kind规则=${source.ruleSearch?.kind}');
            }

            final book = Book(
              bookUrl: finalBookUrl,
              origin: source.bookSourceUrl,
              originName: source.bookSourceName,
              name: result['name'] ?? '',
              author: result['author'] ?? '',
              kind: kindValue,
              // coverUrl已经在parseRule中使用实际请求的URL（fullUrl）作为baseUrl处理过了
              // 参考项目中，封面URL使用当前页面URL作为baseUrl，parseRule已经处理
              coverUrl: result['coverUrl'],
              intro: result['intro'],
              wordCount: result['wordCount'],
              latestChapterTitle: result['lastChapter'],
              canUpdate: true,
            );

            // 精确搜索模式：只保留书名或作者完全匹配的结果
            if (precisionSearch) {
              final keywordLower = keyword.toLowerCase();
              final nameLower = book.name.toLowerCase();
              final authorLower = book.author.toLowerCase();

              if (nameLower != keywordLower &&
                  authorLower != keywordLower &&
                  !(nameLower.contains(keywordLower) &&
                      authorLower.contains(keywordLower))) {
                continue; // 跳过不匹配的结果
              }
            }

            results.add(book);

            // 立即回调新结果
            if (onResult != null) {
              onResult(book);
            }
          }
        });
      } catch (e) {
        // 搜索失败，记录日志并继续下一个书源
        AppLog.instance.put('书源搜索失败: ${source.bookSourceName}', error: e);
        continue;
      }
    }

    return results;
  }

  /// 获取书籍详情
  Future<Book?> getBookInfo(Book book) async {
    if (book.isLocal) {
      // 本地书籍不需要获取详情
      return book;
    }

    final source = await _bookSourceService.getBookSourceByUrl(book.origin);
    if (source == null || source.ruleBookInfo == null) {
      AppLog.instance.put('getBookInfo: 书源不存在或详情规则为空');
      return book;
    }

    try {
      AppLog.instance.put('getBookInfo: 开始获取书籍详情，bookUrl=${book.bookUrl}');

      // 使用并发限流器（参考项目：ConcurrentRateLimiter）
      final updatedBook =
          await ConcurrentRateLimiter(source).withLimit(() async {
        // 发送请求，确保禁用缓存
        final headers = NetworkService.parseHeaders(source.header);
        headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
        headers['Pragma'] = 'no-cache';
        headers['Expires'] = '0';

        // 记录到 AppLog
        AppLog.instance
            .put('getBookInfo: 请求URL=${book.bookUrl}, 请求头数量=${headers.length}');

        final response = await _networkService.get(
          book.bookUrl,
          headers: headers,
          retryCount: 1,
          options: Options(
            extra: {'noCache': true},
          ),
        );

        final html = await NetworkService.getResponseText(response);

        // 记录到 AppLog
        AppLog.instance.put(
            'getBookInfo: 响应状态码=${response.statusCode}, 内容长度=${html.length}, URL=${book.bookUrl}');

        final bookInfo = await RuleParser.parseBookInfoRule(
          html,
          source.ruleBookInfo,
          baseUrl: book.bookUrl, // 使用书籍详情页的URL
        );

        // 更新书籍信息
        final newTocUrl = bookInfo['tocUrl'] != null
            ? NetworkService.joinUrl(source.bookSourceUrl, bookInfo['tocUrl']!)
            : book.tocUrl;

        AppLog.instance.put(
            'getBookInfo: 解析结果 - name=${bookInfo['name']}, author=${bookInfo['author']}, kind=${bookInfo['kind']}, tocUrl=${bookInfo['tocUrl']}, 最终tocUrl=$newTocUrl');

        // 处理 canReName（如果可以重命名，存储到 variable 中）
        String? updatedVariable = book.variable;
        final canReNameValue = bookInfo['canReName'];
        if (canReNameValue != null && canReNameValue.isNotEmpty) {
          // 将 canReName 存储到 variable JSON 中
          try {
            final variableMap = <String, dynamic>{};
            if (updatedVariable != null && updatedVariable.isNotEmpty) {
              final decoded =
                  jsonDecode(updatedVariable) as Map<String, dynamic>?;
              if (decoded != null) {
                variableMap.addAll(decoded);
              }
            }
            // canReName 通常是一个布尔值或字符串，存储为字符串
            variableMap['canReName'] = canReNameValue;
            updatedVariable = jsonEncode(variableMap);
          } catch (e) {
            AppLog.instance
                .put('getBookInfo: 更新canReName到variable失败', error: e);
          }
        }

        // 更新书籍信息
        return book.copyWith(
          name: bookInfo['name'] ?? book.name,
          author: bookInfo['author'] ?? book.author,
          kind: bookInfo['kind'] ?? book.kind,
          // coverUrl已经在parseRule中使用书籍详情页URL（book.bookUrl）作为baseUrl处理过了
          // 参考项目：封面URL使用当前页面URL作为baseUrl，parseRule已经处理
          coverUrl: bookInfo['coverUrl'] ?? book.coverUrl,
          intro: bookInfo['intro'] ?? book.intro,
          wordCount: bookInfo['wordCount'] ?? book.wordCount,
          latestChapterTitle:
              bookInfo['lastChapter'] ?? book.latestChapterTitle,
          tocUrl: newTocUrl,
          variable: updatedVariable,
          lastCheckTime: DateTime.now().millisecondsSinceEpoch,
        );
      });

      // 参考项目：如果书籍在书架中，自动保存到数据库
      try {
        final existingBook = await getBookByUrl(book.bookUrl);
        if (existingBook != null) {
          // 书籍在书架中，自动更新数据库
          await updateBook(updatedBook);
          AppLog.instance.put('getBookInfo: 书籍在书架中，已自动更新数据库');
        } else {
          // 尝试通过书名和作者查找（因为bookUrl可能不同）
          final existingByName = await getBookByNameAndAuthor(
              updatedBook.name, updatedBook.author);
          if (existingByName != null) {
            // 找到同名同作者的书籍，更新它
            final finalBook =
                updatedBook.copyWith(bookUrl: existingByName.bookUrl);
            await updateBook(finalBook);
            AppLog.instance.put('getBookInfo: 通过书名和作者找到书籍，已自动更新数据库');
          }
        }
      } catch (e) {
        // 保存失败不影响返回结果
        AppLog.instance.put('getBookInfo: 自动保存书籍详情失败', error: e);
      }

      return updatedBook;
    } catch (e) {
      AppLog.instance.put('getBookInfo: 获取书籍详情失败', error: e);
      return book;
    }
  }

  /// 获取章节列表（支持分页获取所有章节）
  Future<List<BookChapter>> getChapterList(Book book) async {
    if (book.isLocal) {
      // 本地书籍从数据库读取章节
      return await _getLocalChapters(book.bookUrl);
    }

    final source = await _bookSourceService.getBookSourceByUrl(book.origin);
    if (source == null || source.ruleToc == null) {
      return [];
    }

    try {
      // 使用tocUrl或bookUrl
      final tocUrl = book.tocUrl.isNotEmpty ? book.tocUrl : book.bookUrl;
      AppLog.instance.put('开始获取章节列表: tocUrl=$tocUrl, bookUrl=${book.bookUrl}');

      // 发送请求
      final response = await _networkService.get(
        tocUrl,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      var html = await NetworkService.getResponseText(response);

      AppLog.instance
          .put('获取章节列表响应: 状态码=${response.statusCode}, 内容长度=${html.length}');

      if (html.isEmpty) {
        AppLog.instance.put('获取章节列表失败: 响应内容为空');
        // 如果获取失败，尝试从数据库读取
        final localChapters = await _getLocalChapters(book.bookUrl);
        if (localChapters.isEmpty) {
          throw TocEmptyException('获取章节列表失败: 响应内容为空，且本地无章节数据');
        }
        return localChapters;
      }

      // 确定有效的baseUrl：如果tocUrl不是有效的绝对URL，使用source.bookSourceUrl
      String? effectiveBaseUrl = tocUrl;
      if (!tocUrl.isAbsUrl()) {
        // 如果source.bookSourceUrl也是有效的绝对URL，使用它；否则尝试从tocUrl构建
        if (source.bookSourceUrl.isAbsUrl()) {
          effectiveBaseUrl = source.bookSourceUrl;
          AppLog.instance.put(
              'tocUrl不是绝对URL，使用source.bookSourceUrl作为baseUrl: $effectiveBaseUrl');
        } else {
          // 如果两者都不是绝对URL，尝试从tocUrl构建完整的URL
          // 如果tocUrl是相对路径，使用source.bookSourceUrl作为基础
          try {
            effectiveBaseUrl =
                NetworkService.joinUrl(source.bookSourceUrl, tocUrl);
            if (!effectiveBaseUrl.isAbsUrl()) {
              // 如果仍然无效，使用source.bookSourceUrl
              effectiveBaseUrl = source.bookSourceUrl;
            }
            AppLog.instance.put(
                'tocUrl和source.bookSourceUrl都不是绝对URL，尝试拼接后: $effectiveBaseUrl');
          } catch (e) {
            AppLog.instance.put(
                '构建baseUrl失败: $e，使用source.bookSourceUrl: ${source.bookSourceUrl}');
            effectiveBaseUrl = source.bookSourceUrl;
          }
        }
      }

      // 最终验证：确保effectiveBaseUrl是有效的绝对URL
      if (!effectiveBaseUrl.isAbsUrl()) {
        AppLog.instance
            .put('警告: effectiveBaseUrl仍然无效: $effectiveBaseUrl，将尝试继续解析但可能失败');
      }

      // 参考项目：执行 preUpdateJs（如果存在）
      // 参考项目的 TocRule 有 preUpdateJs 字段，用于在解析目录前预处理HTML
      if (source.ruleToc?.preUpdateJs != null &&
          source.ruleToc!.preUpdateJs!.isNotEmpty) {
        AppLog.instance.put('执行 preUpdateJs 预处理HTML');
        try {
          final preUpdateResult = await RuleParser.executeJs(
            html,
            source.ruleToc!.preUpdateJs!,
            source: source,
            book: book,
            baseUrl: effectiveBaseUrl,
          );
          if (preUpdateResult != null && preUpdateResult.isNotEmpty) {
            html = preUpdateResult;
            AppLog.instance.put('preUpdateJs 执行成功，HTML长度=${html.length}');
          } else {
            AppLog.instance.put('preUpdateJs 执行返回空，使用原始HTML');
          }
        } catch (e) {
          AppLog.instance.put('preUpdateJs 执行失败: $e，使用原始HTML', error: e);
        }
      }

      // 首先尝试使用原始规则获取第一页，如果失败则使用降级规则
      TocRule? effectiveTocRule = source.ruleToc;
      String? fallbackChapterListRule;

      // 检查原始规则是否能匹配到章节
      var testChapterList = RuleParser.parseTocRule(
        html,
        source.ruleToc,
        baseUrl: effectiveBaseUrl,
      );

      if (testChapterList.isEmpty && source.ruleToc?.chapterList != null) {
        AppLog.instance.put('原始规则未匹配到章节，尝试智能降级处理');

        // 查找降级规则
        final chapterLinkPattern = RegExp(
            '<a[^>]*href=["\']/[^"\']*\\.html["\'][^>]*>.*?</a>',
            caseSensitive: false,
            dotAll: true);
        final chapterLinkMatches = chapterLinkPattern.allMatches(html).toList();

        if (chapterLinkMatches.isNotEmpty) {
          AppLog.instance
              .put('找到 ${chapterLinkMatches.length} 个可能的章节链接，尝试查找容器');

          html_dom.Element? directoryContainer;
          String? containerClass;
          String? containerId;

          // 首先尝试查找directoryArea容器
          final doc = html_parser.parse(html);
          final directoryPattern = RegExp(
              'class\\s*=\\s*["\'][^"\']*directory[^"\']*["\']',
              caseSensitive: false);
          final directoryMatches = directoryPattern.allMatches(html);
          if (directoryMatches.isNotEmpty) {
            final match = directoryMatches.first;
            final matchHtml = html.substring(match.start, match.end);
            final classPattern = RegExp('class\\s*=\\s*["\']([^"\']+)["\']',
                caseSensitive: false);
            final classMatch = classPattern.firstMatch(matchHtml);
            if (classMatch != null) {
              final allClasses =
                  classMatch.group(1)?.split(RegExp(r'\s+')) ?? [];
              final dirClass = allClasses.firstWhere(
                (c) => c.contains('directory'),
                orElse: () => '',
              );
              if (dirClass.isNotEmpty) {
                directoryContainer =
                    HtmlParser.selectElement(doc, 'div.$dirClass');
                containerClass = dirClass;
                AppLog.instance.put('找到directory容器: class=$containerClass');
              }
            }
          }

          // 如果找到了directory容器，提取其class或id用于生成降级规则
          if (directoryContainer != null) {
            final dirClassAttr = directoryContainer.attributes['class'];
            final dirIdAttr = directoryContainer.attributes['id'];
            if (dirClassAttr != null && dirClassAttr.contains('directory')) {
              final allClasses = dirClassAttr.split(RegExp(r'\s+'));
              final dirClass = allClasses.firstWhere(
                (c) => c.contains('directory'),
                orElse: () => allClasses.first,
              );
              containerClass = dirClass;
              AppLog.instance.put('从directory容器提取class: $containerClass');
            }
            if (dirIdAttr != null) {
              containerId = dirIdAttr;
              AppLog.instance.put('从directory容器提取id: $containerId');
            }
          }

          // 生成降级规则
          if (containerClass != null) {
            fallbackChapterListRule = 'class.$containerClass@tag.a';
            AppLog.instance.put('使用降级规则: $fallbackChapterListRule');
          }
        }

        // 如果找到了降级规则，创建临时规则对象
        if (fallbackChapterListRule != null) {
          effectiveTocRule = TocRule(
            chapterList: fallbackChapterListRule,
            chapterName: source.ruleToc?.chapterName ?? 'tag.a@text',
            chapterUrl: source.ruleToc?.chapterUrl ?? 'tag.a@href',
            isVip: source.ruleToc?.isVip,
            isVolume: source.ruleToc?.isVolume, // 保留卷名规则
            updateTime: source.ruleToc?.updateTime,
            nextTocUrl: source.ruleToc?.nextTocUrl,
          );
        }
      }

      // 参考项目：BookChapterList.analyzeChapterList
      // 处理 chapterList 规则的前缀（参考项目第51-58行）
      var reverse = false;
      var listRule = effectiveTocRule?.chapterList ?? '';
      if (listRule.startsWith('-')) {
        reverse = true;
        listRule = listRule.substring(1);
        AppLog.instance.put('检测到 - 前缀，将反转章节列表');
      }
      if (listRule.startsWith('+')) {
        listRule = listRule.substring(1);
        AppLog.instance.put('检测到 + 前缀，已移除');
      }

      // 如果规则被修改，更新 effectiveTocRule
      if (listRule != effectiveTocRule?.chapterList) {
        effectiveTocRule = TocRule(
          chapterList: listRule,
          chapterName: effectiveTocRule?.chapterName,
          chapterUrl: effectiveTocRule?.chapterUrl,
          isVip: effectiveTocRule?.isVip,
          isVolume: effectiveTocRule?.isVolume,
          updateTime: effectiveTocRule?.updateTime,
          nextTocUrl: effectiveTocRule?.nextTocUrl,
          formatJs: effectiveTocRule?.formatJs,
          preUpdateJs: effectiveTocRule?.preUpdateJs,
        );
      }

      // 参考项目：第一次调用 analyzeChapterList，返回章节列表和下一页URL列表
      final firstPageResult = RuleParser.parseTocRuleWithNextUrl(
        html,
        effectiveTocRule,
        baseUrl: effectiveBaseUrl,
        getNextUrl: true,
      );

      var allChapterList = <Map<String, String?>>[];
      allChapterList
          .addAll(firstPageResult['chapterList'] as List<Map<String, String?>>);
      var nextUrlList =
          List<String>.from(firstPageResult['nextUrlList'] as List);

      // 过滤掉与当前URL相同的URL
      nextUrlList =
          nextUrlList.where((url) => url.isNotEmpty && url != tocUrl).toList();

      // 参考项目：根据 nextUrlList.size 决定处理方式
      // size == 0: 不处理分页
      // size == 1: 循环获取下一页
      // size > 1: 并发处理所有URL
      if (nextUrlList.isEmpty) {
        // 不处理分页
      } else if (nextUrlList.length == 1) {
        // 参考项目：循环获取下一页，直到没有下一页或已访问过
        var currentUrl = nextUrlList[0];
        var visitedUrls = <String>{tocUrl, currentUrl};
        var pageCount = 1;
        const maxPages = 100; // 防止无限循环

        while (pageCount < maxPages) {
          pageCount++;

          try {
            final pageResponse = await _networkService.get(
              currentUrl,
              headers: NetworkService.parseHeaders(source.header),
              retryCount: 1,
            );
            final pageHtml = await NetworkService.getResponseText(pageResponse);

            if (pageHtml.isEmpty) {
              break;
            }

            // 解析当前页的章节列表和下一页URL
            final pageResult = RuleParser.parseTocRuleWithNextUrl(
              pageHtml,
              effectiveTocRule,
              baseUrl: currentUrl,
              getNextUrl: true,
            );

            final pageChapterList =
                pageResult['chapterList'] as List<Map<String, String?>>;
            final pageNextUrlList =
                List<String>.from(pageResult['nextUrlList'] as List);

            allChapterList.addAll(pageChapterList);

            // 获取下一页URL（过滤掉已访问的URL）
            final filteredNextUrls = pageNextUrlList
                .where((url) =>
                    url.isNotEmpty &&
                    url != currentUrl &&
                    !visitedUrls.contains(url))
                .toList();

            if (filteredNextUrls.isEmpty) {
              break;
            }

            currentUrl = filteredNextUrls[0];
            visitedUrls.add(currentUrl);
          } catch (e) {
            AppLog.instance.put('获取第 $pageCount 页失败: $e', error: e);
            break;
          }
        }
      } else {
        // 参考项目：并发处理所有URL
        try {
          // 并发处理所有URL
          final futures = nextUrlList.map((url) async {
            try {
              final response = await _networkService.get(
                url,
                headers: NetworkService.parseHeaders(source.header),
                retryCount: 1,
              );
              final pageHtml = await NetworkService.getResponseText(response);
              return {'url': url, 'html': pageHtml, 'success': true};
            } catch (e) {
              return {'url': url, 'html': '', 'success': false};
            }
          }).toList();

          final results = await Future.wait(futures);

          // 分别解析每个URL的章节列表，然后合并
          for (final result in results) {
            if (result['success'] == true &&
                (result['html'] as String).isNotEmpty) {
              final pageHtml = result['html'] as String;
              final pageUrl = result['url'] as String;

              final pageResult = RuleParser.parseTocRuleWithNextUrl(
                pageHtml,
                effectiveTocRule,
                baseUrl: pageUrl,
                getNextUrl: false, // 并发处理时不需要获取下一页URL
              );

              final pageChapterList =
                  pageResult['chapterList'] as List<Map<String, String?>>;
              allChapterList.addAll(pageChapterList);
            }
          }
        } catch (e) {
          AppLog.instance.put('并发处理异常: $e', error: e);
        }
      }

      var chapterList = allChapterList;

      // 参考项目：转换为BookChapter对象（参考项目第217-256行）
      // 参考项目不过滤"最新章节"，保留所有解析到的章节
      var chapters = <BookChapter>[];
      for (int i = 0; i < chapterList.length; i++) {
        final chapterData = chapterList[i];
        final chapterName = chapterData['chapterName'] ?? '';
        final isVolumeStr = chapterData['isVolume'] ?? '0';
        final isVolume =
            isVolumeStr == '1' || isVolumeStr.toLowerCase() == 'true';
        final chapterUrl = chapterData['chapterUrl'];

        // 参考项目逻辑：
        // 1. 卷名（isVolume）不需要URL，即使URL为空也会添加
        // 2. 非卷名章节必须有URL
        if (!isVolume && (chapterUrl == null || chapterUrl.isEmpty)) {
          continue;
        }

        // 过滤分页链接（参考项目：不添加标题为空的章节，以及分页链接）
        final trimmedName = chapterName.trim().replaceAll(RegExp(r'\s+'), '');
        if (chapterName.contains('上一页') ||
            chapterName.contains('下一页') ||
            chapterName.contains('上一章') ||
            chapterName.contains('下一章') ||
            trimmedName.isEmpty) {
          continue;
        }

        // 参考项目：构建章节URL（参考项目第222-243行）
        // 参考项目保存的是解析出来的原始URL，在getAbsoluteURL()中转换
        // 为了兼容性，我们这里仍然拼接为绝对URL，但不做额外规范化
        String finalUrl = '';
        if (chapterUrl != null && chapterUrl.isNotEmpty) {
          // 参考项目：bookChapter.url = analyzeRule.getString(urlRule)
          // 拼接为绝对URL，但不做额外规范化处理
          finalUrl = NetworkService.joinUrl(effectiveBaseUrl, chapterUrl);
        } else {
          // 参考项目：如果 URL 为空，根据是否是卷名来设置
          if (isVolume) {
            // 参考项目：如果是卷名且URL为空，使用标题+索引作为URL
            finalUrl = '$chapterName$i';
          } else {
            // 参考项目：非卷名但URL为空，使用baseUrl替代
            finalUrl = effectiveBaseUrl;
          }
        }

        // 参考项目：章节标题直接使用原始标题
        final chapterTitle =
            chapterName.isNotEmpty ? chapterName : '第${i + 1}章';

        final chapter = BookChapter(
          url: finalUrl,
          title: chapterTitle,
          bookUrl: book.bookUrl,
          baseUrl: source.bookSourceUrl,
          index: chapters.length, // 使用过滤后的索引
          isVolume: isVolume, // 设置卷名标志
          isVip: chapterData['isVip'] == 'true' || chapterData['isVip'] == '1',
          tag: chapterData['updateTime'],
        );

        chapters.add(chapter);
      }

      // 参考项目：如果章节列表为空，抛出异常
      if (chapters.isEmpty) {
        throw TocEmptyException('章节列表为空');
      }

      // 参考项目：反转逻辑（参考项目第119-120行）
      // 如果 !reverse，反转章节列表
      if (!reverse) {
        chapters = chapters.reversed.toList();
      }

      // 去重：保留第一个发现的章节
      // LinkedHashSet 保留第一次出现的元素
      final originalCount = chapters.length;
      chapters = LinkedHashSet<BookChapter>.from(chapters).toList();
      if (chapters.length < originalCount) {
        AppLog.instance
            .put('章节去重: $originalCount -> ${chapters.length}（保留第一个发现的）');
      }

      // 参考项目：如果 !book.getReverseToc()，再次反转列表（参考项目第126-128行）
      if (!book.getReverseToc()) {
        chapters = chapters.reversed.toList();
        AppLog.instance.put('反转章节列表（!book.getReverseToc()）');
      }

      // 重新设置索引
      for (int i = 0; i < chapters.length; i++) {
        chapters[i] = chapters[i].copyWith(index: i);
      }

      // 参考项目：formatJs 格式化章节标题
      final formatJs = effectiveTocRule?.formatJs;
      if (formatJs != null && formatJs.isNotEmpty) {
        AppLog.instance.put('使用 formatJs 格式化章节标题');
        try {
          for (int i = 0; i < chapters.length; i++) {
            final chapter = chapters[i];
            final bindings = <String, dynamic>{
              'gInt': 0,
              'index': i + 1, // 参考项目：index 从 1 开始
              'chapter': {
                'title': chapter.title,
                'url': chapter.url,
                'index': chapter.index,
              },
              'title': chapter.title,
            };
            final result = await JSEngine.evalJS(formatJs, bindings: bindings);
            if (result != null && result.toString().isNotEmpty) {
              chapters[i] = chapter.copyWith(title: result.toString());
              AppLog.instance.put(
                  '格式化章节 ${i + 1}: ${chapter.title} -> ${result.toString()}');
            }
          }
        } catch (e) {
          AppLog.instance.put('格式化标题出错: $e', error: e);
        }
      }

      // 参考项目：更新书籍信息（参考项目第154-164行）
      // 获取替换规则处理器
      final contentProcessor = ContentProcessor.get(book);

      // 更新 durChapterTitle（参考项目第154行）
      if (chapters.isNotEmpty) {
        final currentChapterIndex = book.durChapterIndex;
        if (currentChapterIndex >= 0 && currentChapterIndex < chapters.length) {
          final currentChapter = chapters[currentChapterIndex];
          final displayTitle = await contentProcessor.getDisplayTitle(
            currentChapter,
            useReplace: book.getUseReplaceRule(),
          );
          book.durChapterTitle = displayTitle;
        } else if (chapters.isNotEmpty) {
          // 如果索引超出范围，使用最后一个章节
          final lastChapter = chapters.last;
          final displayTitle = await contentProcessor.getDisplayTitle(
            lastChapter,
            useReplace: book.getUseReplaceRule(),
          );
          book.durChapterTitle = displayTitle;
        }
      }

      // 更新 lastCheckCount 和 latestChapterTime（参考项目第156-158行）
      if (book.totalChapterNum < chapters.length) {
        book.lastCheckCount = chapters.length - book.totalChapterNum;
        book.latestChapterTime = DateTime.now().millisecondsSinceEpoch;
      }

      // 更新 lastCheckTime 和 totalChapterNum（参考项目第160-161行）
      book.lastCheckTime = DateTime.now().millisecondsSinceEpoch;
      book.totalChapterNum = chapters.length;

      // 更新 latestChapterTitle（参考项目第162-164行）
      if (chapters.isNotEmpty) {
        final simulatedIndex = book.simulatedTotalChapterNum() - 1;
        final latestChapterIndex =
            simulatedIndex >= 0 && simulatedIndex < chapters.length
                ? simulatedIndex
                : chapters.length - 1;
        final latestChapter = chapters[latestChapterIndex];
        final displayTitle = await contentProcessor.getDisplayTitle(
          latestChapter,
          useReplace: book.getUseReplaceRule(),
        );
        book.latestChapterTitle = displayTitle;
      }

      // 参考项目：getWordCount（参考项目第272-286行）
      // 从数据库获取已存在的章节字数
      await getWordCount(chapters, book);

      AppLog.instance.put('获取章节列表成功: 共 ${chapters.length} 个章节');

      // 保存章节列表到数据库
      await saveChapters(chapters);

      // 更新书籍信息到数据库
      try {
        await updateBook(book);
      } catch (e) {
        AppLog.instance.put('更新书籍信息失败: $e', error: e);
      }

      return chapters;
    } catch (e, stackTrace) {
      AppLog.instance.put('获取章节列表失败', error: e);
      AppLog.instance.put('错误堆栈: $stackTrace');
      // 如果获取失败，尝试从数据库读取
      return await _getLocalChapters(book.bookUrl);
    }
  }

  /// 获取章节列表但不保存到数据库（用于探索页面）
  Future<List<BookChapter>> getChapterListWithoutSave(Book book) async {
    if (book.isLocal) {
      // 本地书籍从数据库读取章节
      return await _getLocalChapters(book.bookUrl);
    }

    final source = await _bookSourceService.getBookSourceByUrl(book.origin);
    if (source == null) {
      AppLog.instance.put('获取章节列表失败: 书源不存在 (origin: ${book.origin})');
      return [];
    }

    if (source.ruleToc == null) {
      AppLog.instance.put('获取章节列表失败: 目录规则为空 (书源: ${source.bookSourceName})');
      return [];
    }

    try {
      // 使用tocUrl或bookUrl
      final tocUrl = book.tocUrl.isNotEmpty ? book.tocUrl : book.bookUrl;
      AppLog.instance.put('开始获取章节列表: tocUrl=$tocUrl, bookUrl=${book.bookUrl}');

      // 发送请求
      final response = await _networkService.get(
        tocUrl,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);
      AppLog.instance
          .put('获取章节列表响应: 状态码=${response.statusCode}, 内容长度=${html.length}');

      if (html.isEmpty) {
        AppLog.instance.put('获取章节列表失败: 响应内容为空');
        throw TocEmptyException('获取章节列表失败: 响应内容为空');
      }

      // 检查HTML中是否包含可能的目录容器
      AppLog.instance.put(
          '检查HTML结构: 是否包含id="list": ${html.contains('id="list"') || html.contains("id='list'")}');
      AppLog.instance.put(
          '检查HTML结构: 是否包含class="list": ${html.contains('class="list"') || html.contains("class='list'")}');
      AppLog.instance.put(
          '检查HTML结构: 是否包含<dd>标签: ${html.contains('<dd>') || html.contains('<DD>')}');

      // 查找所有可能的目录相关元素
      final listIdPattern = RegExp('id\\s*=\\s*["\']([^"\']*list[^"\']*)["\']',
          caseSensitive: false);
      final listIds = listIdPattern
          .allMatches(html)
          .map((m) => m.group(1))
          .whereType<String>()
          .take(5)
          .toList();
      if (listIds.isNotEmpty) {
        AppLog.instance.put('HTML中找到包含"list"的id: ${listIds.join(", ")}');
      }

      final listClassPattern = RegExp(
          'class\\s*=\\s*["\']([^"\']*list[^"\']*)["\']',
          caseSensitive: false);
      final listClasses = listClassPattern
          .allMatches(html)
          .map((m) => m.group(1))
          .whereType<String>()
          .take(5)
          .toList();
      if (listClasses.isNotEmpty) {
        AppLog.instance.put('HTML中找到包含"list"的class: ${listClasses.join(", ")}');
      }

      // 解析章节列表
      // 参考项目：baseUrl使用tocUrl（实际请求的URL），而不是书源的基础URL
      AppLog.instance.put(
          '开始解析章节列表: ruleToc=${source.ruleToc?.toJson()}, chapterList规则=${source.ruleToc?.chapterList}');

      // 确定有效的baseUrl：如果tocUrl不是有效的绝对URL，使用source.bookSourceUrl
      String? effectiveBaseUrl = tocUrl;
      if (!tocUrl.isAbsUrl()) {
        // 如果source.bookSourceUrl也是有效的绝对URL，使用它；否则尝试从tocUrl构建
        if (source.bookSourceUrl.isAbsUrl()) {
          effectiveBaseUrl = source.bookSourceUrl;
          AppLog.instance.put(
              'tocUrl不是绝对URL，使用source.bookSourceUrl作为baseUrl: $effectiveBaseUrl');
        } else {
          // 如果两者都不是绝对URL，尝试从tocUrl构建完整的URL
          // 如果tocUrl是相对路径，使用source.bookSourceUrl作为基础
          try {
            effectiveBaseUrl =
                NetworkService.joinUrl(source.bookSourceUrl, tocUrl);
            if (!effectiveBaseUrl.isAbsUrl()) {
              // 如果仍然无效，使用source.bookSourceUrl
              effectiveBaseUrl = source.bookSourceUrl;
            }
            AppLog.instance.put(
                'tocUrl和source.bookSourceUrl都不是绝对URL，尝试拼接后: $effectiveBaseUrl');
          } catch (e) {
            AppLog.instance.put(
                '构建baseUrl失败: $e，使用source.bookSourceUrl: ${source.bookSourceUrl}');
            effectiveBaseUrl = source.bookSourceUrl;
          }
        }
      }

      // 最终验证：确保effectiveBaseUrl是有效的绝对URL
      if (!effectiveBaseUrl.isAbsUrl()) {
        AppLog.instance
            .put('警告: effectiveBaseUrl仍然无效: $effectiveBaseUrl，将尝试继续解析但可能失败');
      }

      // 首先尝试使用原始规则获取第一页，如果失败则使用降级规则
      TocRule? effectiveTocRule = source.ruleToc;
      String? fallbackChapterListRule;

      // 检查原始规则是否能匹配到章节
      var testChapterList = RuleParser.parseTocRule(
        html,
        source.ruleToc,
        baseUrl: effectiveBaseUrl,
      );

      if (testChapterList.isEmpty && source.ruleToc?.chapterList != null) {
        AppLog.instance.put('原始规则未匹配到章节，尝试智能降级处理');

        // 查找降级规则
        final chapterLinkPattern = RegExp(
            '<a[^>]*href=["\']/[^"\']*\\.html["\'][^>]*>.*?</a>',
            caseSensitive: false,
            dotAll: true);
        final chapterLinkMatches = chapterLinkPattern.allMatches(html).toList();

        if (chapterLinkMatches.isNotEmpty) {
          AppLog.instance
              .put('找到 ${chapterLinkMatches.length} 个可能的章节链接，尝试查找容器');

          html_dom.Element? directoryContainer;
          String? containerClass;
          String? containerId;

          // 首先尝试查找directoryArea容器
          final doc = html_parser.parse(html);
          final directoryPattern = RegExp(
              'class\\s*=\\s*["\'][^"\']*directory[^"\']*["\']',
              caseSensitive: false);
          final directoryMatches = directoryPattern.allMatches(html);
          if (directoryMatches.isNotEmpty) {
            final match = directoryMatches.first;
            final matchHtml = html.substring(match.start, match.end);
            final classPattern = RegExp('class\\s*=\\s*["\']([^"\']+)["\']',
                caseSensitive: false);
            final classMatch = classPattern.firstMatch(matchHtml);
            if (classMatch != null) {
              final allClasses =
                  classMatch.group(1)?.split(RegExp(r'\s+')) ?? [];
              final dirClass = allClasses.firstWhere(
                (c) => c.contains('directory'),
                orElse: () => '',
              );
              if (dirClass.isNotEmpty) {
                directoryContainer =
                    HtmlParser.selectElement(doc, 'div.$dirClass');
                containerClass = dirClass;
                AppLog.instance.put('找到directory容器: class=$containerClass');
              }
            }
          }

          // 如果找到了directory容器，提取其class或id用于生成降级规则
          if (directoryContainer != null) {
            final dirClassAttr = directoryContainer.attributes['class'];
            final dirIdAttr = directoryContainer.attributes['id'];
            if (dirClassAttr != null && dirClassAttr.contains('directory')) {
              final allClasses = dirClassAttr.split(RegExp(r'\s+'));
              final dirClass = allClasses.firstWhere(
                (c) => c.contains('directory'),
                orElse: () => allClasses.first,
              );
              containerClass = dirClass;
              AppLog.instance.put('从directory容器提取class: $containerClass');
            }
            if (dirIdAttr != null) {
              containerId = dirIdAttr;
              AppLog.instance.put('从directory容器提取id: $containerId');
            }
          }

          // 生成降级规则
          if (containerClass != null) {
            fallbackChapterListRule = 'class.$containerClass@tag.a';
            AppLog.instance.put('使用降级规则: $fallbackChapterListRule');
          }
        }

        // 如果找到了降级规则，创建临时规则对象
        if (fallbackChapterListRule != null) {
          effectiveTocRule = TocRule(
            chapterList: fallbackChapterListRule,
            chapterName: source.ruleToc?.chapterName ?? 'tag.a@text',
            chapterUrl: source.ruleToc?.chapterUrl ?? 'tag.a@href',
            isVip: source.ruleToc?.isVip,
            isVolume: source.ruleToc?.isVolume, // 保留卷名规则
            updateTime: source.ruleToc?.updateTime,
            nextTocUrl: source.ruleToc?.nextTocUrl,
          );
        }
      }

      // 使用有效规则（原始规则或降级规则）进行分页获取
      var allChapterList = <Map<String, String?>>[];
      var currentUrl = tocUrl;
      var visitedUrls = <String>{currentUrl};
      var pageCount = 0;
      const maxPages = 100; // 防止无限循环

      // 循环获取所有页面的目录（参考项目逻辑）
      while (pageCount < maxPages && effectiveTocRule != null) {
        pageCount++;
        AppLog.instance.put('获取目录第 $pageCount 页: $currentUrl');

        // 如果是第一页，使用已有的html；否则需要重新请求
        String pageHtml;
        if (pageCount == 1) {
          pageHtml = html;
        } else {
          final pageResponse = await _networkService.get(
            currentUrl,
            headers: NetworkService.parseHeaders(source.header),
            retryCount: 1,
          );
          pageHtml = await NetworkService.getResponseText(pageResponse);
          if (pageHtml.isEmpty) {
            AppLog.instance.put('第 $pageCount 页内容为空，停止获取');
            break;
          }
        }

        // 解析当前页的章节列表
        var pageChapterList = RuleParser.parseTocRule(
          pageHtml,
          effectiveTocRule,
          baseUrl: currentUrl,
        );

        AppLog.instance
            .put('第 $pageCount 页解析结果: 找到 ${pageChapterList.length} 个章节');
        allChapterList.addAll(pageChapterList);

        // 查找下一页URL（从nextTocUrl规则或章节数据中获取）
        // 参考项目：使用getStringList获取URL列表（isUrl=true）
        // 如果返回多个URL，参考项目会并发处理；如果返回一个URL，就循环处理
        String? nextUrl;
        if (effectiveTocRule.nextTocUrl != null &&
            effectiveTocRule.nextTocUrl!.isNotEmpty) {
          // 使用nextTocUrl规则获取下一页链接列表
          AppLog.instance
              .put('尝试使用nextTocUrl规则获取下一页: ${effectiveTocRule.nextTocUrl}');

          // 参考项目：使用getStringList获取URL列表，可能返回多个URL
          List<String> nextUrlList;

          // 检查规则是否包含属性选择器（@href, @src等）
          if (effectiveTocRule.nextTocUrl!.contains('@')) {
            // 规则包含属性选择器，直接使用parseListRule获取属性值
            nextUrlList = RuleParser.parseListRule(
              pageHtml,
              effectiveTocRule.nextTocUrl!,
              baseUrl: currentUrl,
              returnHtml: false, // 获取属性值（URL）
            );
          } else {
            // 规则不包含属性选择器，需要先获取HTML，然后提取href
            final linkHtmlList = RuleParser.parseListRule(
              pageHtml,
              effectiveTocRule.nextTocUrl!,
              baseUrl: currentUrl,
              returnHtml: true, // 获取HTML内容
            );

            // 从HTML中提取href属性
            nextUrlList = [];
            for (final linkHtml in linkHtmlList) {
              final hrefPattern = RegExp(
                'href\\s*=\\s*["\']([^"\']+)["\']',
                caseSensitive: false,
              );
              final match = hrefPattern.firstMatch(linkHtml);
              if (match != null) {
                final href = match.group(1);
                if (href != null && href.isNotEmpty) {
                  nextUrlList.add(href);
                }
              }
            }
          }

          // 过滤掉与当前URL相同的URL，并拼接完整URL
          final filteredUrls = nextUrlList
              .where((url) => url.isNotEmpty && url != currentUrl)
              .map((url) => NetworkService.joinUrl(currentUrl, url))
              .where((url) => url != currentUrl && !visitedUrls.contains(url))
              .toList();

          AppLog.instance
              .put('nextTocUrl规则解析结果: 找到 ${filteredUrls.length} 个URL');
          for (int i = 0; i < filteredUrls.length; i++) {
            AppLog.instance.put('  下一页URL ${i + 1}: ${filteredUrls[i]}');
          }

          if (filteredUrls.isNotEmpty) {
            // 参考项目：如果返回多个URL，会并发处理；如果返回一个URL，就循环处理
            if (filteredUrls.length == 1) {
              // 只有一个URL，直接使用
              nextUrl = filteredUrls[0];
              AppLog.instance.put('使用唯一的下页URL: $nextUrl');
            } else {
              // 多个URL，并发处理
              AppLog.instance.put('找到 ${filteredUrls.length} 个下一页URL，开始并发处理');
              try {
                // 并发处理所有URL，收集所有章节
                final futures = filteredUrls.map((url) async {
                  try {
                    AppLog.instance.put('并发处理URL: $url');
                    final response = await _networkService.get(
                      url,
                      headers: NetworkService.parseHeaders(source.header),
                      retryCount: 1,
                    );
                    final html = await NetworkService.getResponseText(response);
                    return {'url': url, 'html': html, 'success': true};
                  } catch (e) {
                    AppLog.instance.put('并发处理URL失败: $url, 错误: $e');
                    return {'url': url, 'html': '', 'success': false};
                  }
                }).toList();

                final results = await Future.wait(futures);

                // 合并所有成功的HTML内容
                final allHtml = results
                    .where((r) =>
                        r['success'] == true &&
                        (r['html'] as String).isNotEmpty)
                    .map((r) => r['html'] as String)
                    .join('\n');

                if (allHtml.isNotEmpty) {
                  // 使用合并后的HTML继续处理
                  pageHtml = allHtml;
                  AppLog.instance.put('并发处理完成，合并后的HTML长度: ${allHtml.length}');
                  // 继续使用当前URL作为nextUrl，因为已经处理了所有URL
                  nextUrl = null; // 设置为null，表示已经处理完所有URL
                } else {
                  // 所有URL都失败，使用第一个URL
                  nextUrl = filteredUrls[0];
                  AppLog.instance.put('所有并发URL处理失败，回退到第一个URL: $nextUrl');
                }
              } catch (e) {
                AppLog.instance.put('并发处理异常: $e，回退到第一个URL');
                nextUrl = filteredUrls[0];
              }
            }
          } else {
            AppLog.instance.put('nextTocUrl规则解析失败或所有URL都已访问过');
          }
        } else {
          AppLog.instance.put('nextTocUrl规则为空，尝试从章节数据中获取');
        }

        // 如果没有从规则中获取到，尝试从章节数据中获取
        if (nextUrl == null || nextUrl.isEmpty) {
          AppLog.instance
              .put('从章节数据中查找nextTocUrl，共 ${pageChapterList.length} 个章节');
          for (int i = 0; i < pageChapterList.length; i++) {
            final chapterData = pageChapterList[i];
            final chapterNextUrl = chapterData['nextTocUrl'];
            if (chapterNextUrl != null && chapterNextUrl.isNotEmpty) {
              AppLog.instance
                  .put('从章节 ${i + 1} 中找到nextTocUrl: $chapterNextUrl');
              nextUrl = NetworkService.joinUrl(currentUrl, chapterNextUrl);
              AppLog.instance.put('拼接后的下一页URL: $nextUrl');
              break;
            }
          }
        }

        // 如果仍然没有找到，尝试从HTML中自动查找"下一页"链接
        if (nextUrl == null || nextUrl.isEmpty) {
          AppLog.instance.put('尝试从HTML中自动查找"下一页"链接');
          try {
            final nextPagePattern = RegExp(
              '<a[^>]*href=["\']([^"\']+)["\'][^>]*>.*?(?:下一页|下页|next|Next|NEXT)[^<]*</a>',
              caseSensitive: false,
              dotAll: true,
            );
            final match = nextPagePattern.firstMatch(pageHtml);
            if (match != null) {
              final href = match.group(1);
              if (href != null && href.isNotEmpty) {
                nextUrl = NetworkService.joinUrl(currentUrl, href);
                AppLog.instance.put('从HTML中自动找到"下一页"链接: $nextUrl');
              }
            }
          } catch (e) {
            AppLog.instance.put('自动查找"下一页"链接失败', error: e);
          }
        }

        // 如果没有找到下一页URL，或者已经访问过，停止循环
        if (nextUrl == null ||
            nextUrl.isEmpty ||
            visitedUrls.contains(nextUrl)) {
          if (nextUrl != null && visitedUrls.contains(nextUrl)) {
            AppLog.instance.put('下一页URL已访问过，停止获取: $nextUrl');
          } else if (nextUrl == null || nextUrl.isEmpty) {
            AppLog.instance.put(
                '没有找到下一页URL，停止获取。当前页: $pageCount, 已获取章节: ${allChapterList.length}');
          }
          break;
        }

        visitedUrls.add(nextUrl);
        currentUrl = nextUrl;
        AppLog.instance.put('找到下一页URL: $nextUrl，继续获取第 ${pageCount + 1} 页');
      }

      AppLog.instance
          .put('目录获取完成: 共 $pageCount 页，总计 ${allChapterList.length} 个章节');
      var chapterList = allChapterList;

      // 如果仍然没有章节，尝试其他降级规则（保留原有逻辑作为最后手段）
      if (chapterList.isEmpty && source.ruleToc?.chapterList != null) {
        AppLog.instance.put('原始规则未匹配到章节，尝试智能降级处理');

        // 尝试查找包含章节链接的容器
        // 使用普通字符串而不是原始字符串，以便正确处理字符类中的引号
        final chapterLinkPattern = RegExp(
            '<a[^>]*href=["\']/[^"\']*\\.html["\'][^>]*>.*?</a>',
            caseSensitive: false,
            dotAll: true);
        final chapterLinkMatches = chapterLinkPattern.allMatches(html).toList();

        if (chapterLinkMatches.isNotEmpty) {
          AppLog.instance
              .put('找到 ${chapterLinkMatches.length} 个可能的章节链接，尝试查找容器');

          // 查找真正的目录开始位置（跳过前几个可能是最新章节的链接）
          // 从第7个链接开始查找，这些应该是真正的目录章节
          html_dom.Element? directoryContainer;
          String? containerClass;
          String? containerId;
          String? containerTag;

          // 首先尝试查找directoryArea容器
          final doc = html_parser.parse(html);
          final directoryPattern = RegExp(
              'class\\s*=\\s*["\'][^"\']*directory[^"\']*["\']',
              caseSensitive: false);
          final directoryMatches = directoryPattern.allMatches(html);
          if (directoryMatches.isNotEmpty) {
            final match = directoryMatches.first;
            final matchHtml = html.substring(match.start, match.end);
            final classPattern = RegExp('class\\s*=\\s*["\']([^"\']+)["\']',
                caseSensitive: false);
            final classMatch = classPattern.firstMatch(matchHtml);
            if (classMatch != null) {
              final allClasses =
                  classMatch.group(1)?.split(RegExp(r'\s+')) ?? [];
              final dirClass = allClasses.firstWhere(
                (c) => c.contains('directory'),
                orElse: () => '',
              );
              if (dirClass.isNotEmpty) {
                directoryContainer =
                    HtmlParser.selectElement(doc, 'div.$dirClass');
                containerClass = dirClass;
                containerTag = 'div';
                AppLog.instance.put('找到directory容器: class=$containerClass');
              }
            }
          }

          // 如果没有找到directory容器，从第7个链接开始查找容器
          if (directoryContainer == null && chapterLinkMatches.length >= 7) {
            // 从第7个链接开始查找容器
            final chapterStartMatch = chapterLinkMatches[6]; // 第7个链接（索引6）
            final beforeHtml = html.substring(0, chapterStartMatch.start);

            // 查找最近的容器开始标签（div, ul, ol, dl, section等）
            final containerStartPattern =
                RegExp(r'<(div|ul|ol|dl|section)[^>]*>', caseSensitive: false);
            final containerStarts =
                containerStartPattern.allMatches(beforeHtml).toList();

            if (containerStarts.isNotEmpty) {
              final lastContainerStart = containerStarts.last;
              containerTag = lastContainerStart.group(1);
              final containerStartPos = lastContainerStart.start;

              // 提取容器的class或id属性
              final containerHtml =
                  html.substring(containerStartPos, lastContainerStart.end);
              final classPattern = RegExp('class\\s*=\\s*["\']([^"\']+)["\']',
                  caseSensitive: false);
              final idPattern = RegExp('id\\s*=\\s*["\']([^"\']+)["\']',
                  caseSensitive: false);
              final classMatch = classPattern.firstMatch(containerHtml);
              final idMatch = idPattern.firstMatch(containerHtml);

              containerClass =
                  classMatch?.group(1)?.split(RegExp(r'\s+')).first;
              containerId = idMatch?.group(1);

              // 如果容器class包含directory，尝试查找该容器
              if (containerClass != null &&
                  containerClass.contains('directory')) {
                directoryContainer =
                    HtmlParser.selectElement(doc, 'div.$containerClass');
                AppLog.instance.put('找到directory容器: class=$containerClass');
              } else if (containerId != null) {
                directoryContainer =
                    HtmlParser.selectElement(doc, 'div#$containerId');
                AppLog.instance.put('找到容器: id=$containerId');
              }
            }
          }

          // 如果找到了directory容器，提取其class或id用于生成降级规则
          if (directoryContainer != null) {
            final dirClassAttr = directoryContainer.attributes['class'];
            final dirIdAttr = directoryContainer.attributes['id'];
            if (dirClassAttr != null && dirClassAttr.contains('directory')) {
              final allClasses = dirClassAttr.split(RegExp(r'\s+'));
              final dirClass = allClasses.firstWhere(
                (c) => c.contains('directory'),
                orElse: () => allClasses.first,
              );
              containerClass = dirClass;
              containerTag = 'div';
              AppLog.instance.put('从directory容器提取class: $containerClass');
            }
            if (dirIdAttr != null) {
              containerId = dirIdAttr;
              AppLog.instance.put('从directory容器提取id: $containerId');
            }
          }

          // 如果还没有找到容器，使用第一个章节链接的容器
          if (containerClass == null && containerId == null) {
            final firstChapterLink = chapterLinkMatches.first;
            final beforeHtml = html.substring(0, firstChapterLink.start);

            // 查找最近的容器开始标签（div, ul, ol, dl, section等）
            final containerStartPattern =
                RegExp(r'<(div|ul|ol|dl|section)[^>]*>', caseSensitive: false);
            final containerStarts =
                containerStartPattern.allMatches(beforeHtml).toList();

            if (containerStarts.isNotEmpty) {
              final lastContainerStart = containerStarts.last;
              containerTag = lastContainerStart.group(1);
              final containerStartPos = lastContainerStart.start;

              // 提取容器的class或id属性
              final containerHtml =
                  html.substring(containerStartPos, lastContainerStart.end);
              final classPattern = RegExp('class\\s*=\\s*["\']([^"\']+)["\']',
                  caseSensitive: false);
              final idPattern = RegExp('id\\s*=\\s*["\']([^"\']+)["\']',
                  caseSensitive: false);
              final classMatch = classPattern.firstMatch(containerHtml);
              final idMatch = idPattern.firstMatch(containerHtml);

              containerClass =
                  classMatch?.group(1)?.split(RegExp(r'\s+')).first;
              containerId = idMatch?.group(1);

              AppLog.instance.put(
                  '找到容器: <$containerTag>${containerClass != null ? ' class="$containerClass"' : ''}${containerId != null ? ' id="$containerId"' : ''}');
            }
          }

          // 使用找到的容器信息生成降级规则
          String? finalContainerClass = containerClass;
          String? finalContainerId = containerId;
          String? finalContainerTag = containerTag;

          if (directoryContainer == null) {
            // 如果没有找到directory容器，尝试从第一个章节链接查找容器
            final firstChapterLink = chapterLinkMatches.first;
            final beforeHtml = html.substring(0, firstChapterLink.start);

            // 查找最近的容器开始标签（div, ul, ol, dl, section等）
            final containerStartPattern =
                RegExp(r'<(div|ul|ol|dl|section)[^>]*>', caseSensitive: false);
            final containerStarts =
                containerStartPattern.allMatches(beforeHtml).toList();

            if (containerStarts.isNotEmpty) {
              final lastContainerStart = containerStarts.last;
              finalContainerTag = lastContainerStart.group(1);
              final containerStartPos = lastContainerStart.start;

              // 提取容器的class或id属性
              final containerHtml =
                  html.substring(containerStartPos, lastContainerStart.end);
              // 使用普通字符串而不是原始字符串，以便正确处理字符类中的引号
              final classPattern2 = RegExp('class\\s*=\\s*["\']([^"\']+)["\']',
                  caseSensitive: false);
              final idPattern2 = RegExp('id\\s*=\\s*["\']([^"\']+)["\']',
                  caseSensitive: false);
              final classMatch2 = classPattern2.firstMatch(containerHtml);
              final idMatch2 = idPattern2.firstMatch(containerHtml);

              finalContainerClass =
                  classMatch2?.group(1)?.split(RegExp(r'\s+')).first;
              finalContainerId = idMatch2?.group(1);

              AppLog.instance.put(
                  '找到容器: <$finalContainerTag>${finalContainerClass != null ? ' class="$finalContainerClass"' : ''}${finalContainerId != null ? ' id="$finalContainerId"' : ''}');
            }
          } else {
            // 如果找到了directory容器，使用它的信息
            finalContainerTag = 'div';
            AppLog.instance.put(
                '使用directory容器: class=$finalContainerClass, id=$finalContainerId');
          }

          // 生成降级规则并尝试
          if (finalContainerClass != null ||
              finalContainerId != null ||
              finalContainerTag != null) {
            final fallbackRules = <String>[];

            if (finalContainerId != null) {
              // 如果容器有id，尝试使用id选择器
              fallbackRules.add('id.$finalContainerId@tag.a');
              fallbackRules.add('id.$finalContainerId@tag.p');
              fallbackRules.add('id.$finalContainerId@tag.li');
              fallbackRules.add('id.$finalContainerId@tag.dd');
            }

            if (finalContainerClass != null) {
              // 如果容器有class，尝试使用class选择器
              fallbackRules.add('class.$finalContainerClass@tag.a');
              fallbackRules.add('class.$finalContainerClass@tag.p');
              fallbackRules.add('class.$finalContainerClass@tag.li');
              fallbackRules.add('class.$finalContainerClass@tag.dd');
            }

            // 尝试直接选择容器内的链接（使用CSS选择器格式）
            if (finalContainerTag != null) {
              if (finalContainerClass != null) {
                fallbackRules.add('$finalContainerTag.$finalContainerClass a');
              }
              if (finalContainerId != null) {
                fallbackRules.add('$finalContainerTag#$finalContainerId a');
              }
              fallbackRules.add('$finalContainerTag a');
            }

            // 尝试每个降级规则
            for (final fallbackRule in fallbackRules) {
              AppLog.instance.put('尝试降级规则: $fallbackRule');

              // 创建临时规则对象
              final fallbackTocRule = TocRule(
                chapterList: fallbackRule,
                chapterName: source.ruleToc?.chapterName ?? 'tag.a@text',
                chapterUrl: source.ruleToc?.chapterUrl ?? 'tag.a@href',
                isVip: source.ruleToc?.isVip,
                updateTime: source.ruleToc?.updateTime,
                nextTocUrl: source.ruleToc?.nextTocUrl,
              );

              final fallbackChapterList = RuleParser.parseTocRule(
                html,
                fallbackTocRule,
                baseUrl: effectiveBaseUrl,
              );

              AppLog.instance.put(
                  '降级规则 $fallbackRule 匹配结果: ${fallbackChapterList.length} 个章节');

              // 如果匹配到的章节数量大于当前结果，使用这个规则
              // 这样可以确保选择匹配到最多章节的规则
              if (fallbackChapterList.length > chapterList.length) {
                AppLog.instance.put('降级规则 $fallbackRule 匹配到更多章节，使用此规则');
                chapterList = fallbackChapterList;
                // 如果匹配到的章节数量足够多（比如超过10个），可以认为这是正确的规则
                if (fallbackChapterList.length >= 10) {
                  AppLog.instance.put(
                      '降级规则 $fallbackRule 匹配到足够多的章节（${fallbackChapterList.length}个），停止尝试其他规则');
                  break;
                }
              }
            }
          }
        }
      }

      if (chapterList.isEmpty && source.ruleToc?.chapterList != null) {
        AppLog.instance.put('警告: 章节列表为空，但规则不为空。可能是规则不匹配HTML结构。');
        AppLog.instance.put(
            'HTML前2000字符: ${html.substring(0, html.length > 2000 ? 2000 : html.length)}');

        // 尝试查找可能的目录相关元素（用于调试）
        final dlPattern =
            RegExp('<dl[^>]*>.*?</dl>', caseSensitive: false, dotAll: true);
        final dlMatches = dlPattern.allMatches(html);
        AppLog.instance.put('HTML中找到 ${dlMatches.length} 个 <dl> 标签');
        if (dlMatches.isNotEmpty) {
          AppLog.instance.put(
              '第一个<dl>标签内容（前500字符）: ${dlMatches.first.group(0)?.substring(0, dlMatches.first.group(0)!.length > 500 ? 500 : dlMatches.first.group(0)!.length)}');
        }

        final ulPattern =
            RegExp('<ul[^>]*>.*?</ul>', caseSensitive: false, dotAll: true);
        final ulMatches = ulPattern.allMatches(html);
        AppLog.instance.put('HTML中找到 ${ulMatches.length} 个 <ul> 标签');

        final olPattern =
            RegExp('<ol[^>]*>.*?</ol>', caseSensitive: false, dotAll: true);
        final olMatches = olPattern.allMatches(html);
        AppLog.instance.put('HTML中找到 ${olMatches.length} 个 <ol> 标签');

        // 查找所有包含链接的元素（可能是章节链接）
        final linkPattern = RegExp('<a[^>]*href[^>]*>.*?</a>',
            caseSensitive: false, dotAll: true);
        final linkMatches = linkPattern.allMatches(html);
        AppLog.instance.put('HTML中找到 ${linkMatches.length} 个链接');

        // 记录调试信息后，抛出异常
        throw TocEmptyException(
            '章节列表为空: 规则不匹配HTML结构 (书源: ${source.bookSourceName})');
      }

      // 转换为BookChapter对象
      var chapters = <BookChapter>[];
      for (int i = 0; i < chapterList.length; i++) {
        final chapterData = chapterList[i];
        final chapterName = chapterData['chapterName'] ?? '';
        final isVolumeStr = chapterData['isVolume'] ?? '0';
        final isVolume =
            isVolumeStr == '1' || isVolumeStr.toLowerCase() == 'true';
        final chapterUrl = chapterData['chapterUrl'];

        // 参考项目逻辑：
        // 1. 卷名（isVolume）不需要URL，即使URL为空也会添加
        // 2. 非卷名章节必须有URL
        if (!isVolume && (chapterUrl == null || chapterUrl.isEmpty)) {
          AppLog.instance.put('章节 ${i + 1} 缺少URL且不是卷名，跳过');
          continue;
        }

        // 过滤分页链接（参考项目：不添加标题为空的章节，以及分页链接）
        // 过滤包含"上一页"、"下一页"等分页文本的章节
        // 使用更严格的空白检查：去除所有空白字符后检查是否为空
        final trimmedName = chapterName.trim().replaceAll(RegExp(r'\s+'), '');
        if (chapterName.contains('上一页') ||
            chapterName.contains('下一页') ||
            chapterName.contains('上一章') ||
            chapterName.contains('下一章') ||
            trimmedName.isEmpty) {
          AppLog.instance
              .put('过滤分页链接或空标题章节: 原始="$chapterName", 处理后="$trimmedName"');
          continue;
        }

        // 构建章节URL（卷名可能没有URL）
        String finalUrl;
        if (isVolume) {
          // 卷名不需要URL，使用空字符串
          finalUrl = '';
        } else if (chapterUrl != null && chapterUrl.isNotEmpty) {
          // 使用effectiveBaseUrl而不是tocUrl，确保baseUrl是有效的绝对URL
          finalUrl = NetworkService.joinUrl(effectiveBaseUrl, chapterUrl);
        } else {
          // 非卷名但没有URL，跳过（已在上面检查）
          continue;
        }

        final chapter = BookChapter(
          url: finalUrl,
          title: chapterName.isNotEmpty ? chapterName : '第${i + 1}章',
          bookUrl: book.bookUrl,
          baseUrl: source.bookSourceUrl,
          index: chapters.length, // 使用过滤后的索引
          isVolume: isVolume, // 设置卷名标志
          isVip: chapterData['isVip'] == 'true' || chapterData['isVip'] == '1',
          tag: chapterData['updateTime'],
        );

        chapters.add(chapter);
      }

      // 过滤最新章节：找到第一个包含数字编号的章节（如"1、"、"2、"等），这应该是真正的目录开始
      // 参考项目：只添加标题不为空的章节，不添加分页链接
      if (chapters.isNotEmpty) {
        int startIndex = 0;
        // 查找第一个包含数字编号的章节（如"1、"、"2、"、"第一章"等）
        // 或者查找第一个标题看起来像章节标题的（包含"章"、"节"等）
        for (int i = 0; i < chapters.length; i++) {
          final title = chapters[i].title;
          // 检查是否包含数字编号模式（如"1、"、"2、"、"第一章"、"第1章"等）
          // 或者包含"章"、"节"等关键词，且不是"最新章节"、"最新章"等
          final hasNumberPattern =
              RegExp(r'^\d+[、.]|^第\d+章|^第[一二三四五六七八九十]+章').hasMatch(title);
          final hasChapterKeyword = title.contains('章') || title.contains('节');
          final isNotLatestChapter =
              !title.contains('最新') && !title.contains('最近');

          if (hasNumberPattern ||
              (hasChapterKeyword && isNotLatestChapter && i >= 6)) {
            // 如果找到了数字编号模式，或者找到了包含"章"的标题且不是"最新"相关，且索引>=6（跳过前几个）
            startIndex = i;
            AppLog.instance.put('找到真正的目录开始位置: 索引=$startIndex, 标题=$title');
            break;
          }
        }

        // 如果找到了真正的目录开始位置，移除前面的最新章节
        // 但至少要保留一个章节，避免全部删除
        if (startIndex > 0 && startIndex < chapters.length) {
          AppLog.instance.put('移除前 $startIndex 个最新章节');
          chapters.removeRange(0, startIndex);
          // 重新设置索引
          for (int i = 0; i < chapters.length; i++) {
            chapters[i] = chapters[i].copyWith(index: i);
          }
        }

        // 如果第一条章节的标题为空或只包含空白字符，移除它
        // 但需要确保不会把所有章节都删除
        while (chapters.isNotEmpty) {
          final firstTitle =
              chapters[0].title.trim().replaceAll(RegExp(r'\s+'), '');
          if (firstTitle.isEmpty) {
            AppLog.instance.put('移除第一条空标题章节: 原始标题="${chapters[0].title}"');
            chapters.removeAt(0);
            // 重新设置索引
            for (int i = 0; i < chapters.length; i++) {
              chapters[i] = chapters[i].copyWith(index: i);
            }
            // 如果删除后列表为空，停止循环
            if (chapters.isEmpty) {
              break;
            }
          } else {
            AppLog.instance.put('第一条章节标题: "${chapters[0].title}"');
            break;
          }
        }

        // 输出前几条章节的标题，用于调试
        if (chapters.isNotEmpty) {
          final previewCount = chapters.length > 5 ? 5 : chapters.length;
          for (int i = 0; i < previewCount; i++) {
            AppLog.instance.put('章节 ${i + 1}: "${chapters[i].title}"');
          }
        }
      }

      // 去重：保留第一个发现的章节
      // LinkedHashSet 保留第一次出现的元素
      final originalCount = chapters.length;
      chapters = LinkedHashSet<BookChapter>.from(chapters).toList();
      if (chapters.length < originalCount) {
        AppLog.instance
            .put('章节去重: $originalCount -> ${chapters.length}（保留第一个发现的）');
      }

      // 重新设置索引
      for (int i = 0; i < chapters.length; i++) {
        chapters[i] = chapters[i].copyWith(index: i);
      }

      AppLog.instance.put('获取章节列表成功: 共 ${chapters.length} 个章节');
      // 不保存到数据库，直接返回
      return chapters;
    } catch (e, stackTrace) {
      AppLog.instance.put('获取章节列表失败', error: e);
      AppLog.instance.put('错误堆栈: $stackTrace');
      // 重新抛出异常，让调用者能够处理错误
      // 如果调用者希望静默处理，可以在调用处捕获异常
      rethrow;
    }
  }

  /// 更新书籍目录（用于更新目录功能，支持分页获取）
  Future<bool> updateChapterList(Book book) async {
    if (book.isLocal || !book.canUpdate) {
      return false;
    }

    try {
      final db = await _db.database;
      if (db == null) return false;

      // 先获取书籍信息（如果需要）
      final updatedBook = await getBookInfo(book);
      if (updatedBook == null) return false;

      // 使用 getChapterList 方法获取所有章节（支持分页）
      final chapters = await getChapterList(updatedBook);

      if (chapters.isEmpty) {
        return false;
      }

      // 更新书籍信息
      await saveBook(updatedBook.copyWith(
        totalChapterNum: chapters.length,
        lastCheckTime: DateTime.now().millisecondsSinceEpoch,
        latestChapterTitle: chapters.isNotEmpty ? chapters.last.title : null,
      ));

      return true;
    } catch (e) {
      AppLog.instance.put('更新目录失败', error: e);
      return false;
    }
  }

  /// 批量更新目录
  Future<Map<String, bool>> updateChapterLists(List<Book> books) async {
    final results = <String, bool>{};

    // 过滤出可以更新的网络书籍
    final booksToUpdate =
        books.where((book) => !book.isLocal && book.canUpdate).toList();

    for (final book in booksToUpdate) {
      try {
        final success = await updateChapterList(book);
        results[book.bookUrl] = success;
      } catch (e) {
        results[book.bookUrl] = false;
      }
    }

    return results;
  }

  /// 通过URL添加书籍
  Future<int> addBookByUrl(String bookUrls, {int? groupId}) async {
    int successCount = 0;
    final urls = bookUrls.split('\n');

    for (final url in urls) {
      final bookUrl = url.trim();
      if (bookUrl.isEmpty) continue;

      try {
        // 检查书籍是否已存在
        final existingBook = await getBookByUrl(bookUrl);
        if (existingBook != null) {
          successCount++;
          continue;
        }

        // 获取baseUrl
        final uri = Uri.tryParse(bookUrl);
        if (uri == null) continue;
        final baseUrl = '${uri.scheme}://${uri.host}';

        // 查找匹配的书源
        BookSource? source =
            await _bookSourceService.getBookSourceByUrl(baseUrl);

        // 如果没找到，尝试通过bookUrlPattern匹配
        if (source == null) {
          final allSources =
              await _bookSourceService.getAllBookSources(enabledOnly: true);
          for (final s in allSources) {
            if (s.bookUrlPattern != null && s.bookUrlPattern!.isNotEmpty) {
              try {
                final pattern = RegExp(s.bookUrlPattern!);
                if (pattern.hasMatch(bookUrl)) {
                  source = s;
                  break;
                }
              } catch (e) {
                // 正则表达式错误，跳过
                continue;
              }
            }
          }
        }

        if (source == null) continue;

        // 创建书籍对象
        final book = Book(
          bookUrl: bookUrl,
          origin: source.bookSourceUrl,
          originName: source.bookSourceName,
          canUpdate: true,
        );

        // 获取书籍信息
        final bookInfo = await getBookInfo(book);
        if (bookInfo == null) continue;

        // 检查是否已存在同名同作者的书籍
        final existingBookByName =
            await getBookByNameAndAuthor(bookInfo.name, bookInfo.author);
        if (existingBookByName != null) {
          // 如果已存在，更新章节列表
          final chapters = await getChapterList(bookInfo);
          if (chapters.isNotEmpty) {
            // 删除旧章节
            final db = await _db.database;
            if (db != null) {
              await db.delete(
                'chapters',
                where: 'bookUrl = ?',
                whereArgs: [existingBookByName.bookUrl],
              );
              // 保存新章节
              await saveChapters(chapters
                  .map((c) => c.copyWith(bookUrl: existingBookByName.bookUrl))
                  .toList());
            }
          }
          successCount++;
          continue;
        }

        // 获取章节列表
        final chapters = await getChapterList(bookInfo);
        if (chapters.isEmpty) continue;

        // 设置分组
        final finalBook =
            groupId != null ? bookInfo.copyWith(group: groupId) : bookInfo;

        // 保存书籍
        await createBook(finalBook);

        successCount++;
      } catch (e) {
        // 添加失败，继续下一个
        continue;
      }
    }

    return successCount;
  }

  /// 根据URL获取书籍
  Future<Book?> getBookByUrl(String bookUrl) async {
    final db = await _db.database;
    if (db == null) return null;
    final result = await db.query(
      'books',
      where: 'bookUrl = ?',
      whereArgs: [bookUrl],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _bookFromDbMap(result.first);
  }

  /// 根据书名和作者获取书籍
  Future<Book?> getBookByNameAndAuthor(String name, String author) async {
    final db = await _db.database;
    if (db == null) return null;
    final result = await db.query(
      'books',
      where: 'name = ? AND author = ?',
      whereArgs: [name, author],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _bookFromDbMap(result.first);
  }

  /// 通过书名和作者搜索并添加书籍（用于导入书单）
  Future<int> addBookByNameAndAuthor(String name, String author,
      {int? groupId}) async {
    if (name.isEmpty) return 0;

    // 检查是否已存在
    final existingBook = await getBookByNameAndAuthor(name, author);
    if (existingBook != null) {
      return 0; // 已存在，不重复添加
    }

    // 搜索书籍
    final searchResults = await searchBooks(name);

    // 精确匹配书名和作者
    Book? matchedBook;
    for (final book in searchResults) {
      if (book.name == name && book.author == author) {
        matchedBook = book;
        break;
      }
    }

    if (matchedBook == null) {
      return 0; // 未找到匹配的书籍
    }

    // 获取书籍详情
    final bookInfo = await getBookInfo(matchedBook);
    if (bookInfo == null) return 0;

    // 获取章节列表
    final chapters = await getChapterList(bookInfo);
    if (chapters.isEmpty) return 0;

    // 设置分组
    final finalBook =
        groupId != null ? bookInfo.copyWith(group: groupId) : bookInfo;

    // 保存书籍
    await createBook(finalBook);

    return 1;
  }

  /// 导入书单（从JSON）
  Future<int> importBooklist(String jsonText, {int? groupId}) async {
    try {
      // 解析JSON
      final jsonData = jsonDecode(jsonText);
      if (jsonData is! List) {
        throw Exception('书单格式错误：应为数组格式');
      }

      int successCount = 0;

      // 遍历书单
      for (final item in jsonData) {
        if (item is! Map) continue;

        final name = item['name']?.toString() ?? '';
        final author = item['author']?.toString() ?? '';

        if (name.isEmpty) continue;

        try {
          final count =
              await addBookByNameAndAuthor(name, author, groupId: groupId);
          successCount += count;
        } catch (e) {
          // 单个书籍添加失败，继续下一个
          continue;
        }
      }

      return successCount;
    } catch (e) {
      throw Exception('导入书单失败: $e');
    }
  }

  /// 获取章节正文
  /// 参考项目：支持分页获取（nextContentUrl），循环获取所有页面的内容
  /// [book] 可选参数，传入后会自动检查和保存文件缓存，避免重复网络请求
  Future<String?> getChapterContent(
    BookChapter chapter,
    BookSource source, {
    String? bookName,
    String? bookOrigin,
    Book? book, // 新增：用于缓存检查和保存
  }) async {
    if (source.ruleContent == null) {
      AppLog.instance.put('获取章节内容失败: 内容规则为空 (章节: ${chapter.title})');
      return null;
    }

    // ✅ 新策略: 优先从文件存储读取
    if (book != null && !book.isLocal) {
      // 1. 如果chapter有localPath,从文件读取
      if (chapter.localPath != null && chapter.localPath!.isNotEmpty) {
        final fileContent = await ChapterContentService.instance
            .getChapterContent(book, chapter);
        if (fileContent != null && fileContent.isNotEmpty) {
          AppLog.instance.put(
            '从文件存储读取: ${chapter.title} (${fileContent.length}字)'
          );
          return fileContent;
        }
        // localPath存在但文件不存在,继续从网络获取
        AppLog.instance.put(
          '警告: localPath存在但文件不存在: ${chapter.title}'
        );
      }
      
      // 2. 尝试从文件系统读取(向后兼容旧缓存)
      final fileContent = await ChapterContentService.instance
          .getChapterContent(book, chapter);
      if (fileContent != null && fileContent.isNotEmpty) {
        AppLog.instance.put(
          '从文件系统读取(无localPath): ${chapter.title} (${fileContent.length}字)'
        );
        // 更新localPath
        final localPath = ChapterContentService.instance
            .getChapterLocalPath(book, chapter);
        chapter.localPath = localPath;
        // 异步更新数据库,不阻塞返回
        _updateChapterLocalPath(chapter.bookUrl, chapter.url, localPath)
            .catchError((e) => AppLog.instance.put('更新localPath失败', error: e));
        return fileContent;
      }

      // 3. 回退: 从旧的CacheService读取
      final cachedContent =
          await CacheService.instance.getCachedChapterContent(book, chapter);
      if (cachedContent != null && cachedContent.isNotEmpty) {
        AppLog.instance.put(
          '从旧缓存读取: ${chapter.title} (${cachedContent.length}字)'
        );
        return cachedContent;
      }
    }

    // 检查是否正在请求该章节（防止重复请求）
    // 参考项目：使用 bookUrl + chapterUrl 作为缓存的 key
    final chapterKey = chapter.primaryStr();
    if (_loadingChapters.containsKey(chapterKey)) {
      // 等待现有请求完成
      return await _loadingChapters[chapterKey];
    }

    // 创建请求Future
    final requestFuture = _getChapterContentInternal(chapter, source,
        bookName: bookName, bookOrigin: bookOrigin, book: book);

    // 将请求添加到跟踪Map
    _loadingChapters[chapterKey] = requestFuture;

    try {
      final result = await requestFuture;
      return result;
    } finally {
      // 请求完成后移除跟踪
      _loadingChapters.remove(chapterKey);
    }
  }

  /// 获取章节正文的内部实现
  /// 参考项目：支持分页获取（nextContentUrl），循环获取所有页面的内容
  Future<String?> _getChapterContentInternal(
    BookChapter chapter,
    BookSource source, {
    String? bookName,
    String? bookOrigin,
    Book? book, // 新增：用于缓存保存
  }) async {
    try {
      // 参考项目：使用章节URL作为baseUrl，支持分页获取
      // 参考项目：BookContent.analyzeContent
      var currentUrl = chapter.url;
      var redirectUrl = currentUrl; // 重定向后的URL
      var visitedUrls = <String>{currentUrl};
      var contentList = <String>[];

      // 参考项目：获取下一章的URL（用于判断是否到达下一章）
      final localChapters = await _getLocalChapters(chapter.bookUrl);
      BookChapter? nextChapter;
      if (chapter.index + 1 < localChapters.length) {
        nextChapter = localChapters[chapter.index + 1];
      } else if (localChapters.isNotEmpty) {
        // 参考项目：如果下一章不存在，使用第一章（循环）
        nextChapter = localChapters[0];
      }
      final nextChapterUrl = nextChapter?.url;
      final response = await _networkService.get(
        currentUrl,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);
      // 参考项目：获取重定向后的URL（如果有）
      // 注意：Dio的Response可能没有redirectRecord，使用实际请求的URL
      redirectUrl = response.realUri.toString();

      AppLog.instance
          .put('获取章节内容响应: 状态码=${response.statusCode}, 内容长度=${html.length}');

      if (html.isEmpty) {
        AppLog.instance.put('章节内容响应为空');
        throw ContentEmptyException('章节内容为空: ${chapter.title}');
      }

      final pageContent = await RuleParser.parseContentRule(
        html,
        source.ruleContent,
        baseUrl: currentUrl, // 使用当前请求的URL作为baseUrl
        bookName: bookName,
        bookOrigin: bookOrigin,
        applyReplaceRegex: false, // 不在每页应用，而是在合并后统一应用
      );

      if (pageContent == null || pageContent.isEmpty) {
        AppLog.instance.put('章节内容解析失败: 内容为空 (章节: ${chapter.title})');
        throw ContentEmptyException('章节内容为空: ${chapter.title}');
      }

      contentList.add(pageContent);

      // 参考项目：获取下一页URL列表（可能返回多个URL）
      // 参考项目：analyzeRule.getStringList(nextUrlRule, isUrl = true)
      List<String> nextUrlList = [];

      if (source.ruleContent?.nextContentUrl != null &&
          source.ruleContent!.nextContentUrl!.isNotEmpty) {
        AppLog.instance
            .put('获取章节内容下一页URL: 规则=${source.ruleContent!.nextContentUrl}');

        // 参考项目：使用parseListRule获取URL列表（isUrl=true）
        final rawNextUrlList = RuleParser.parseListRule(
          html,
          source.ruleContent!.nextContentUrl!,
          variables: null,
          baseUrl: redirectUrl,
          returnHtml: false,
        );

        // 将相对URL转换为绝对URL，并过滤
        for (final url in rawNextUrlList) {
          if (url.isNotEmpty) {
            final absoluteUrl = url.startsWith('http')
                ? url
                : NetworkService.joinUrl(redirectUrl, url);
            // 参考项目：过滤掉与redirectUrl相同的URL
            if (absoluteUrl != redirectUrl &&
                !visitedUrls.contains(absoluteUrl)) {
              nextUrlList.add(absoluteUrl);
            }
          }
        }

        AppLog.instance.put('获取章节内容下一页URL: 找到 ${nextUrlList.length} 个URL');
        for (int i = 0; i < nextUrlList.length; i++) {
          AppLog.instance.put('  下一页URL ${i + 1}: ${nextUrlList[i]}');
        }
      }

      // 参考项目逻辑：
      // 如果 nextUrlList.size == 0，没有下一页，直接返回
      // 如果 nextUrlList.size == 1，循环获取所有页面
      // 如果 nextUrlList.size > 1，并发获取所有页面
      if (nextUrlList.isEmpty) {
        // 没有下一页，直接返回
        AppLog.instance.put('没有找到下一页URL');
      } else if (nextUrlList.length == 1) {
        // 参考项目：循环获取所有页面
        var nextUrl = nextUrlList[0];
        var pageCount = 1;

        while (nextUrl.isNotEmpty && !visitedUrls.contains(nextUrl)) {
          // 参考项目：检查是否到达下一章
          // 参考项目逻辑：NetworkUtils.getAbsoluteURL(redirectUrl, nextUrl) == NetworkUtils.getAbsoluteURL(redirectUrl, mNextChapterUrl)
          if (nextChapterUrl != null) {
            // 将两个 URL 都通过 getAbsoluteURL 规范化后再比较
            final normalizedNextUrl =
                NetworkUtils.getAbsoluteURL(redirectUrl, nextUrl);
            final normalizedNextChapterUrl =
                NetworkUtils.getAbsoluteURL(redirectUrl, nextChapterUrl);

            if (_urlEquals(normalizedNextUrl, normalizedNextChapterUrl)) {
              AppLog.instance.put('下一页URL等于下一章URL，停止获取');
              break;
            }
          }

          pageCount++;
          visitedUrls.add(nextUrl);
          AppLog.instance.put('获取章节内容第 $pageCount 页: $nextUrl');

          try {
            final nextResponse = await _networkService.get(
              nextUrl,
              headers: NetworkService.parseHeaders(source.header),
              retryCount: 1,
            );

            final nextHtml = await NetworkService.getResponseText(nextResponse);
            final nextRedirectUrl = nextResponse.realUri.toString();

            if (nextHtml.isEmpty) {
              AppLog.instance.put('章节内容响应为空，停止获取');
              break;
            }

            final nextPageContent = await RuleParser.parseContentRule(
              nextHtml,
              source.ruleContent,
              baseUrl: nextUrl,
              bookName: bookName,
              bookOrigin: bookOrigin,
              applyReplaceRegex: false,
            );

            if (nextPageContent != null && nextPageContent.isNotEmpty) {
              contentList.add(nextPageContent);
              AppLog.instance.put('第${contentList.length}页完成');
            }

            // 获取下一页URL
            if (source.ruleContent?.nextContentUrl != null &&
                source.ruleContent!.nextContentUrl!.isNotEmpty) {
              final nextNextUrlList = RuleParser.parseListRule(
                nextHtml,
                source.ruleContent!.nextContentUrl!,
                variables: null,
                baseUrl: nextRedirectUrl,
                returnHtml: false,
              );

              // 转换为绝对URL并过滤
              final filteredNextUrls = <String>[];
              for (final url in nextNextUrlList) {
                if (url.isNotEmpty) {
                  final absoluteUrl = url.startsWith('http')
                      ? url
                      : NetworkService.joinUrl(nextRedirectUrl, url);
                  if (absoluteUrl != nextRedirectUrl &&
                      !visitedUrls.contains(absoluteUrl)) {
                    // 检查是否到达下一章（参考项目：使用 getAbsoluteURL 规范化后比较）
                    if (nextChapterUrl != null) {
                      final normalizedAbsoluteUrl = NetworkUtils.getAbsoluteURL(
                          nextRedirectUrl, absoluteUrl);
                      final normalizedNextChapterUrl =
                          NetworkUtils.getAbsoluteURL(
                              nextRedirectUrl, nextChapterUrl);
                      if (_urlEquals(
                          normalizedAbsoluteUrl, normalizedNextChapterUrl)) {
                        AppLog.instance.put('检测到下一页URL等于下一章URL，停止获取');

                        filteredNextUrls.clear();
                        break;
                      }
                    }
                    filteredNextUrls.add(absoluteUrl);
                  }
                }
              }

              if (filteredNextUrls.isEmpty) {
                break;
              }
              nextUrl = filteredNextUrls[0];
            } else {
              break;
            }
          } catch (e) {
            AppLog.instance.put('获取第 $pageCount 页失败: $e', error: e);
            break;
          }
        }

        AppLog.instance.put('本章总页数: ${visitedUrls.length}');
      } else {
        // 参考项目：并发获取所有页面
        // 注意：并发模式下也需要过滤掉下一章的URL
        final filteredNextUrlList = <String>[];
        if (nextChapterUrl != null) {
          // 参考项目：使用 getAbsoluteURL 规范化后比较
          final normalizedNextChapterUrl =
              NetworkUtils.getAbsoluteURL(redirectUrl, nextChapterUrl);
          for (final url in nextUrlList) {
            final normalizedUrl = NetworkUtils.getAbsoluteURL(redirectUrl, url);
            if (!_urlEquals(normalizedUrl, normalizedNextChapterUrl)) {
              filteredNextUrlList.add(url);
            } else {
              AppLog.instance.put('并发模式：过滤掉下一章URL: $url');
            }
          }
        } else {
          filteredNextUrlList.addAll(nextUrlList);
        }

        AppLog.instance.put(
            '并发解析正文，总页数: ${filteredNextUrlList.length} (原始: ${nextUrlList.length})');

        final futures = filteredNextUrlList.asMap().entries.map((entry) async {
          final index = entry.key;
          final url = entry.value;
          try {
            final response = await _networkService.get(
              url,
              headers: NetworkService.parseHeaders(source.header),
              retryCount: 1,
            );
            final pageHtml = await NetworkService.getResponseText(response);
            return {'url': url, 'html': pageHtml, 'success': true};
          } catch (e) {
            return {'url': url, 'html': '', 'success': false};
          }
        }).toList();

        final results = await Future.wait(futures);

        for (final result in results) {
          if (result['success'] == true &&
              (result['html'] as String).isNotEmpty) {
            final pageHtml = result['html'] as String;
            final pageUrl = result['url'] as String;

            final pageContent = await RuleParser.parseContentRule(
              pageHtml,
              source.ruleContent,
              baseUrl: pageUrl,
              bookName: bookName,
              bookOrigin: bookOrigin,
              applyReplaceRegex: false,
            );

            if (pageContent != null && pageContent.isNotEmpty) {
              contentList.add(pageContent);
            }
          }
        }
      }

      // 合并所有页面的内容
      if (contentList.isEmpty) {
        AppLog.instance.put('章节内容获取失败: 所有页面内容都为空 (章节: ${chapter.title})');
        throw ContentEmptyException('章节内容为空: ${chapter.title}');
      }

      // 参考项目：将多页内容拼接在一起
      var content = contentList.join('\n');
      final totalPages = contentList.length;
      AppLog.instance.put(
          '章节内容获取成功: 共 $totalPages 页，合并前总长度=${content.length} (章节: ${chapter.title})');

      // 参考项目：在所有页面内容合并后，统一应用replaceRegex规则
      // 参考项目逻辑：先将内容按行分割并trim，应用替换规则，然后在每行前添加全角空格
      if (source.ruleContent?.replaceRegex != null &&
          source.ruleContent!.replaceRegex!.isNotEmpty) {
        // #region agent log
        try {
          final f = File(
              '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
          f.writeAsStringSync(
              '${jsonEncode({
                    "location": "book_service.dart:2449",
                    "message": "book_service应用replaceRegex前",
                    "data": {
                      "replaceRegex": source.ruleContent!.replaceRegex,
                      "contentLength": content.length,
                      "totalPages": totalPages
                    },
                    "timestamp": DateTime.now().millisecondsSinceEpoch,
                    "sessionId": "debug-session",
                    "hypothesisId": "D"
                  })}\n',
              mode: FileMode.append);
        } catch (_) {}
        // #endregion

        AppLog.instance
            .put('应用replaceRegex规则: ${source.ruleContent!.replaceRegex}');

        // 参考项目逻辑：按行分割并trim每行
        final lines = content.split('\n');
        content = lines.map((line) => line.trim()).join('\n');

        // 应用replaceRegex规则
        final beforeReplace = content;
        content = RuleParser.applyReplaceRegex(
            content, source.ruleContent!.replaceRegex!);

        // 参考项目逻辑：按行分割并在每行前添加全角空格（段落缩进）
        final processedLines = content.split('\n');
        content = processedLines.map((line) => '　　$line').join('\n');

        // #region agent log
        try {
          final f = File(
              '/Users/zhangmingxun/Desktop/legado_flutter/.cursor/debug.log');
          f.writeAsStringSync(
              '${jsonEncode({
                    "location": "book_service.dart:2469",
                    "message": "book_service应用replaceRegex后",
                    "data": {
                      "contentLengthBefore": beforeReplace.length,
                      "contentLengthAfter": content.length
                    },
                    "timestamp": DateTime.now().millisecondsSinceEpoch,
                    "sessionId": "debug-session",
                    "hypothesisId": "D"
                  })}\n',
              mode: FileMode.append);
        } catch (_) {}
        // #endregion

        AppLog.instance.put('应用replaceRegex后，内容长度=${content.length}');
      }

      // 输出章节内容 前500 字符
      final previewLength = content.length > 500 ? 500 : content.length;
      // 输出章节内容 后500 字符
      if (content.length > 500) {
        final tailLength = content.length > 500 ? 500 : content.length;
      }

      // 参考项目：在返回内容前立即保存到缓存（BookHelp.saveText）
      // 这样可以避免 _loadingChapters 移除后、缓存写入前的竞态条件
      if (book != null && !book.isLocal) {
        // ✅ 新策略: 保存到文件存储
        final localPath = await ChapterContentService.instance
            .saveChapterContent(book, chapter, content);
        
        if (localPath != null) {
          // 更新内存中的chapter对象
          chapter.localPath = localPath;
          // 异步更新数据库,不阻塞返回
          _updateChapterLocalPath(chapter.bookUrl, chapter.url, localPath)
              .catchError((e) => AppLog.instance.put('更新localPath失败', error: e));
        }
        
        // 同时保存到旧缓存(向后兼容)
        await CacheService.instance.saveChapterContent(book, chapter, content);
      } else if (book == null) {
        // 未传入 book 参数，尝试从数据库查询（向后兼容）
        try {
          final dbBook = await getBookByUrl(chapter.bookUrl);
          if (dbBook != null && !dbBook.isLocal) {
            await CacheService.instance
                .saveChapterContent(dbBook, chapter, content);
          }
        } catch (e) {
          // 缓存失败不影响返回内容
        }
      }

      return content;
    } catch (e, stackTrace) {
      AppLog.instance.put('获取章节内容失败', error: e);
      AppLog.instance.put('错误堆栈: $stackTrace');
      AppLog.instance.put('章节URL: ${chapter.url}, 章节标题: ${chapter.title}');
      return null;
    }
  }

  /// 保存书籍到书架
  Future<void> saveBook(Book book) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.insert(
      'books',
      _bookToDbMap(book),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 创建书籍（保存书籍和章节）
  Future<Book> createBook(Book book) async {
    await saveBook(book);
    return book;
  }

  /// 创建章节
  Future<void> createChapter(BookChapter chapter) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.insert(
      'chapters',
      _chapterToDbMap(chapter),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 从书架删除书籍
  Future<void> deleteBook(String bookUrl) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.delete(
      'books',
      where: 'bookUrl = ?',
      whereArgs: [bookUrl],
    );
    // 章节会通过外键级联删除
  }

  /// 获取书架所有书籍
  Future<List<Book>> getBookshelfBooks() async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'books',
      orderBy: '"order" ASC, durChapterTime DESC',
    );
    return result.map((json) => _bookFromDbMap(json)).toList();
  }

  /// 获取最后阅读的书籍
  /// 参考项目：appDb.bookDao.lastReadBook
  Future<Book?> getLastReadBook() async {
    final db = await _db.database;
    if (db == null) return null;

    try {
      // 按最后阅读时间排序，获取最近阅读的书籍
      final result = await db.query(
        'books',
        orderBy: 'durChapterTime DESC',
        limit: 1,
      );

      if (result.isEmpty) return null;
      return _bookFromDbMap(result.first);
    } catch (e) {
      AppLog.instance.put('获取最后阅读书籍失败: $e', error: e);
      return null;
    }
  }

  /// 根据分组获取书籍
  Future<List<Book>> getBooksByGroup(int groupId) async {
    final db = await _db.database;
    if (db == null) return [];

    final result = await db.query(
      'books',
      where: '"group" = ?',
      whereArgs: [groupId],
      orderBy: '"order" ASC, durChapterTime DESC',
    );
    return result.map((json) => _bookFromDbMap(json)).toList();
  }

  /// 更新书籍分组
  Future<void> updateBookGroup(String bookUrl, int groupId) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.update(
      'books',
      {'group': groupId},
      where: 'bookUrl = ?',
      whereArgs: [bookUrl],
    );
  }

  /// 更新书籍阅读进度
  Future<void> updateReadingProgress(
    String bookUrl,
    int chapterIndex,
    int chapterPos,
    String? chapterTitle,
  ) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.update(
      'books',
      {
        'durChapterIndex': chapterIndex,
        'durChapterPos': chapterPos,
        'durChapterTitle': chapterTitle,
        'durChapterTime': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'bookUrl = ?',
      whereArgs: [bookUrl],
    );
  }

  /// 构建搜索URL
  String _buildSearchUrl(String searchUrl, String keyword) {
    return searchUrl.replaceAll('{{key}}', Uri.encodeComponent(keyword));
  }

  /// 保存章节列表
  Future<void> saveChapters(List<BookChapter> chapters) async {
    if (chapters.isEmpty) return;

    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');

    // 先删除该书籍的所有章节，然后重新插入
    // 这样可以避免由于 index 不同导致的重复记录
    final bookUrl = chapters.first.bookUrl;
    await db.delete(
      'chapters',
      where: 'bookUrl = ?',
      whereArgs: [bookUrl],
    );

    final batch = db.batch();

    for (final chapter in chapters) {
      batch.insert(
        'chapters',
        _chapterToDbMap(chapter),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 获取本地章节列表
  Future<List<BookChapter>> _getLocalChapters(String bookUrl) async {
    final db = await _db.database;
    if (db == null) return [];
    final result = await db.query(
      'chapters',
      where: 'bookUrl = ?',
      whereArgs: [bookUrl],
      orderBy: '"index" ASC',
    );
    return result.map((json) => _chapterFromDbMap(json)).toList();
  }

  /// 从数据库获取指定索引的章节（参考项目：bookChapterDao.getChapter）
  /// 确保返回的章节的 index 字段与请求的索引一致
  Future<BookChapter?> getChapterByIndex(String bookUrl, int index) async {
    final db = await _db.database;
    if (db == null) return null;
    final result = await db.query(
      'chapters',
      where: 'bookUrl = ? AND "index" = ?',
      whereArgs: [bookUrl, index],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return _chapterFromDbMap(result.first);
  }

  /// Book转数据库Map
  Map<String, dynamic> _bookToDbMap(Book book) {
    return {
      'bookUrl': book.bookUrl,
      'tocUrl': book.tocUrl,
      'origin': book.origin,
      'originName': book.originName,
      'name': book.name,
      'author': book.author,
      'kind': book.kind,
      'customTag': book.customTag,
      'coverUrl': book.coverUrl,
      'customCoverUrl': book.customCoverUrl,
      'intro': book.intro,
      'customIntro': book.customIntro,
      'charset': book.charset,
      'type': book.type,
      'group': book.group,
      'latestChapterTitle': book.latestChapterTitle,
      'latestChapterTime': book.latestChapterTime,
      'lastCheckTime': book.lastCheckTime,
      'lastCheckCount': book.lastCheckCount,
      'totalChapterNum': book.totalChapterNum,
      'durChapterTitle': book.durChapterTitle,
      'durChapterIndex': book.durChapterIndex,
      'durChapterPos': book.durChapterPos,
      'durChapterTime': book.durChapterTime,
      'wordCount': book.wordCount,
      'canUpdate': book.canUpdate ? 1 : 0,
      'order': book.order,
      'originOrder': book.originOrder,
      'variable': book.variable,
      'readConfig': book.readConfig != null
          ? jsonEncode(book.readConfig!.toJson())
          : null,
      'syncTime': book.syncTime,
    };
  }

  /// 数据库Map转Book
  Book _bookFromDbMap(Map<String, dynamic> map) {
    return Book(
      bookUrl: map['bookUrl'] ?? '',
      tocUrl: map['tocUrl'] ?? '',
      origin: map['origin'] ?? BookType.localTag,
      originName: map['originName'] ?? '',
      name: map['name'] ?? '',
      author: map['author'] ?? '',
      kind: map['kind'],
      customTag: map['customTag'],
      coverUrl: map['coverUrl'],
      customCoverUrl: map['customCoverUrl'],
      intro: map['intro'],
      customIntro: map['customIntro'],
      charset: map['charset'],
      type: map['type'] ?? BookType.text,
      group: map['group'] ?? 0,
      latestChapterTitle: map['latestChapterTitle'],
      latestChapterTime: map['latestChapterTime'] ?? 0,
      lastCheckTime: map['lastCheckTime'] ?? 0,
      lastCheckCount: map['lastCheckCount'] ?? 0,
      totalChapterNum: map['totalChapterNum'] ?? 0,
      durChapterTitle: map['durChapterTitle'],
      durChapterIndex: map['durChapterIndex'] ?? 0,
      durChapterPos: map['durChapterPos'] ?? 0,
      durChapterTime: map['durChapterTime'] ?? 0,
      wordCount: map['wordCount'],
      canUpdate: map['canUpdate'] == 1,
      order: map['order'] ?? 0,
      originOrder: map['originOrder'] ?? 0,
      variable: map['variable'],
      readConfig: map['readConfig'] != null
          ? ReadConfig.fromJson(jsonDecode(map['readConfig']))
          : null,
      syncTime: map['syncTime'] ?? 0,
    );
  }

  /// BookChapter转数据库Map
  Map<String, dynamic> _chapterToDbMap(BookChapter chapter) {
    return {
      'url': chapter.url,
      'bookUrl': chapter.bookUrl,
      'title': chapter.title,
      'isVolume': chapter.isVolume ? 1 : 0,
      'baseUrl': chapter.baseUrl,
      'index': chapter.index,
      'isVip': chapter.isVip ? 1 : 0,
      'isPay': chapter.isPay ? 1 : 0,
      'resourceUrl': chapter.resourceUrl,
      'tag': chapter.tag,
      'wordCount': chapter.wordCount,
      'start': chapter.start,
      'end': chapter.end,
      'startFragmentId': chapter.startFragmentId,
      'endFragmentId': chapter.endFragmentId,
      'variable': chapter.variable,
    };
  }

  /// 数据库Map转BookChapter
  BookChapter _chapterFromDbMap(Map<String, dynamic> map) {
    return BookChapter(
      url: map['url'] ?? '',
      title: map['title'] ?? '',
      isVolume: map['isVolume'] == 1,
      baseUrl: map['baseUrl'] ?? '',
      bookUrl: map['bookUrl'] ?? '',
      index: map['index'] ?? 0,
      isVip: map['isVip'] == 1,
      isPay: map['isPay'] == 1,
      resourceUrl: map['resourceUrl'],
      tag: map['tag'],
      wordCount: map['wordCount'],
      start: map['start'],
      end: map['end'],
      startFragmentId: map['startFragmentId'],
      endFragmentId: map['endFragmentId'],
      variable: map['variable'],
    );
  }

  /// 更新书籍排序
  Future<void> updateBookOrder(String bookUrl, int order) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.update(
      'books',
      {'order': order},
      where: 'bookUrl = ?',
      whereArgs: [bookUrl],
    );
  }

  /// 更新书籍信息
  Future<void> updateBook(Book book) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.update(
      'books',
      _bookToDbMap(book),
      where: 'bookUrl = ?',
      whereArgs: [book.bookUrl],
    );
  }

  /// 更新章节字数
  /// 参考项目：BookService.updateChapterWordCount
  Future<void> updateChapterWordCount(BookChapter chapter) async {
    final db = await _db.database;
    if (db == null) throw Exception('数据库不可用（Web平台不支持SQLite）');
    await db.update(
      'chapters',
      {'wordCount': chapter.wordCount},
      where: 'url = ? AND bookUrl = ?',
      whereArgs: [chapter.url, chapter.bookUrl],
    );
  }

  /// 从数据库获取已存在的章节字数
  /// 参考项目：BookChapterList.getWordCount（第272-286行）
  Future<void> getWordCount(List<BookChapter> chapters, Book book) async {
    // 参考项目：如果 AppConfig.tocCountWords 为 false，不处理
    // 这里暂时总是处理，如果需要可以从配置中读取
    try {
      final db = await _db.database;
      if (db == null) return;

      // 从数据库获取已存在的章节列表
      final existingChapters = await _getLocalChapters(book.bookUrl);
      if (existingChapters.isEmpty) return;

      // 创建章节文件名的映射（参考项目：associateBy）
      final wordCountMap = <String, String>{};
      for (final existingChapter in existingChapters) {
        final fileName = _getChapterFileName(existingChapter);
        if (existingChapter.wordCount != null &&
            existingChapter.wordCount!.isNotEmpty) {
          wordCountMap[fileName] = existingChapter.wordCount!;
        }
      }

      // 更新章节字数
      for (final chapter in chapters) {
        final fileName = _getChapterFileName(chapter);
        final wordCount = wordCountMap[fileName];
        if (wordCount != null) {
          chapter.wordCount = wordCount;
        }
      }
    } catch (e) {
      AppLog.instance.put('获取章节字数失败: $e', error: e);
    }
  }

  /// 获取章节文件名（用于字数匹配）
  /// 参考项目：BookChapter.getFileName
  String _getChapterFileName(BookChapter chapter) {
    // 参考项目：使用章节URL的MD5作为文件名
    // 这里简化处理，使用章节索引和URL的组合
    return '${chapter.index}_${chapter.url}';
  }

  /// 更新章节的localPath字段
  /// 
  /// 将章节内容文件路径更新到数据库
  Future<void> _updateChapterLocalPath(
    String bookUrl,
    String chapterUrl,
    String localPath,
  ) async {
    try {
      final db = await _db.database;
      if (db == null) return;

      await db.update(
        'chapters',
        {'localPath': localPath},
        where: 'bookUrl = ? AND url = ?',
        whereArgs: [bookUrl, chapterUrl],
      );
    } catch (e) {
      AppLog.instance.put(
        '更新章节localPath失败: bookUrl=$bookUrl, url=$chapterUrl',
        error: e,
      );
    }
  }
}
