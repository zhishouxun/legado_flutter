import 'dart:convert';
import 'dart:io';
import 'package:json_path/json_path.dart';
import '../../data/models/book.dart';
import '../../data/models/book_source.dart';
import '../../data/models/book_source_rule.dart';
import '../../services/book/book_service.dart';
import '../../services/source/book_source_service.dart';
import '../../services/replace_rule_service.dart';
import '../../utils/replace_analyzer.dart';
import '../../utils/app_log.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/constants/app_status.dart';

/// 旧数据导入工具
/// 参考项目：io.legado.app.help.storage.ImportOldData
///
/// 用于导入旧版本的数据格式（书架、书源、替换规则）
class ImportOldData {
  ImportOldData._();

  /// 从 URI 导入旧数据
  /// 参考项目：ImportOldData.importUri()
  ///
  /// [uri] 文件 URI 或路径
  /// 返回导入结果：{书架数量, 书源数量, 替换规则数量}
  static Future<Map<String, int>> importFromUri(String uri) async {
    final result = <String, int>{
      'books': 0,
      'sources': 0,
      'rules': 0,
    };

    try {
      // 检查是否是 content:// URI
      if (uri.startsWith('content://')) {
        // TODO: 处理 content:// URI（需要平台通道）
        AppLog.instance.put('暂不支持 content:// URI 导入');
        return result;
      }

      // 处理文件路径
      final file = File(uri);
      if (!await file.exists()) {
        AppLog.instance.put('文件不存在: $uri');
        return result;
      }

      final parentDir = file.parent;
      
      // 导入书架
      final shelfFile = File('${parentDir.path}/myBookShelf.json');
      if (await shelfFile.exists()) {
        try {
          final json = await shelfFile.readAsString();
          result['books'] = await importOldBookshelf(json);
        } catch (e) {
          AppLog.instance.put('导入书架失败', error: e);
        }
      }

      // 导入书源
      final sourceFile = File('${parentDir.path}/myBookSource.json');
      if (await sourceFile.exists()) {
        try {
          final json = await sourceFile.readAsString();
          result['sources'] = importOldSource(json);
        } catch (e) {
          AppLog.instance.put('导入书源失败', error: e);
        }
      }

      // 导入替换规则
      final ruleFile = File('${parentDir.path}/myBookReplaceRule.json');
      if (await ruleFile.exists()) {
        try {
          final json = await ruleFile.readAsString();
          result['rules'] = await importOldReplaceRule(json);
        } catch (e) {
          AppLog.instance.put('导入替换规则失败', error: e);
        }
      }
    } catch (e) {
      AppLog.instance.put('导入旧数据失败', error: e);
    }

    return result;
  }

  /// 导入旧书架数据
  /// 参考项目：ImportOldData.importOldBookshelf()
  static Future<int> importOldBookshelf(String json) async {
    try {
      final books = _fromOldBooks(json);
      for (final book in books) {
        try {
          await BookService.instance.saveBook(book);
        } catch (e) {
          AppLog.instance.put('导入书籍失败: ${book.name}', error: e);
        }
      }
      return books.length;
    } catch (e) {
      AppLog.instance.put('解析旧书架数据失败', error: e);
      return 0;
    }
  }

  /// 导入旧书源数据
  /// 参考项目：ImportOldData.importOldSource()
  static int importOldSource(String json) {
    try {
      final sources = _fromOldBookSources(json);
      for (final source in sources) {
        try {
          BookSourceService.instance.addBookSource(source);
        } catch (e) {
          AppLog.instance.put('导入书源失败: ${source.bookSourceName}', error: e);
        }
      }
      return sources.length;
    } catch (e) {
      AppLog.instance.put('解析旧书源数据失败', error: e);
      return 0;
    }
  }

  /// 导入旧替换规则数据
  /// 参考项目：ImportOldData.importOldReplaceRule()
  static Future<int> importOldReplaceRule(String json) async {
    try {
      final rules = ReplaceAnalyzer.jsonToReplaceRules(json);
      for (final rule in rules) {
        try {
          await ReplaceRuleService.instance.addOrUpdateRule(rule);
        } catch (e) {
          AppLog.instance.put('导入替换规则失败: ${rule.name}', error: e);
        }
      }
      return rules.length;
    } catch (e) {
      AppLog.instance.put('解析旧替换规则数据失败', error: e);
      return 0;
    }
  }

  /// 从旧格式解析书籍列表
  /// 参考项目：ImportOldData.fromOldBooks()
  static List<Book> _fromOldBooks(String json) {
    final books = <Book>[];
    try {
      final jsonPath = JsonPath(json);
      final items = jsonPath.read(r'$') as List<dynamic>?;
      
      if (items == null) return books;

      // 获取现有书籍 URL 列表（用于去重）
      // TODO: 异步获取现有书籍列表
      final existingBookUrls = <String>{};

      for (final item in items) {
        try {
          final itemJson = jsonEncode(item);
          final itemPath = JsonPath(itemJson);
          
          final bookUrl = itemPath.readString(r'$.noteUrl');
          if (bookUrl == null || bookUrl.isEmpty) continue;
          
          if (existingBookUrls.contains(bookUrl)) {
            AppLog.instance.put('书籍已存在: $bookUrl');
            continue;
          }

          final book = Book(
            bookUrl: bookUrl,
            name: itemPath.readString(r'$.bookInfoBean.name') ?? '',
            author: itemPath.readString(r'$.bookInfoBean.author') ?? '',
            origin: itemPath.readString(r'$.tag') ?? '',
            originName: itemPath.readString(r'$.bookInfoBean.origin') ?? '',
            intro: itemPath.readString(r'$.bookInfoBean.introduce'),
            coverUrl: itemPath.readString(r'$.bookInfoBean.coverUrl'),
            customCoverUrl: itemPath.readString(r'$.customCoverPath'),
            tocUrl: itemPath.readString(r'$.bookInfoBean.chapterUrl') ?? bookUrl,
            latestChapterTitle: itemPath.readString(r'$.lastChapterName'),
            variable: itemPath.readString(r'$.variable'),
            totalChapterNum: itemPath.readInt(r'$.chapterListSize') ?? 0,
            durChapterIndex: itemPath.readInt(r'$.durChapter') ?? 0,
            durChapterTitle: itemPath.readString(r'$.durChapterName'),
            durChapterPos: itemPath.readInt(r'$.durChapterPage') ?? 0,
            durChapterTime: itemPath.readLong(r'$.finalDate'),
            lastCheckTime: itemPath.readLong(r'$.bookInfoBean.finalRefreshData'),
            lastCheckCount: itemPath.readInt(r'$.newChapters') ?? 0,
            order: itemPath.readInt(r'$.serialNumber') ?? 0,
            canUpdate: itemPath.readBool(r'$.allowUpdate') ?? true,
          );

          // 设置书籍类型
          final origin = book.origin;
          final isLocal = origin == 'loc_book';
          final isAudio = itemPath.readString(r'$.bookInfoBean.bookSourceType') == 'AUDIO';
          
          int bookType = 0;
          if (isLocal) {
            bookType |= AppStatus.bookTypeLocal;
          }
          if (isAudio) {
            bookType |= AppStatus.bookTypeAudio;
          } else {
            bookType |= AppStatus.bookTypeText;
          }
          book.type = bookType;

          // 设置使用替换规则
          final useReplaceRule = itemPath.readBool(r'$.useReplaceRule') ?? false;
          book.readConfig?.useReplaceRule = useReplaceRule;

          books.add(book);
          existingBookUrls.add(bookUrl);
        } catch (e) {
          AppLog.instance.put('解析书籍项失败', error: e);
        }
      }
    } catch (e) {
      AppLog.instance.put('解析旧书架 JSON 失败', error: e);
    }

    return books;
  }

  /// 从旧格式解析书源列表
  /// 参考项目：ImportOldData.fromOldBookSources()
  static List<BookSource> _fromOldBookSources(String json) {
    final sources = <BookSource>[];
    try {
      final jsonPath = JsonPath(json);
      final items = jsonPath.read(r'$') as List<dynamic>?;
      
      if (items == null) return sources;

      for (final item in items) {
        try {
          final itemJson = jsonEncode(item);
          final source = _fromOldBookSource(itemJson);
          sources.add(source);
        } catch (e) {
          AppLog.instance.put('解析书源项失败', error: e);
        }
      }
    } catch (e) {
      AppLog.instance.put('解析旧书源 JSON 失败', error: e);
    }

    return sources;
  }

  /// 从旧格式解析单个书源
  /// 参考项目：ImportOldData.fromOldBookSource()
  static BookSource _fromOldBookSource(String itemJson) {
    final itemPath = JsonPath(itemJson);
    
    final bookSourceUrl = itemPath.readString(r'$.bookSourceUrl');
    if (bookSourceUrl == null || bookSourceUrl.isEmpty) {
      throw NoStackTraceException('书源URL为空');
    }

    final source = BookSource(
      bookSourceUrl: bookSourceUrl,
      bookSourceName: itemPath.readString(r'$.bookSourceName') ?? '',
      bookSourceGroup: itemPath.readString(r'$.bookSourceGroup'),
      loginUrl: itemPath.readString(r'$.loginUrl'),
      loginUi: itemPath.readString(r'$.loginUi'),
      loginCheckJs: itemPath.readString(r'$.loginCheckJs'),
      coverDecodeJs: itemPath.readString(r'$.coverDecodeJs'),
      bookSourceComment: itemPath.readString(r'$.bookSourceComment') ?? '',
      bookUrlPattern: itemPath.readString(r'$.ruleBookUrlPattern'),
      customOrder: itemPath.readInt(r'$.serialNumber') ?? 0,
      enabled: itemPath.readBool(r'$.enable') ?? true,
      bookSourceType: itemPath.readString(r'$.bookSourceType') == 'AUDIO' ? 1 : 0,
    );

    // 转换请求头（从 User-Agent 转换为 header JSON）
    // 参考项目：ImportOldData.uaToHeader()
    final userAgent = itemPath.readString(r'$.httpUserAgent');
    if (userAgent != null && userAgent.isNotEmpty) {
      // 参考项目使用 AppConst.UA_NAME 作为键名
      // 在 Flutter 中，我们使用 'User-Agent' 作为标准键名
      final headerMap = {'User-Agent': userAgent};
      source.header = jsonEncode(headerMap);
    }

    // 转换 URL 和规则
    source.searchUrl = _toNewUrl(itemPath.readString(r'$.ruleSearchUrl'));
    source.exploreUrl = _toNewUrls(itemPath.readString(r'$.ruleFindUrl'));
    
    if (source.exploreUrl == null || source.exploreUrl!.isEmpty) {
      source.enabledExplore = false;
    }

    // 转换规则对象
    source.ruleSearch = SearchRule(
      bookList: _toNewRule(itemPath.readString(r'$.ruleSearchList')),
      name: _toNewRule(itemPath.readString(r'$.ruleSearchName')),
      author: _toNewRule(itemPath.readString(r'$.ruleSearchAuthor')),
      intro: _toNewRule(itemPath.readString(r'$.ruleSearchIntroduce')),
      kind: _toNewRule(itemPath.readString(r'$.ruleSearchKind')),
      bookUrl: _toNewRule(itemPath.readString(r'$.ruleSearchNoteUrl')),
      coverUrl: _toNewRule(itemPath.readString(r'$.ruleSearchCoverUrl')),
      lastChapter: _toNewRule(itemPath.readString(r'$.ruleSearchLastChapter')),
    );

    source.ruleExplore = ExploreRule(
      bookList: _toNewRule(itemPath.readString(r'$.ruleFindList')),
      name: _toNewRule(itemPath.readString(r'$.ruleFindName')),
      author: _toNewRule(itemPath.readString(r'$.ruleFindAuthor')),
      intro: _toNewRule(itemPath.readString(r'$.ruleFindIntroduce')),
      kind: _toNewRule(itemPath.readString(r'$.ruleFindKind')),
      bookUrl: _toNewRule(itemPath.readString(r'$.ruleFindNoteUrl')),
      coverUrl: _toNewRule(itemPath.readString(r'$.ruleFindCoverUrl')),
      lastChapter: _toNewRule(itemPath.readString(r'$.ruleFindLastChapter')),
    );

    source.ruleBookInfo = BookInfoRule(
      init: _toNewRule(itemPath.readString(r'$.ruleBookInfoInit')),
      name: _toNewRule(itemPath.readString(r'$.ruleBookName')),
      author: _toNewRule(itemPath.readString(r'$.ruleBookAuthor')),
      intro: _toNewRule(itemPath.readString(r'$.ruleIntroduce')),
      kind: _toNewRule(itemPath.readString(r'$.ruleBookKind')),
      coverUrl: _toNewRule(itemPath.readString(r'$.ruleCoverUrl')),
      lastChapter: _toNewRule(itemPath.readString(r'$.ruleBookLastChapter')),
      tocUrl: _toNewRule(itemPath.readString(r'$.ruleChapterUrl')),
    );

    source.ruleToc = TocRule(
      chapterList: _toNewRule(itemPath.readString(r'$.ruleChapterList')),
      chapterName: _toNewRule(itemPath.readString(r'$.ruleChapterName')),
      chapterUrl: _toNewRule(itemPath.readString(r'$.ruleContentUrl')),
      nextTocUrl: _toNewRule(itemPath.readString(r'$.ruleChapterUrlNext')),
    );

    var content = _toNewRule(itemPath.readString(r'$.ruleBookContent')) ?? '';
    if (content.startsWith(r'$') && !content.startsWith(r'$.')) {
      content = content.substring(1);
    }

    source.ruleContent = ContentRule(
      content: content,
      replaceRegex: _toNewRule(itemPath.readString(r'$.ruleBookContentReplace')),
      nextContentUrl: _toNewRule(itemPath.readString(r'$.ruleContentUrlNext')),
    );

    return source;
  }

  /// 转换旧规则格式到新格式
  /// 参考项目：ImportOldData.toNewRule()
  static String? _toNewRule(String? oldRule) {
    if (oldRule == null || oldRule.isEmpty) return null;

    var newRule = oldRule;
    var reverse = false;
    var allinone = false;

    // 处理前缀
    if (newRule.startsWith('-')) {
      reverse = true;
      newRule = newRule.substring(1);
    }
    if (newRule.startsWith('+')) {
      allinone = true;
      newRule = newRule.substring(1);
    }

    // 检查是否需要转换
    final lowerRule = newRule.toLowerCase();
    if (!lowerRule.startsWith('@css:') &&
        !lowerRule.startsWith('@xpath:') &&
        !newRule.startsWith('//') &&
        !newRule.startsWith('##') &&
        !newRule.startsWith(':') &&
        !lowerRule.contains('@js:') &&
        !lowerRule.contains('<js>')) {
      
      // 转换 # 为 ##
      if (newRule.contains('#') && !newRule.contains('##')) {
        newRule = newRule.replaceAll('#', '##');
      }

      // 转换 | 为 ||
      if (newRule.contains('|') && !newRule.contains('||')) {
        if (newRule.contains('##')) {
          final parts = newRule.split('##');
          if (parts.isNotEmpty && parts[0].contains('|')) {
            newRule = parts[0].replaceAll('|', '||');
            for (int i = 1; i < parts.length; i++) {
              newRule += '##${parts[i]}';
            }
          }
        } else {
          newRule = newRule.replaceAll('|', '||');
        }
      }

      // 转换 & 为 &&
      if (newRule.contains('&') &&
          !newRule.contains('&&') &&
          !newRule.contains('http') &&
          !newRule.startsWith('/')) {
        newRule = newRule.replaceAll('&', '&&');
      }
    }

    // 恢复前缀
    if (allinone) {
      newRule = '+$newRule';
    }
    if (reverse) {
      newRule = '-$newRule';
    }

    return newRule;
  }

  /// 转换旧 URL 格式到新格式
  /// 参考项目：ImportOldData.toNewUrl()
  static String? _toNewUrl(String? oldUrl) {
    if (oldUrl == null || oldUrl.isEmpty) return null;

    // 如果是 JavaScript 代码，直接返回
    final lowerUrl = oldUrl.toLowerCase();
    if (lowerUrl.startsWith('<js>') || lowerUrl.startsWith('@js:')) {
      return oldUrl
          .replaceAll('=searchKey', '={{key}}')
          .replaceAll('=searchPage', '={{page}}');
    }

    // TODO: 实现完整的 URL 转换逻辑
    // 包括 Header、charset、body、method 等的转换
    // 这是一个简化版本，完整实现需要参考参考项目的逻辑

    return oldUrl;
  }

  /// 转换旧 URLs 格式到新格式
  /// 参考项目：ImportOldData.toNewUrls()
  static String? _toNewUrls(String? oldUrls) {
    if (oldUrls == null || oldUrls.isEmpty) return null;

    final lowerUrls = oldUrls.toLowerCase();
    if (lowerUrls.startsWith('@js:') || lowerUrls.startsWith('<js>')) {
      return oldUrls;
    }

    if (!oldUrls.contains('\n') && !oldUrls.contains('&&')) {
      return _toNewUrl(oldUrls);
    }

    final urls = oldUrls.split(RegExp(r'(&&|\r?\n)+'));
    return urls
        .map((url) => _toNewUrl(url)?.replaceAll(RegExp(r'\n\s*'), ''))
        .where((url) => url != null && url.isNotEmpty)
        .join('\n');
  }
}

/// JsonPath 扩展方法
extension JsonPathExtension on JsonPath {
  String? readString(String path) {
    try {
      final results = read(path);
      if (results.isEmpty) return null;
      final match = results.first;
      final value = match.value;
      return value?.toString();
    } catch (e) {
      return null;
    }
  }

  int? readInt(String path) {
    try {
      final results = read(path);
      if (results.isEmpty) return null;
      final match = results.first;
      final value = match.value;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    } catch (e) {
      return null;
    }
  }

  int readLong(String path) {
    try {
      final results = read(path);
      if (results.isEmpty) return 0;
      final match = results.first;
      final value = match.value;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    } catch (e) {
      return 0;
    }
  }

  bool? readBool(String path) {
    try {
      final results = read(path);
      if (results.isEmpty) return null;
      final match = results.first;
      final value = match.value;
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

