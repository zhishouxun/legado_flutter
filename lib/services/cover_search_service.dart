import '../core/base/base_service.dart';
import 'book/book_service.dart';
import '../utils/app_log.dart';
import '../utils/default_data.dart';
import '../services/network/network_service.dart';
import '../utils/parsers/rule_parser.dart';

/// 封面搜索结果
class CoverSearchResult {
  final String coverUrl;
  final String originName;
  final String originUrl;

  CoverSearchResult({
    required this.coverUrl,
    required this.originName,
    required this.originUrl,
  });
}

/// 封面搜索服务
class CoverSearchService extends BaseService {
  static final CoverSearchService instance = CoverSearchService._init();
  CoverSearchService._init();

  /// 获取封面规则配置
  Future<Map<String, dynamic>> _getCoverRuleConfig() async {
    return await DefaultData.instance.coverRule;
  }

  /// 搜索封面
  /// 通过搜索书籍来获取封面URL，如果配置了封面规则则使用规则搜索
  Future<List<CoverSearchResult>> searchCover(String bookName, String author) async {
    final results = <CoverSearchResult>[];
    
    try {
      // 获取封面规则配置
      final coverRuleConfig = await _getCoverRuleConfig();
      final enable = coverRuleConfig['enable'] as bool? ?? false;
      final searchUrl = coverRuleConfig['searchUrl'] as String? ?? '';
      final coverRule = coverRuleConfig['coverRule'] as String? ?? '';

      // 如果启用了封面规则且配置了搜索URL和规则，使用规则搜索
      if (enable && searchUrl.isNotEmpty && coverRule.isNotEmpty) {
        try {
          // 构建搜索URL（替换关键字）
          final keyword = '$bookName $author'.trim();
          final url = searchUrl.replaceAll('{{keyword}}', keyword);
          
          // 发送请求
          final response = await NetworkService.instance.get(
            url,
            retryCount: 1,
          );

          final html = await NetworkService.getResponseText(response);
          
          // 使用规则解析封面URL
          final coverUrls = await RuleParser.parseRuleAsync(
            html,
            coverRule,
            baseUrl: url,
          );

          if (coverUrls != null && coverUrls.isNotEmpty) {
            // 如果规则返回的是单个URL字符串，转换为列表
            final urlList = coverUrls.split('\n')
                .map((url) => url.trim())
                .where((url) => url.isNotEmpty)
                .toList();

            // 转换为CoverSearchResult
            final seenUrls = <String>{};
            for (final coverUrl in urlList) {
              if (!seenUrls.contains(coverUrl)) {
                seenUrls.add(coverUrl);
                results.add(CoverSearchResult(
                  coverUrl: coverUrl,
                  originName: '封面规则',
                  originUrl: url,
                ));
              }
            }
          }
        } catch (e) {
          AppLog.instance.put('使用封面规则搜索失败，回退到默认搜索', error: e);
          // 规则搜索失败，继续使用默认搜索
        }
      }

      // 如果规则搜索没有结果，使用默认搜索方式
      if (results.isEmpty) {
        // 搜索书籍
        final searchResults = await BookService.instance.searchBooks(bookName);
        
        // 过滤：只保留书名相同且作者匹配的书籍，并且有封面URL
        final filteredResults = searchResults.where((book) {
          if (book.name != bookName) return false;
          if (author.isNotEmpty) {
            if (!book.author.contains(author) && !author.contains(book.author)) {
              return false;
            }
          }
          // 必须有封面URL
          final coverUrl = book.coverUrl ?? book.customCoverUrl;
          return coverUrl != null && coverUrl.isNotEmpty;
        }).toList();
        
        // 转换为CoverSearchResult，去重
        final seenUrls = <String>{};
        for (final book in filteredResults) {
          final coverUrl = book.coverUrl ?? book.customCoverUrl;
          if (coverUrl != null && coverUrl.isNotEmpty && !seenUrls.contains(coverUrl)) {
            seenUrls.add(coverUrl);
            results.add(CoverSearchResult(
              coverUrl: coverUrl,
              originName: book.originName,
              originUrl: book.origin,
            ));
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('封面搜索失败', error: e);
    }
    
    return results;
  }
}

