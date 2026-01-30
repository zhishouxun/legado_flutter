import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import '../../core/base/base_service.dart';
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';
import '../../data/models/book_source_rule.dart';
import '../../utils/parsers/html_parser.dart';
import '../../utils/js_engine.dart';
import '../../utils/js_extensions.dart';
import '../network/network_service.dart';
import '../source/book_source_service.dart';
import '../../utils/app_log.dart';

/// 漫画阅读服务
class MangaService extends BaseService {
  static final MangaService instance = MangaService._init();
  MangaService._init();

  final BookSourceService _bookSourceService = BookSourceService.instance;
  final NetworkService _networkService = NetworkService.instance;

  /// 获取章节图片列表
  /// 从章节内容中提取所有图片URL
  Future<List<String>> getChapterImages(BookChapter chapter, Book book) async {
    if (book.isLocal) {
      // 本地书籍暂不支持
      return [];
    }

    final source = await _bookSourceService.getBookSourceByUrl(book.origin);
    if (source == null || source.ruleContent == null) {
      return [];
    }

    try {
      // 发送请求
      final response = await _networkService.get(
        chapter.url,
        headers: NetworkService.parseHeaders(source.header),
        retryCount: 1,
      );

      final html = await NetworkService.getResponseText(response);

      // 提取图片URL（不清理HTML标签）
      return await _extractImageUrls(html, source.ruleContent!, source.bookSourceUrl);
    } catch (e) {
      AppLog.instance.put('获取章节图片失败: ${chapter.title}', error: e);
      return [];
    }
  }

  /// 从HTML中提取图片URL
  Future<List<String>> _extractImageUrls(String html, ContentRule rule, String baseUrl) async {
    final imageUrls = <String>[];

    try {
      if (rule.content == null || rule.content!.isEmpty) {
        return imageUrls;
      }

      // 执行网页 JavaScript（如果有）
      String processedHtml = html;
      if (rule.webJs != null && rule.webJs!.isNotEmpty) {
        try {
          // 创建 JavaScript 扩展对象
          final jsExtensions = JSExtensions(
            source: await _bookSourceService.getBookSourceByUrl(baseUrl),
            book: null,
            baseUrl: baseUrl,
          );
          
          // 执行 JavaScript 代码
          final jsResult = await JSEngine.evalJS(
            rule.webJs!,
            bindings: jsExtensions.createBindings(),
          );
          
          // 如果返回字符串，使用返回的结果
          if (jsResult is String && jsResult.isNotEmpty) {
            processedHtml = jsResult;
          }
        } catch (e) {
          AppLog.instance.put('执行漫画规则 JavaScript 失败', error: e);
          // JavaScript 执行失败，继续使用原始 HTML
        }
      }

      // 解析内容区域
      final document = html_parser.parse(processedHtml);
      String? contentHtml;

      // 使用规则提取内容区域
      html_dom.Element? contentElement;
      if (rule.content!.startsWith('//') || rule.content!.startsWith('/')) {
        // XPath 查询
        try {
          final xpathNodes = HtmlParser.selectXPath(document, rule.content!);
          if (xpathNodes.isNotEmpty) {
          // 获取第一个节点的 HTML 内容
          final nodeHtml = HtmlParser.getXPathNodeOuterHtml(xpathNodes.first);
          if (nodeHtml != null && nodeHtml.isNotEmpty) {
            // 解析为 Element
            final nodeDoc = html_parser.parse(nodeHtml);
            final firstChild = nodeDoc.body?.children.firstOrNull;
            if (firstChild is html_dom.Element) {
              contentElement = firstChild;
            }
          }
          }
        } catch (e) {
          AppLog.instance.put('XPath 查询失败，回退到 CSS 选择器', error: e);
          // XPath 失败，回退到 CSS 选择器
          contentElement = HtmlParser.selectElement(document, rule.content!);
        }
      } else {
        // CSS选择器
        contentElement = HtmlParser.selectElement(document, rule.content!);
      }
      
      if (contentElement != null) {
        // 获取元素的HTML内容（包含标签）
        contentHtml = contentElement.innerHtml;
      }

      if (contentHtml == null || contentHtml.isEmpty) {
        return imageUrls;
      }

      // 从内容中提取所有图片URL
      // 使用HTML解析器提取所有img标签
      final contentDoc = html_parser.parse(contentHtml);
      final imgElements = contentDoc.querySelectorAll('img');
      
      for (final img in imgElements) {
        // 优先使用src属性
        String? imgUrl = img.attributes['src'];
        
        // 如果没有src，尝试data-src
        if (imgUrl == null || imgUrl.isEmpty) {
          imgUrl = img.attributes['data-src'];
        }
        
        // 如果还没有，尝试data-original
        if (imgUrl == null || imgUrl.isEmpty) {
          imgUrl = img.attributes['data-original'];
        }
        
        if (imgUrl != null && imgUrl.isNotEmpty) {
          // 处理相对路径
          final fullUrl = NetworkService.joinUrl(baseUrl, imgUrl);
          if (!imageUrls.contains(fullUrl)) {
            imageUrls.add(fullUrl);
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('提取图片URL失败', error: e);
    }

    return imageUrls;
  }
}

