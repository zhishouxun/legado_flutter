import '../models/search_book.dart';
import '../models/book.dart';
import '../models/book_chapter.dart';
import '../models/book_source.dart';
import '../../services/network/network_service.dart';
import '../../utils/parsers/rule_parser.dart';
import '../../utils/concurrent_rate_limiter.dart';
import '../../utils/app_log.dart';
import 'book_remote_datasource.dart';

/// BookRemoteDataSource 的实现类
/// 封装网络请求和规则解析逻辑,负责从书源获取数据
class BookRemoteDataSourceImpl implements BookRemoteDataSource {
  final NetworkService _networkService;

  BookRemoteDataSourceImpl({
    NetworkService? networkService,
  }) : _networkService = networkService ?? NetworkService.instance;

  @override
  Stream<SearchBook> searchBooks(String keyword, BookSource source) async* {
    // 验证书源有效性
    if (!source.enabled ||
        source.searchUrl == null ||
        source.ruleSearch == null) {
      AppLog.instance.put('书源无效或未启用: ${source.bookSourceName}');
      return;
    }

    final searchResults = <SearchBook>[];

    try {
      // 使用并发限流器控制请求速率
      await ConcurrentRateLimiter(source).withLimit(() async {
        // 1. 构建搜索URL
        final searchUrl = _buildSearchUrl(source.searchUrl!, keyword);
        final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, searchUrl);

        // 2. 发送网络请求
        final response = await _networkService.get(
          fullUrl,
          headers: NetworkService.parseHeaders(source.header),
          retryCount: 1,
        );

        // 3. 获取响应文本
        final html = await NetworkService.getResponseText(response);

        if (html.isEmpty) {
          AppLog.instance.put('搜索响应为空: ${source.bookSourceName}');
          return;
        }

        // 4. 使用规则解析搜索结果
        final results = await RuleParser.parseSearchRule(
          html,
          source.ruleSearch,
          variables: {'keyword': keyword},
          baseUrl: fullUrl,
        );

        // 5. 转换为SearchBook对象
        for (final result in results) {
          final bookUrl = result['bookUrl'];
          if (bookUrl == null || bookUrl.isEmpty) continue;

          // 检查 checkKeyWord 规则
          if (source.ruleSearch?.checkKeyWord != null &&
              source.ruleSearch!.checkKeyWord!.isNotEmpty) {
            final checkKeyWordValue = result['checkKeyWord'];
            if (checkKeyWordValue == null || checkKeyWordValue.isEmpty) {
              continue;
            }
          }

          // 处理相对URL
          final finalBookUrl =
              bookUrl.startsWith('http://') || bookUrl.startsWith('https://')
                  ? bookUrl
                  : NetworkService.joinUrl(source.bookSourceUrl, bookUrl);

          // 创建SearchBook对象并添加到列表
          searchResults.add(SearchBook(
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
            tocUrl: finalBookUrl, // 默认使用bookUrl作为tocUrl
          ));
        }
      });
    } catch (e) {
      AppLog.instance.put('搜索失败: ${source.bookSourceName}', error: e);
    }

    // 通过yield逐个返回搜索结果
    for (final searchBook in searchResults) {
      yield searchBook;
    }
  }

  @override
  Future<Book> getBookInfo(Book book, BookSource source) async {
    if (source.ruleBookInfo == null) {
      AppLog.instance.put('获取书籍详情失败: 书籍信息规则为空');
      throw Exception('书籍信息规则为空');
    }

    try {
      // 使用tocUrl或bookUrl作为请求地址
      final infoUrl = book.tocUrl.isNotEmpty ? book.tocUrl : book.bookUrl;

      await ConcurrentRateLimiter(source).withLimit(() async {});

      // 发送请求
      final response = await _networkService.get(
        infoUrl,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);

      if (html.isEmpty) {
        throw Exception('书籍详情响应为空');
      }

      // 使用规则解析书籍信息
      final bookInfo = await RuleParser.parseBookInfoRule(
        html,
        source.ruleBookInfo,
        variables: {},
        baseUrl: infoUrl,
      );

      // 更新Book对象
      return book.copyWith(
        name: bookInfo['name'] ?? book.name,
        author: bookInfo['author'] ?? book.author,
        kind: bookInfo['kind'] ?? book.kind,
        coverUrl: bookInfo['coverUrl'] ?? book.coverUrl,
        intro: bookInfo['intro'] ?? book.intro,
        wordCount: bookInfo['wordCount'] ?? book.wordCount,
        latestChapterTitle: bookInfo['lastChapter'] ?? book.latestChapterTitle,
        tocUrl: bookInfo['tocUrl'] ?? book.tocUrl,
        canUpdate: true, // 默认允许更新
      );
    } catch (e) {
      AppLog.instance.put('获取书籍详情失败: ${book.name}', error: e);
      rethrow;
    }
  }

  @override
  Future<List<BookChapter>> getChapterList(Book book, BookSource source) async {
    if (source.ruleToc == null) {
      AppLog.instance.put('获取章节列表失败: 目录规则为空');
      throw Exception('目录规则为空');
    }

    try {
      // 使用tocUrl或bookUrl
      final tocUrl = book.tocUrl.isNotEmpty ? book.tocUrl : book.bookUrl;

      await ConcurrentRateLimiter(source).withLimit(() async {});

      // 发送请求
      final response = await _networkService.get(
        tocUrl,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);

      if (html.isEmpty) {
        throw Exception('章节列表响应为空');
      }

      // 使用规则解析章节列表
      final chapterDataList = RuleParser.parseTocRule(
        html,
        source.ruleToc,
        variables: {},
        baseUrl: tocUrl,
      );

      final chapters = <BookChapter>[];

      for (int i = 0; i < chapterDataList.length; i++) {
        final chapterData = chapterDataList[i];

        final chapterName = chapterData['chapterName'];
        final chapterUrl = chapterData['chapterUrl'];
        final isVolume =
            chapterData['isVolume'] == 'true' || chapterData['isVolume'] == '1';

        // 跳过无效章节
        if (chapterName == null || chapterName.isEmpty) continue;
        if (!isVolume && (chapterUrl == null || chapterUrl.isEmpty)) continue;

        // 过滤分页链接
        final trimmedName = chapterName.trim().replaceAll(RegExp(r'\s+'), '');
        if (chapterName.contains('上一页') ||
            chapterName.contains('下一页') ||
            chapterName.contains('上一章') ||
            chapterName.contains('下一章') ||
            trimmedName.isEmpty) {
          continue;
        }

        // 构建完整URL
        String finalUrl = '';
        if (chapterUrl != null && chapterUrl.isNotEmpty) {
          finalUrl = NetworkService.joinUrl(tocUrl, chapterUrl);
        } else if (isVolume) {
          finalUrl = '$chapterName$i';
        } else {
          finalUrl = tocUrl;
        }

        final chapter = BookChapter(
          url: finalUrl,
          title: chapterName.isNotEmpty ? chapterName : '第${i + 1}章',
          bookUrl: book.bookUrl,
          baseUrl: source.bookSourceUrl,
          index: chapters.length,
          isVolume: isVolume,
          isVip: chapterData['isVip'] == 'true' || chapterData['isVip'] == '1',
          tag: chapterData['updateTime'],
        );

        chapters.add(chapter);
      }

      if (chapters.isEmpty) {
        throw Exception('章节列表为空');
      }

      return chapters;
    } catch (e) {
      AppLog.instance.put('获取章节列表失败: ${book.name}', error: e);
      rethrow;
    }
  }

  @override
  Future<String> getChapterContent(
    BookChapter chapter,
    BookSource source,
  ) async {
    if (source.ruleContent == null) {
      AppLog.instance.put('获取章节内容失败: 内容规则为空');
      throw Exception('内容规则为空');
    }

    try {
      await ConcurrentRateLimiter(source).withLimit(() async {});

      // 发送请求
      final response = await _networkService.get(
        chapter.url,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);

      if (html.isEmpty) {
        throw Exception('章节内容响应为空');
      }

      // 使用规则解析章节内容
      final content = await RuleParser.parseContentRule(
        html,
        source.ruleContent,
        baseUrl: chapter.url,
        applyReplaceRegex: false, // 由Repository层统一处理替换规则
      );

      if (content == null || content.isEmpty) {
        throw Exception('章节内容解析为空');
      }

      return content;
    } catch (e) {
      AppLog.instance.put('获取章节内容失败: ${chapter.title}', error: e);
      rethrow;
    }
  }

  /// 构建搜索URL(替换关键字占位符)
  String _buildSearchUrl(String searchUrl, String keyword) {
    // 参考BookService的实现
    return searchUrl
        .replaceAll('{{key}}', Uri.encodeComponent(keyword))
        .replaceAll('<searchKey>', Uri.encodeComponent(keyword));
  }
}
