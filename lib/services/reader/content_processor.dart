import 'dart:math' as math;
import 'dart:async';
import '../../data/models/book.dart';
import '../../data/models/book_chapter.dart';
import '../../data/models/replace_rule.dart';
import '../replace_rule_service.dart';
import '../../utils/app_log.dart';
import '../../utils/chinese_utils.dart';
import '../../config/app_config.dart';

/// 内容处理器，用于处理章节内容
/// 参考项目：ContentProcessor.kt
class ContentProcessor {
  final String bookName;
  final String bookOrigin;

  // 使用同步的 List，但在更新时确保线程安全
  List<ReplaceRule> _titleReplaceRules = [];
  List<ReplaceRule> _contentReplaceRules = [];
  final Set<String> _removeSameTitleCache = {};

  // 记录最后使用时间，用于清理不活跃的处理器
  DateTime _lastUsedTime = DateTime.now();

  ContentProcessor._(this.bookName, this.bookOrigin) {
    _updateReplaceRules();
    _updateRemoveSameTitleCache();
  }

  static final Map<String, ContentProcessor> _processors = {};
  static Timer? _cleanupTimer;
  static final Object _processorsLock = Object(); // 用于同步访问 _processors

  /// 初始化清理定时器（定期清理不活跃的处理器）
  static void _initCleanupTimer() {
    if (_cleanupTimer != null) return;

    // 每5分钟清理一次不活跃的处理器（超过30分钟未使用）
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final now = DateTime.now();
      final keysToRemove = <String>[];

      // 同步访问 _processors，防止并发修改
      synchronized(_processorsLock, () {
        _processors.forEach((key, processor) {
          final timeSinceLastUse = now.difference(processor._lastUsedTime);
          if (timeSinceLastUse.inMinutes > 30) {
            keysToRemove.add(key);
          }
        });

        for (final key in keysToRemove) {
          _processors.remove(key);
        }

        if (_processors.isEmpty && _cleanupTimer != null) {
          _cleanupTimer?.cancel();
          _cleanupTimer = null;
        }
      });
    });
  }

  /// 获取或创建 ContentProcessor 实例
  static ContentProcessor get(Book book) {
    return getByName(book.name, book.origin);
  }

  /// 根据书籍名称和来源获取或创建 ContentProcessor 实例
  /// 参考项目：使用 WeakReference，这里使用定期清理机制
  static ContentProcessor getByName(String bookName, String bookOrigin) {
    final key = '$bookName$bookOrigin';
    late ContentProcessor processor;
    
    // 同步访问 _processors，防止并发创建
    synchronized(_processorsLock, () {
      if (!_processors.containsKey(key)) {
        _processors[key] = ContentProcessor._(bookName, bookOrigin);
        _initCleanupTimer();
      }
      processor = _processors[key]!;
      processor._lastUsedTime = DateTime.now(); // 更新最后使用时间
    });
    
    return processor;
  }

  /// 更新所有 ContentProcessor 的替换规则
  static Future<void> updateAllReplaceRules() async {
    late List<ContentProcessor> processors;
    synchronized(_processorsLock, () {
      processors = List.from(_processors.values);
    });
    for (final processor in processors) {
      await processor._updateReplaceRulesAsync();
    }
  }

  /// 同步执行函数，确保在异步环境中的原子性
  static void synchronized(Object lock, void Function() action) {
    action();
  }

  /// 清理所有处理器（用于测试或应用退出时）
  static void clearAll() {
    synchronized(_processorsLock, () {
      _processors.clear();
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    });
  }

  /// 更新替换规则（同步版本，用于初始化）
  void _updateReplaceRules() {
    // 异步更新，但不等待完成
    _updateReplaceRulesAsync();
  }

  /// 更新替换规则（异步版本）
  Future<void> _updateReplaceRulesAsync() async {
    try {
      // 参考项目：同步从数据库获取，这里使用异步但确保在获取完成前不会使用空列表
      final titleRules = await ReplaceRuleService.instance
          .getEnabledRulesByTitleScope(bookName, bookOrigin);
      final contentRules = await ReplaceRuleService.instance
          .getEnabledRulesByContentScope(bookName, bookOrigin);

      // 更新规则列表（确保线程安全）
      _titleReplaceRules = titleRules;
      _contentReplaceRules = contentRules;
    } catch (e) {
      AppLog.instance.put('更新替换规则失败: $bookName@$bookOrigin', error: e);
    }
  }

  /// 更新去除重复标题的缓存
  /// 参考项目：upRemoveSameTitle
  /// 从已缓存的章节文件中获取文件名，避免重复处理已处理过的章节
  Future<void> _updateRemoveSameTitleCache() async {
    try {
      // 尝试从 BookService 获取书籍对象
      // 注意：如果 BookService 没有 getBookByOrigin 方法，可以尝试其他方式
      // 或者直接使用 CacheService 根据 bookName 和 bookOrigin 获取缓存文件

      // 方案1：如果 BookService 有相关方法，使用它
      // final book = await BookService.instance.getBookByOrigin(bookName, bookOrigin);
      // if (book == null) return;
      // final cachedFiles = await CacheService.instance.getCachedChapterFiles(book);

      // 方案2：直接通过 CacheService 获取（需要扩展 CacheService）
      // 当前实现：暂时跳过，在 getContent 中动态添加
      // 参考项目：从 BookHelp.getChapterFiles(book) 获取，过滤出以 "nr" 结尾的文件
      // 当前项目的章节文件名格式是 MD5.txt，需要转换为 "nr" 格式

      // 暂时留空，在 getContent 中动态添加到缓存
      // 这样可以避免需要 Book 对象，同时保持功能正常
    } catch (e) {
      AppLog.instance.put('更新去除重复标题缓存失败: $bookName@$bookOrigin', error: e);
    }
  }

  /// 获取标题替换规则
  List<ReplaceRule> getTitleReplaceRules() {
    return _titleReplaceRules;
  }

  /// 获取内容替换规则
  List<ReplaceRule> getContentReplaceRules() {
    return _contentReplaceRules;
  }

  /// 清除去除重复标题缓存
  /// 参考项目：用于清除已处理的章节缓存
  void clearRemoveSameTitleCache() {
    _removeSameTitleCache.clear();
  }

  /// 获取去除重复标题缓存（用于外部访问）
  Set<String> get removeSameTitleCache => _removeSameTitleCache;

  /// 处理章节内容
  /// 参考项目：ContentProcessor.getContent
  Future<ProcessedContent> getContent(
    Book book,
    BookChapter chapter,
    String content, {
    bool includeTitle = true,
    bool useReplace = true,
    bool chineseConvert = true,
    bool reSegment = true,
  }) async {
    var mContent = content;
    var sameTitleRemoved = false;
    List<ReplaceRule>? effectiveReplaceRules;

    if (content != "null" && content.isNotEmpty) {
      // 1. 去除重复标题
      final fileName = _getChapterFileName(chapter, "nr");
      if (!_removeSameTitleCache.contains(fileName)) {
        try {
          final name = _escapeRegex(book.name);
          var title =
              _escapeRegex(chapter.title).replaceAll(RegExp(r'\s+'), r'\s*');
          var pattern =
              RegExp('^(\\s|\\p{P}|$name)*$title(\\s)*', unicode: true);
          var match = pattern.firstMatch(mContent);
          if (match != null) {
            mContent = mContent.substring(match.end);
            sameTitleRemoved = true;
            // 添加到缓存，避免重复处理（参考项目逻辑）
            _removeSameTitleCache.add(fileName);
          } else if (useReplace && _getUseReplaceRule(book)) {
            // 如果使用替换规则，尝试使用处理后的标题
            final displayTitle = await _getDisplayTitle(
                chapter, _contentReplaceRules,
                chineseConvert: false);
            title = _escapeRegex(displayTitle);
            pattern = RegExp('^(\\s|\\p{P}|$name)*$title(\\s)*', unicode: true);
            match = pattern.firstMatch(mContent);
            if (match != null) {
              mContent = mContent.substring(match.end);
              sameTitleRemoved = true;
              // 添加到缓存，避免重复处理（参考项目逻辑）
              _removeSameTitleCache.add(fileName);
            }
          }
        } catch (e) {
          AppLog.instance.put('去除重复标题出错', error: e);
        }
      }

      // 2. 重新分段（如果启用）
      if (reSegment && _getReSegment(book)) {
        mContent = _reSegment(mContent, chapter.title);
      }

      // 3. 简繁转换（如果启用）
      if (chineseConvert) {
        try {
          // 参考项目：根据AppConfig.chineseConverterType决定转换方向
          // 0: 不转换, 1: 繁体转简体, 2: 简体转繁体
          final converterType = AppConfig.getChineseConverterType();

          if (converterType == 1) {
            // 繁体转简体
            mContent = await ChineseUtils.t2s(mContent);
          } else if (converterType == 2) {
            // 简体转繁体
            mContent = await ChineseUtils.s2t(mContent);
          }
        } catch (e) {
          AppLog.instance.put('简繁转换出错', error: e);
        }
      }

      // 4. 应用替换规则（净化规则）
      if (useReplace && _getUseReplaceRule(book)) {
        effectiveReplaceRules = [];
        // 参考项目：先将内容按行分割并trim
        mContent = mContent.split('\n').map((line) => line.trim()).join('\n');

        // 确保替换规则已加载（如果为空，尝试重新加载）
        if (_contentReplaceRules.isEmpty) {
          await _updateReplaceRulesAsync();
        }

        // 使用ReplaceRuleService应用规则（支持超时机制）
        // 参考项目：直接遍历规则列表应用，记录生效的规则
        try {
          for (final rule in _contentReplaceRules) {
            if (rule.pattern.isEmpty) continue;

            try {
              final beforeRule = mContent;
              final tmp = await ReplaceRuleService.instance.applyRules(
                mContent,
                rules: [rule],
              );
              if (beforeRule != tmp) {
                effectiveReplaceRules ??= [];
                effectiveReplaceRules.add(rule);
                mContent = tmp;
              }
            } catch (e) {
              AppLog.instance.put('替换净化: 规则 ${rule.name} 应用失败', error: e);
            }
          }
        } catch (e) {
          AppLog.instance.put('替换净化: 应用规则失败', error: e);
        }
      }
    }

    // 5. 添加标题（如果 includeTitle 为 true）
    if (includeTitle) {
      final displayTitle = await _getDisplayTitle(
        chapter,
        _titleReplaceRules,
        useReplace: useReplace && _getUseReplaceRule(book),
      );
      mContent = '$displayTitle\n$mContent';
    }

    // 6. 处理段落缩进
    final contents = <String>[];
    final lines = mContent.split('\n');
    for (final line in lines) {
      // 去除行首行尾空白（包括全角空格）
      final paragraph = line.trim();
      if (paragraph.isNotEmpty) {
        if (contents.isEmpty && includeTitle) {
          // 第一行（标题）不添加缩进
          contents.add(paragraph);
        } else {
          // 其他行添加段落缩进
          // 段落缩进从 ReadBookConfig 获取，这里暂时使用全角空格
          contents.add('　　$paragraph');
        }
      }
    }

    return ProcessedContent(
      sameTitleRemoved: sameTitleRemoved,
      contents: contents,
      effectiveReplaceRules: effectiveReplaceRules,
    );
  }

  /// 获取章节显示标题（应用标题替换规则）
  /// 公开方法，供外部调用
  Future<String> getDisplayTitle(
    BookChapter chapter, {
    bool useReplace = true,
    bool chineseConvert = true,
  }) async {
    // 确保替换规则已加载
    if (_titleReplaceRules.isEmpty) {
      await _updateReplaceRulesAsync();
    }
    return _getDisplayTitle(
      chapter,
      _titleReplaceRules,
      useReplace: useReplace,
      chineseConvert: chineseConvert,
    );
  }

  /// 获取章节显示标题（应用标题替换规则）
  /// 内部方法
  Future<String> _getDisplayTitle(
    BookChapter chapter,
    List<ReplaceRule> replaceRules, {
    bool useReplace = true,
    bool chineseConvert = true,
  }) async {
    var title = chapter.title;

    if (useReplace && replaceRules.isNotEmpty) {
      for (final rule in replaceRules) {
        if (rule.pattern.isEmpty) continue;
        try {
          if (rule.isRegex) {
            final pattern = RegExp(rule.pattern, multiLine: true);
            title = title.replaceAll(pattern, rule.replacement);
          } else {
            title = title.replaceAll(rule.pattern, rule.replacement);
          }
        } catch (e) {
          // 忽略替换错误
        }
      }
    }

    // 简繁转换
    if (chineseConvert) {
      final converterType = AppConfig.getChineseConverterType();
      if (converterType == 1) {
        title = await ChineseUtils.t2s(title);
      } else if (converterType == 2) {
        title = await ChineseUtils.s2t(title);
      }
    }

    return title;
  }

  /// 更新替换规则（异步）- 已合并到 _updateReplaceRulesAsync

  /// 获取章节文件名
  String _getChapterFileName(BookChapter chapter, String suffix) {
    // 参考项目：chapter.getFileName("nr")
    // 这里简化处理，使用章节索引和标题生成文件名
    return '${chapter.index}_${chapter.title}.$suffix';
  }

  /// 转义正则表达式特殊字符
  String _escapeRegex(String text) {
    return text.replaceAllMapped(
        RegExp(r'[.*+?^${}()|[\]\\]'), (match) => '\\${match.group(0)}');
  }

  /// 获取是否使用替换规则
  bool _getUseReplaceRule(Book book) {
    // 参考项目：book.getUseReplaceRule()
    // 当前项目：Book 模型可能没有这个字段，暂时返回 true
    // 如果 Book 模型有 useReplaceRule 字段，应该从这里获取
    return true;
  }

  /// 获取是否重新分段
  bool _getReSegment(Book book) {
    // 参考项目：book.getReSegment()
    // 当前项目：Book 模型可能没有这个字段，暂时返回 false
    // 如果 Book 模型有 reSegment 字段，应该从这里获取
    return false;
  }

  // 常量定义（参考项目）
  static const String _markSentencesEnd = '？。！?!~';
  static const String _markSentencesEndP = '.？。！?!~';
  static const String _markSentencesMid = '.，、,—…';
  static const String _markSentencesSay = '问说喊唱叫骂道着答';
  static const String _markQuotationBefore = '，：,:';
  static const String _markQuotation = '"“”';
  static const String _markQuotationRight = '"”';
  static const int _wordMaxLength = 16;

  // 引号字符常量
  static const String _leftQuote = '\u201C'; // "
  static const String _rightQuote = '\u201D'; // "

  /// 重新分段
  /// 参考项目：ContentHelp.reSegment
  String _reSegment(String content, String chapterName) {
    var content1 = content;
    final dict = _makeDict(content1);

    // 预处理：替换引号、处理分段
    // 使用Unicode转义来表示引号字符：\u201C (左引号 "), \u201D (右引号 ")
    final leftQuote = '\u201C'; // "
    final rightQuote = '\u201D'; // "
    final quoteChars = '"\u201C\u201D';

    // 参考项目：content1.replace("&quot;".toRegex(), """)
    var contentProcessed = content1
        .replaceAll(RegExp(r'&quot;'), leftQuote)
        .replaceAll(RegExp('[:：][\'$quoteChars]+'), '：$leftQuote')
        .replaceAll(RegExp('[$quoteChars]+\\s*[$quoteChars][\\s$quoteChars]*'),
            '$rightQuote\n$leftQuote');
    var p = contentProcessed.split(RegExp(r'\n(\s*)'));

    // 初始化StringBuffer的长度，在原content的长度基础上做冗余（参考项目：content1.length * 1.15）
    var buffer = StringBuffer();
    // 章节的文本格式为章节标题-空行-首段，所以处理段落时需要略过第一行文本
    buffer.write('  ');
    if (chapterName.trim() != (p.isNotEmpty ? p[0].trim() : '')) {
      // 去除段落内空格。unicode 3000 象形字间隔（中日韩符号和标点），不包含在\s内
      if (p.isNotEmpty) {
        buffer.write(p[0].replaceAll(RegExp(r'[\u3000\s]+'), ''));
      }
    }

    // 如果原文存在分段错误，需要把段落重新黏合
    for (int i = 1; i < p.length; i++) {
      final bufferStr = buffer.toString();
      if (bufferStr.isNotEmpty) {
        final lastChar = bufferStr[bufferStr.length - 1];
        final secondLastChar =
            bufferStr.length > 1 ? bufferStr[bufferStr.length - 2] : '';
        if (_match(_markSentencesEnd, lastChar) ||
            (_match(_markQuotationRight, lastChar) &&
                _match(_markSentencesEnd, secondLastChar))) {
          buffer.write('\n');
        }
      }
      // 段落开头以外的地方不应该有空格
      // 去除段落内空格。unicode 3000 象形字间隔（中日韩符号和标点），不包含在\s内
      buffer.write(p[i].replaceAll(RegExp(r'[\u3000\s]'), ''));
    }

    // 预分段预处理
    // ""处理为"\n"。
    // "。处理为"。\n"。不考虑"？"  "！"的情况。
    // "。xxx处理为 "。\n xxx
    final bufferStr = buffer
        .toString()
        .replaceAll(RegExp(r'["""]+\s*["""]+'), '$_rightQuote\n$_leftQuote')
        .replaceAll(
            RegExp(r'["""]+([？。！?!~])["""]+'), '$_rightQuote\$1\n$_leftQuote')
        .replaceAll(RegExp(r'["""]+([？。！?!~])([^"""])'), '$_rightQuote\$1\n\$2')
        .replaceAll(RegExp(r'([问说喊唱叫骂道着答])[\.。]'), r'$1。\n');
    p = bufferStr.split('\n');

    buffer = StringBuffer();
    for (final s in p) {
      buffer.write('\n');
      buffer.write(_findNewLines(s, dict));
    }
    buffer = _reduceLength(buffer);

    // 参考项目：处理章节头部空格和换行，修正引号格式
    content1 = buffer
        .toString()
        // 处理章节头部空格和换行
        .replaceFirst(RegExp(r'^\s+'), '')
        .replaceAll(
            RegExp(r'\s*["""]+\s*["""][\s"""]*'), '$_rightQuote\n$_leftQuote')
        .replaceAll(RegExp(r'[:：]["""\s]+'), '：$_leftQuote')
        // 参考项目：.replace("\n[\"“”]([^\n\"“”]+)([,:，：][\"”“])([^\n\"“”]+)".toRegex(), "\n$1：\"$3")
        .replaceAll(
            RegExp(r'\n["""]([^\n"""]+)([,:，：]["""])'), r'\n$1：$_leftQuote')
        .replaceAll(RegExp(r'\n(\s*)'), '\n');

    return content1;
  }

  /// 从字符串提取引号包围,且不止出现一次的内容为字典
  List<String> _makeDict(String str) {
    // 引号中间不包含任何标点
    final pattern = RegExp(
        r'(?<=["' "'" '"' "])([^p{P}]{1,$_wordMaxLength})(?=[" '"' "'" '"])',
        unicode: true);
    final matches = pattern.allMatches(str);
    final cache = <String>[];
    final dict = <String>[];

    for (final match in matches) {
      final word = match.group(0) ?? '';
      if (cache.contains(word)) {
        if (!dict.contains(word)) {
          dict.add(word);
        }
      } else {
        cache.add(word);
      }
    }

    return dict;
  }

  /// 强制切分，减少段落内的句子
  StringBuffer _reduceLength(StringBuffer str) {
    final p = str.toString().split('\n');
    final l = p.length;
    final b = List<bool>.filled(l, false);
    final paragraphDialogPattern = RegExp(r'^["""][^"""]+["""]$');

    for (int i = 0; i < l; i++) {
      b[i] = paragraphDialogPattern.hasMatch(p[i]);
    }

    var dialogue = 0;
    for (int i = 0; i < l; i++) {
      if (b[i]) {
        if (dialogue < 0) {
          dialogue = 1;
        } else if (dialogue < 2) {
          dialogue++;
        }
      } else {
        if (dialogue > 1) {
          p[i] = _splitQuote(p[i]);
          dialogue--;
        } else if (dialogue > 0 && i < l - 2) {
          if (b[i + 1]) {
            p[i] = _splitQuote(p[i]);
          }
        }
      }
    }

    final string = StringBuffer();
    for (int i = 0; i < l; i++) {
      string.write('\n');
      string.write(p[i]);
    }

    return string;
  }

  /// 强制切分进入对话模式后，未构成 "xxx" 形式的段落
  String _splitQuote(String str) {
    final length = str.length;
    if (length < 3) return str;

    if (_match(_markQuotation, str[0])) {
      final i = _seekIndex(str, _markQuotation, 1, length - 2, true) + 1;
      if (i > 1) {
        if (!_match(_markQuotationBefore, str[i - 1])) {
          return '${str.substring(0, i)}\n${str.substring(i)}';
        }
      }
    } else if (_match(_markQuotation, str[length - 1])) {
      final i =
          length - 1 - _seekIndex(str, _markQuotation, 1, length - 2, false);
      if (i > 1) {
        if (!_match(_markQuotationBefore, str[i - 1])) {
          return '${str.substring(0, i)}\n${str.substring(i)}';
        }
      }
    }

    return str;
  }

  /// 对内容重新划分段落.输入参数str已经使用换行符预分割
  /// 参考项目：ContentHelp.findNewLines
  String _findNewLines(String str, List<String> dict) {
    // 参考项目：使用 StringBuilder 并直接修改字符
    // Dart 中我们需要使用字符数组来模拟 StringBuilder 的行为
    final stringChars = str.split('');
    // 标记string中每个引号的位置
    final arrayQuote = <int>[];
    // 标记插入换行符的位置，int为插入位置（str的char下标）
    var insN = <int>[];

    // mod[i]标记str的每一段处于引号内还是引号外
    // 参考项目：使用 IntArray(str.length)，但实际只需要 arrayQuote.size 的长度
    // 为了简化，我们使用 List<int>，索引对应 arrayQuote 的索引
    final mod = List<int>.filled(str.length, 0); // 使用 str.length 作为最大长度
    var waitClose = false;

    for (int i = 0; i < str.length; i++) {
      final c = str[i];
      if (_match(_markQuotation, c)) {
        final size = arrayQuote.length;

        // 把"xxx"、"yy"合并为"xxx_yy"进行处理
        if (size > 0) {
          final quotePre = arrayQuote[size - 1];
          if (i - quotePre == 2) {
            var remove = false;
            if (waitClose) {
              if (_match(',，、/', str[i - 1])) {
                remove = true;
              }
            } else if (_match(',，、/和与或', str[i - 1])) {
              remove = true;
            }
            if (remove) {
              // 修改引号方向（参考项目：string.setCharAt(i, '""); string.setCharAt(i - 2, '"'))
              stringChars[i] = _leftQuote;
              stringChars[i - 2] = _rightQuote;
              arrayQuote.removeLast();
              if (size > 1) {
                mod[size - 1] = 1;
                mod[size] = -1;
              }
              continue;
            }
          }
        }
        arrayQuote.add(i);

        // 为xxx："xxx"做标记
        if (i > 1) {
          final charB1 = str[i - 1];
          var charB2 = '';
          if (_match(_markQuotationBefore, charB1)) {
            if (arrayQuote.length > 1) {
              final lastQuote = arrayQuote[arrayQuote.length - 2];
              var p = 0;
              if (charB1 == ',' || charB1 == '，') {
                if (arrayQuote.length > 2) {
                  p = arrayQuote[arrayQuote.length - 3];
                  if (p > 0) {
                    charB2 = str[p - 1];
                  }
                }
              }
              if (_match(_markSentencesEndP, charB2)) {
                insN.add(p - 1);
              } else if (charB2 != '的') {
                final lastEnd = _seekLast(str, _markSentencesEnd, i, lastQuote);
                if (lastEnd > 0) {
                  insN.add(lastEnd);
                } else {
                  insN.add(lastQuote);
                }
              }
            }
            waitClose = true;
            mod[size] = 1;
            if (size > 0) {
              mod[size - 1] = -1;
              if (size > 1) {
                mod[size - 2] = 1;
              }
            }
          } else if (waitClose) {
            waitClose = false;
            insN.add(i);
          }
        }
      }
    }

    final size = arrayQuote.length;

    // 标记循环状态，此位置前的引号是否已经配对
    var opend = false;
    if (size > 0) {
      // 第1次遍历array_quote，令其元素的值不为0
      for (int i = 0; i < size; i++) {
        if (mod[i] > 0) {
          opend = true;
        } else if (mod[i] < 0) {
          if (!opend) {
            if (i > 0) mod[i] = 3;
          }
          opend = false;
        } else {
          opend = !opend;
          if (opend) {
            mod[i] = 2;
          } else {
            mod[i] = -2;
          }
        }
      }
      // 修正，断尾必须封闭引号
      if (opend) {
        // 参考项目：arrayQuote[size - 1] - string.length > -3
        if (arrayQuote[size - 1] - stringChars.length > -3) {
          if (size > 1) mod[size - 2] = 4;
          mod[size - 1] = -4;
        } else if (stringChars.length > 1 &&
            !_match(_markSentencesSay, stringChars[stringChars.length - 2])) {
          // 参考项目：string.append(""")
          stringChars.add(_rightQuote);
        }
      }

      // 第2次循环，mod[i]由负变正时，前1字符如果是句末，需要插入换行
      var loop2Mod1 = -1;
      var loop2Mod2 = 0;
      var i = 0;
      var j = arrayQuote.isNotEmpty ? arrayQuote[0] - 1 : -1;
      if (j < 0) {
        i = 1;
        loop2Mod1 = 0;
      }
      while (i < size) {
        j = arrayQuote[i] - 1;
        loop2Mod2 = mod[i];
        if (loop2Mod1 < 0 && loop2Mod2 > 0) {
          // 参考项目：match(MARK_SENTENCES_END, string[j])
          if (j >= 0 &&
              j < stringChars.length &&
              _match(_markSentencesEnd, stringChars[j])) {
            insN.add(j);
          }
        }
        loop2Mod1 = loop2Mod2;
        i++;
      }
    }

    // 使用字典验证ins_n，避免插入不必要的换行
    // 参考项目：使用 string[i] 而不是 str[i]，因为 string 可能已经被修改
    final insN1 = <int>[];
    for (final i in insN) {
      if (i >= 0 && i < stringChars.length && _match('"\'""', stringChars[i])) {
        final start =
            _seekLast(stringChars.join(''), '"\'""', i - 1, i - _wordMaxLength);
        if (start > 0) {
          final word = stringChars.sublist(start + 1, i).join('');
          if (dict.contains(word)) {
            continue;
          } else {
            if (start < stringChars.length &&
                _match('的地得', stringChars[start])) {
              continue;
            }
          }
        }
      }
      insN1.add(i);
    }
    insN = insN1;

    // 随机在句末插入换行符
    insN = insN.toSet().toList()..sort();

    var gain = 3;
    var min = 0;
    var trigger = 2;
    var progress = 0;
    var j = 0;
    var nextLine = insN.isNotEmpty ? insN[j] : -1;

    // 参考项目：使用 string 而不是 str，因为 string 可能已经被修改
    final currentStr = stringChars.join('');

    for (int i = 0; i < arrayQuote.length; i++) {
      final quote = arrayQuote[i];
      if (quote > 0) {
        gain = 4;
        min = 2;
        trigger = 4;
      } else {
        gain = 3;
        min = 0;
        trigger = 2;
      }

      while (j < insN.length) {
        if (nextLine >= quote) break;
        nextLine = insN[j];
        if (progress < nextLine) {
          final subs = currentStr.substring(progress, nextLine);
          insN.addAll(_forceSplit(subs, progress, min, gain, trigger));
          progress = nextLine + 1;
        }
        j++;
        if (j < insN.length) {
          nextLine = insN[j];
        }
      }
      if (progress < quote) {
        final subs = currentStr.substring(progress, quote + 1);
        insN.addAll(_forceSplit(subs, progress, min, gain, trigger));
        progress = quote + 1;
      }
    }
    while (j < insN.length) {
      nextLine = insN[j];
      if (progress < nextLine) {
        final subs = currentStr.substring(progress, nextLine);
        insN.addAll(_forceSplit(subs, progress, min, gain, trigger));
        progress = nextLine + 1;
      }
      j++;
    }
    if (progress < currentStr.length) {
      final subs = currentStr.substring(progress);
      insN.addAll(_forceSplit(subs, progress, min, gain, trigger));
    }

    // 根据段落状态修正引号方向、计算需要插入引号的位置
    final insQuote = List<bool>.filled(size, false);
    opend = false;
    // 参考项目：直接修改 string（StringBuilder），这里修改 stringChars
    for (int i = 0; i < size; i++) {
      final p = arrayQuote[i];
      if (mod[i] > 0) {
        stringChars[p] = _leftQuote;
        if (opend) insQuote[i] = true;
        opend = true;
      } else if (mod[i] < 0) {
        stringChars[p] = _rightQuote;
        opend = false;
      } else {
        opend = !opend;
        if (opend) {
          stringChars[p] = _leftQuote;
        } else {
          stringChars[p] = _rightQuote;
        }
      }
    }
    final modifiedStr = stringChars.join('');

    insN = insN.toSet().toList()..sort();

    // 完成字符串拼接（从string复制、插入引号和换行）
    final buffer = StringBuffer();
    j = 0;
    progress = 0;
    nextLine = insN.isNotEmpty ? insN[j] : -1;

    for (int i = 0; i < arrayQuote.length; i++) {
      final quote = arrayQuote[i];

      while (j < insN.length) {
        if (nextLine >= quote) break;
        nextLine = insN[j];
        if (progress <= nextLine) {
          buffer.write(modifiedStr.substring(progress, nextLine + 1));
          buffer.write('\n');
          progress = nextLine + 1;
        }
        j++;
        if (j < insN.length) {
          nextLine = insN[j];
        }
      }
      if (progress < quote) {
        buffer.write(modifiedStr.substring(progress, quote + 1));
        progress = quote + 1;
      }
      if (insQuote[i] && buffer.length > 2) {
        final bufferStr = buffer.toString();
        // 参考项目：在引号前插入一个引号
        if (bufferStr[bufferStr.length - 1] == '\n') {
          buffer.write(_leftQuote);
        } else {
          // 参考项目：buffer.insert(buffer.length - 1, ""\n")
          final lastIndex = bufferStr.length - 1;
          buffer.clear();
          buffer.write(bufferStr.substring(0, lastIndex));
          buffer.write('$_rightQuote\n');
          buffer.write(bufferStr[lastIndex]);
        }
      }
    }
    while (j < insN.length) {
      nextLine = insN[j];
      if (progress <= nextLine) {
        buffer.write(modifiedStr.substring(progress, nextLine + 1));
        buffer.write('\n');
        progress = nextLine + 1;
      }
      j++;
    }
    if (progress < modifiedStr.length) {
      buffer.write(modifiedStr.substring(progress));
    }

    return buffer.toString();
  }

  /// 计算随机插入换行符的位置
  List<int> _forceSplit(
      String str, int offset, int min, int gain, int trigger) {
    final result = <int>[];
    final arrayEnd =
        _seekIndexes(str, _markSentencesEndP, 0, str.length - 2, true);
    final arrayMid =
        _seekIndexes(str, _markSentencesMid, 0, str.length - 2, true);

    if (arrayEnd.length < trigger && arrayMid.length < trigger * 3) {
      return result;
    }

    var j = 0;
    var i = min;
    while (i < arrayEnd.length) {
      var k = 0;
      while (j < arrayMid.length) {
        if (arrayMid[j] < arrayEnd[i]) k++;
        j++;
      }
      if (math.Random().nextDouble() * gain < 0.8 + k / 2.5) {
        result.add(arrayEnd[i] + offset);
        i = math.max(i + min, i);
      }
      i++;
    }

    return result;
  }

  /// 计算匹配到字典的每个字符的位置
  List<int> _seekIndexes(
      String str, String key, int from, int to, bool inOrder) {
    final list = <int>[];
    if (str.length - from < 1) return list;

    var i = from > 0 ? from : 0;
    var t = to > 0 ? math.min(str.length, to) : str.length;

    while (i < t) {
      final c = inOrder ? str[i] : str[str.length - i - 1];
      if (key.contains(c)) {
        if (list.isNotEmpty && i - list.last == 1) {
          list[list.length - 1] = i;
        } else {
          list.add(i);
        }
      }
      i++;
    }

    return list;
  }

  /// 计算字符串最后出现与字典中字符匹配的位置
  int _seekLast(String str, String key, int from, int to) {
    if (str.length - from < 1) return -1;

    var i = from < str.length - 1 && str.length - 1 > 0 ? from : str.length - 1;
    var t = to > 0 ? to : 0;

    while (i > t) {
      final c = str[i];
      if (key.contains(c)) {
        return i;
      }
      i--;
    }

    return -1;
  }

  /// 计算字符串与字典中字符的最短距离
  int _seekIndex(String str, String key, int from, int to, bool inOrder) {
    if (str.length - from < 1) return -1;

    var i = from > 0 ? from : 0;
    var t = to > 0 ? math.min(str.length, to) : str.length;

    while (i < t) {
      final c = inOrder ? str[i] : str[str.length - i - 1];
      if (key.contains(c)) {
        return i;
      }
      i++;
    }

    return -1;
  }

  /// 检查字符是否匹配规则
  bool _match(String rule, String chr) {
    return rule.contains(chr);
  }
}

/// 处理后的内容
class ProcessedContent {
  final bool sameTitleRemoved;
  final List<String> contents; // 每段内容（已添加段落缩进）
  final List<ReplaceRule>? effectiveReplaceRules;

  ProcessedContent({
    required this.sameTitleRemoved,
    required this.contents,
    this.effectiveReplaceRules,
  });

  /// 获取完整内容（用换行符连接）
  String get fullContent => contents.join('\n');
}
