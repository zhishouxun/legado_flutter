import 'dart:async';
import '../../core/base/base_service.dart';
import '../../data/models/book_source.dart';
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';
import '../book/book_service.dart';
import '../network/network_service.dart';
import '../../utils/parsers/rule_parser.dart';
import '../explore_service.dart';

/// 书源调试服务
class BookSourceDebugService extends BaseService {
  static final BookSourceDebugService instance = BookSourceDebugService._init();
  final BookService _bookService = BookService.instance;
  final NetworkService _networkService = NetworkService.instance;
  final ExploreService _exploreService = ExploreService.instance;

  BookSourceDebugService._init();

  /// 调试回调
  Function(int state, String message)? onMessage;
  String? _searchSrc;
  String? _bookSrc;
  String? _tocSrc;
  String? _contentSrc;

  /// 开始调试
  Future<void> startDebug(BookSource source, String key) async {
    onMessage?.call(1, '开始调试: $key');

    try {
      // 判断调试类型
      if (_isUrl(key)) {
        // URL调试 - 详情页
        await _debugBookInfo(source, key);
      } else if (key.contains('::')) {
        // 发现页调试
        final url = key.substring(key.indexOf('::') + 2);
        await _debugExplore(source, url);
      } else if (key.startsWith('++')) {
        // 目录页调试
        final url = key.substring(2);
        await _debugToc(source, url);
      } else if (key.startsWith('--')) {
        // 正文页调试
        final url = key.substring(2);
        await _debugContent(source, url);
      } else {
        // 搜索调试
        await _debugSearch(source, key);
      }
    } catch (e) {
      onMessage?.call(-1, '调试出错: $e');
    }
  }

  bool _isUrl(String str) {
    return str.startsWith('http://') || str.startsWith('https://');
  }

  /// 调试搜索
  Future<void> _debugSearch(BookSource source, String keyword) async {
    onMessage?.call(1, '开始解析搜索页');

    try {
      if (source.searchUrl == null || source.ruleSearch == null) {
        onMessage?.call(-1, '搜索URL或规则为空');
        return;
      }

      // 构建搜索URL
      final searchUrl =
          source.searchUrl!.replaceAll('{{key}}', Uri.encodeComponent(keyword));
      final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, searchUrl);

      // 发送请求
      final response = await _networkService.get(
        fullUrl,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);
      _searchSrc = html;
      onMessage?.call(10, html); // 保存搜索页HTML

      // 解析搜索结果
      final results = await RuleParser.parseSearchRule(
        html,
        source.ruleSearch!,
        variables: {'keyword': keyword},
        baseUrl: source.bookSourceUrl,
      );

      onMessage?.call(1, '搜索页解析完成，找到 ${results.length} 个结果');

      if (results.isNotEmpty) {
        // 继续调试第一个结果的详情页
        final firstResult = results.first;
        final bookUrl = firstResult['bookUrl'];
        if (bookUrl != null && bookUrl.isNotEmpty) {
          final fullBookUrl =
              NetworkService.joinUrl(source.bookSourceUrl, bookUrl);
          await _debugBookInfo(source, fullBookUrl);
        }
      } else {
        onMessage?.call(1000, '未获取到书籍');
      }
    } catch (e) {
      onMessage?.call(-1, '搜索调试失败: $e');
    }
  }

  /// 调试发现
  Future<void> _debugExplore(BookSource source, String url) async {
    onMessage?.call(1, '开始解析发现页');

    try {
      // 解析发现书籍
      final books = await _exploreService.exploreBooks(source, url, page: 1);

      onMessage?.call(1, '发现页解析完成，找到 ${books.length} 个结果');

      if (books.isNotEmpty) {
        // 继续调试第一个结果的详情页
        final firstBook = books.first;
        final bookUrl = firstBook['bookUrl'];
        if (bookUrl != null && bookUrl.isNotEmpty) {
          final fullBookUrl =
              NetworkService.joinUrl(source.bookSourceUrl, bookUrl);
          await _debugBookInfo(source, fullBookUrl);
        }
      } else {
        onMessage?.call(1000, '未获取到书籍');
      }
    } catch (e) {
      onMessage?.call(-1, '发现调试失败: $e');
    }
  }

  /// 调试详情页
  Future<void> _debugBookInfo(BookSource source, String bookUrl) async {
    onMessage?.call(1, '开始解析详情页');

    try {
      // 发送请求
      final response = await _networkService.get(
        bookUrl,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);
      _bookSrc = html;
      onMessage?.call(20, html); // 保存详情页HTML

      if (source.ruleBookInfo == null) {
        onMessage?.call(1000, '详情规则为空');
        return;
      }

      // 创建临时Book对象
      final book = Book(
        bookUrl: bookUrl,
        origin: source.bookSourceUrl,
        originName: source.bookSourceName,
      );

      // 解析书籍信息
      final bookInfo = await _bookService.getBookInfo(book);

      onMessage?.call(1, '详情页解析完成');
      onMessage?.call(1, '书名: ${bookInfo?.name ?? "未获取"}');
      onMessage?.call(1, '作者: ${bookInfo?.author ?? "未获取"}');

      if (bookInfo != null && bookInfo.tocUrl.isNotEmpty) {
        // 有目录URL，直接调试目录
        await _debugToc(source, bookInfo.tocUrl, bookInfo);
      } else if (bookInfo != null) {
        // 没有目录URL，使用bookUrl调试目录
        await _debugToc(source, bookInfo.bookUrl, bookInfo);
      }
    } catch (e) {
      onMessage?.call(-1, '详情调试失败: $e');
    }
  }

  /// 调试目录页
  Future<void> _debugToc(BookSource source, String tocUrl, [Book? book]) async {
    onMessage?.call(1, '开始解析目录页');

    try {
      final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, tocUrl);

      // 发送请求
      final response = await _networkService.get(
        fullUrl,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);
      _tocSrc = html;
      onMessage?.call(30, html); // 保存目录页HTML

      if (source.ruleToc == null) {
        onMessage?.call(1000, '目录规则为空');
        return;
      }

      // 创建临时Book对象
      final bookObj = book ??
          Book(
            bookUrl: tocUrl,
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            tocUrl: tocUrl,
          );

      // 解析章节列表
      final chapters = await _bookService.getChapterList(bookObj);

      onMessage?.call(1, '目录页解析完成，找到 ${chapters.length} 个章节');

      if (chapters.isNotEmpty) {
        // 调试第一个章节的正文
        final firstChapter = chapters.first;
        await _debugContent(source, firstChapter.url, bookObj, firstChapter);
      } else {
        onMessage?.call(1000, '未获取到章节');
      }
    } catch (e) {
      onMessage?.call(-1, '目录调试失败: $e');
    }
  }

  /// 调试正文页
  Future<void> _debugContent(
    BookSource source,
    String contentUrl, [
    Book? book,
    BookChapter? chapter,
  ]) async {
    onMessage?.call(1, '开始解析正文页');

    try {
      final fullUrl = NetworkService.joinUrl(source.bookSourceUrl, contentUrl);

      // 发送请求
      final response = await _networkService.get(
        fullUrl,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);
      _contentSrc = html;
      onMessage?.call(40, html); // 保存正文页HTML

      if (source.ruleContent == null) {
        onMessage?.call(1000, '正文规则为空');
        return;
      }

      // 解析正文内容
      final content = await RuleParser.parseContentRule(
        html,
        source.ruleContent!,
        baseUrl: source.bookSourceUrl,
      );

      if (content != null && content.isNotEmpty) {
        final preview =
            content.length > 200 ? '${content.substring(0, 200)}...' : content;
        onMessage?.call(1, '正文页解析完成');
        onMessage?.call(1, '正文预览: $preview');
        onMessage?.call(1000, '调试完成');
      } else {
        onMessage?.call(-1, '未获取到正文内容');
      }
    } catch (e) {
      onMessage?.call(-1, '正文调试失败: $e');
    }
  }

  /// 获取HTML源码
  String? getSearchSrc() => _searchSrc;
  String? getBookSrc() => _bookSrc;
  String? getTocSrc() => _tocSrc;
  String? getContentSrc() => _contentSrc;

  /// 清除调试数据
  void clear() {
    _searchSrc = null;
    _bookSrc = null;
    _tocSrc = null;
    _contentSrc = null;
    onMessage = null;
  }
}
