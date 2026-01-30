/// 正文处理工具类
/// 参考项目：io.legado.app.help.book.ContentHelp
///
/// 提供正文内容处理功能，包括：
/// - 段落重排算法（修复错误分段）
/// - 引号智能处理
/// - 内容格式化
library;

import 'dart:math';

/// 正文处理工具类
class ContentHelp {
  ContentHelp._();

  // ========== 常量定义 ==========

  /// 句子结尾标点
  static const String _markSentencesEnd = '？。！?!~';
  static const String _markSentencesEndP = '.？。！?!~';

  // 以下常量暂时保留用于后续扩展
  // /// 句中标点
  // static const String _markSentencesMid = '.，、,—…';
  // /// 说话动词
  // static const String _markSentencesSay = '问说喊唱叫骂道着答';

  /// 冒号
  static const String _markQuotationBefore = '，：,:';

  /// 引号 - 使用 Unicode 字符
  static const String _markQuotation = '"\'\u201c\u201d\u2018\u2019';
  static const String _markQuotationRight = '"\u201c\u201d\u2019';

  /// 对话段落正则
  static final RegExp _paragraphDialog = RegExp(r'^["""][^"""]+["""]$');

  // /// 字典词条最大长度 - 暂时保留
  // static const int _wordMaxLength = 16;

  // ========== 主要方法 ==========

  /// 段落重排算法入口
  /// 把整篇内容输入，连接错误的分段，再把每个段落调用其他方法重新切分
  ///
  /// [content] 正文内容
  /// [chapterName] 章节标题
  /// 返回重排后的内容
  static String reSegment(String content, String chapterName) {
    var content1 = content;
    final dict = _makeDict(content1);

    // 预处理引号和分段
    var p = content1
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'''[:：]['"'"]+'''), '："')
        .replaceAll(RegExp(r'''["""]+\s*["""][\s"""]*'''), '"\n"')
        .split(RegExp(r'\n(\s*)'));

    // 初始化 StringBuilder 的长度
    final buffer = StringBuffer();
    buffer.write('  ');

    if (chapterName.trim() != (p.isNotEmpty ? p[0].trim() : '')) {
      // 去除段落内空格
      buffer.write(
          p.isNotEmpty ? p[0].replaceAll(RegExp(r'[\u3000\s]+'), '') : '');
    }

    // 如果原文存在分段错误，需要把段落重新黏合
    for (var i = 1; i < p.length; i++) {
      final bufStr = buffer.toString();
      if (bufStr.isNotEmpty) {
        final lastChar = bufStr[bufStr.length - 1];
        if (_match(_markSentencesEnd, lastChar) ||
            (_match(_markQuotationRight, lastChar) &&
                bufStr.length > 1 &&
                _match(_markSentencesEnd, bufStr[bufStr.length - 2]))) {
          buffer.write('\n');
        }
      }
      // 去除段落内空格
      buffer.write(p[i].replaceAll(RegExp(r'[\u3000\s]'), ''));
    }

    // 预分段预处理
    // 引号字符: " (U+0022), " (U+201C), " (U+201D)
    p = buffer
        .toString()
        .replaceAll(RegExp(r'["\u201c\u201d]+\s*["\u201c\u201d]+'), '"\n"')
        .replaceAll(
            RegExp(r'["\u201c\u201d]+([？。！?!~])["\u201c\u201d]+'), '"\$1\n"')
        .replaceAll(RegExp(r'["\u201c\u201d]+([？。！?!~])([^"\u201c\u201d])'),
            '"\$1\n\$2')
        .replaceAll(RegExp(r'([问说喊唱叫骂道着答])[\.。]'), '\$1。\n')
        .split('\n');

    final buffer2 = StringBuffer();
    for (final s in p) {
      buffer2.write('\n');
      buffer2.write(_findNewLines(s, dict));
    }

    final buffer3 = _reduceLength(buffer2.toString());

    // 最终处理
    content1 = buffer3
        .replaceFirst(RegExp(r'^\s+'), '')
        .replaceAll(
            RegExp(r'\s*["\u201c\u201d]+\s*["\u201c\u201d][\s"\u201c\u201d]*'),
            '"\n"')
        .replaceAll(RegExp(r'[:：]["\u201c\u201d\s]+'), '："')
        .replaceAll(
            RegExp(
                r'\n["\u201c\u201d]([^\n"\u201c\u201d]+)([,:，：]["\u201c\u201d])([^\n"\u201c\u201d]+)'),
            '\n\$1："\$3')
        .replaceAll(RegExp(r'\n(\s*)'), '\n');

    return content1;
  }

  /// 强制切分，减少段落内的句子
  static String _reduceLength(String str) {
    final p = str.split('\n');
    final l = p.length;
    final b = List<bool>.filled(l, false);

    for (var i = 0; i < l; i++) {
      b[i] = _paragraphDialog.hasMatch(p[i]);
    }

    var dialogue = 0;
    for (var i = 0; i < l; i++) {
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

    final result = StringBuffer();
    for (var i = 0; i < l; i++) {
      result.write('\n');
      result.write(p[i]);
    }

    return result.toString();
  }

  /// 强制切分进入对话模式后，未构成 "xxx" 形式的段落
  static String _splitQuote(String str) {
    final length = str.length;
    if (length < 3) return str;

    if (_match(_markQuotation, str[0])) {
      final i = _seekIndex(str, _markQuotation, 1, length - 2, true) + 1;
      if (i > 1 && !_match(_markQuotationBefore, str[i - 1])) {
        return '${str.substring(0, i)}\n${str.substring(i)}';
      }
    } else if (_match(_markQuotation, str[length - 1])) {
      final i =
          length - 1 - _seekIndex(str, _markQuotation, 1, length - 2, false);
      if (i > 1 && !_match(_markQuotationBefore, str[i - 1])) {
        return '${str.substring(0, i)}\n${str.substring(i)}';
      }
    }

    return str;
  }

  /// 对内容重新划分段落（简化版）
  static String _findNewLines(String str, List<String> dict) {
    if (str.isEmpty) return str;

    // ignore: unused_local_variable
    final string = StringBuffer(str);
    final arrayQuote = <int>[];
    var insN = <int>[];

    // 标记每段引号状态
    final mod = List<int>.filled(str.length, 0);
    var waitClose = false;

    // 第一次遍历，标记引号位置
    for (var i = 0; i < str.length; i++) {
      final c = str[i];
      if (_match(_markQuotation, c)) {
        final size = arrayQuote.length;

        // 处理连续引号
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
              arrayQuote.removeLast();
              mod[size - 1] = 1;
              mod[size] = -1;
              continue;
            }
          }
        }

        arrayQuote.add(i);

        // 处理 xxx："xxx"
        if (i > 1) {
          final charB1 = str[i - 1];
          var charB2 = '\u0000';

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
              } else if (!_match('的', charB2)) {
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

    // 去重并排序
    insN = insN.toSet().toList()..sort();

    // 构建最终结果
    final buffer = StringBuffer();
    var progress = 0;

    for (final n in insN) {
      if (n >= progress && n < str.length) {
        buffer.write(str.substring(progress, n + 1));
        buffer.write('\n');
        progress = n + 1;
      }
    }

    if (progress < str.length) {
      buffer.write(str.substring(progress));
    }

    return buffer.isEmpty ? str : buffer.toString();
  }

  /// 从字符串提取引号包围且不止出现一次的内容为字典
  static List<String> _makeDict(String str) {
    final pattern =
        RegExp(r'''(?<=[""'"])([^\p{P}]{1,16})(?=[""'"])''', unicode: true);
    final matcher = pattern.allMatches(str);
    final cache = <String>[];
    final dict = <String>[];

    for (final match in matcher) {
      final word = match.group(0);
      if (word != null) {
        if (cache.contains(word)) {
          if (!dict.contains(word)) {
            dict.add(word);
          }
        } else {
          cache.add(word);
        }
      }
    }

    return dict;
  }

  /// 计算字符串最后出现与字典中字符匹配的位置
  static int _seekLast(String str, String key, int from, int to) {
    if (str.length - from < 1) return -1;
    var i = str.length - 1;
    if (from < i && i > 0) i = from;
    var t = 0;
    if (to > 0) t = to;

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
  static int _seekIndex(
      String str, String key, int from, int to, bool inOrder) {
    if (str.length - from < 1) return -1;
    var i = 0;
    if (from > 0) i = from;
    var t = str.length;
    if (to > 0) t = min(t, to);

    while (i < t) {
      final c = inOrder ? str[i] : str[str.length - i - 1];
      if (key.contains(c)) {
        return i;
      }
      i++;
    }

    return -1;
  }

  /// 匹配字符是否在规则中
  static bool _match(String rule, String chr) {
    return rule.contains(chr);
  }

  // ========== 其他实用方法 ==========

  /// 去除重复标题
  /// 参考项目：ContentProcessor.getContent 中的去重标题逻辑
  ///
  /// [content] 正文内容
  /// [bookName] 书名
  /// [chapterTitle] 章节标题
  /// 返回去除重复标题后的内容
  static String removeSameTitle(
      String content, String bookName, String chapterTitle) {
    if (content.isEmpty || chapterTitle.isEmpty) return content;

    try {
      // 转义书名中的特殊字符
      final escapedBookName = RegExp.escape(bookName);
      // 转义章节标题中的特殊字符，并替换空格为 \s*
      final escapedTitle =
          RegExp.escape(chapterTitle).replaceAll(RegExp(r'\s+'), r'\s*');

      // 构建匹配正则：开头可能有空格、标点或书名，然后是章节标题
      final pattern = RegExp(
          '^(\\s|\\p{P}|$escapedBookName)*$escapedTitle(\\s)*',
          unicode: true);
      final match = pattern.firstMatch(content);

      if (match != null) {
        return content.substring(match.end);
      }
    } catch (e) {
      // 正则匹配失败，返回原内容
    }

    return content;
  }

  /// 格式化内容（添加段落缩进）
  ///
  /// [content] 正文内容
  /// [indent] 段落缩进字符串
  /// [includeTitle] 是否包含标题（标题不缩进）
  static List<String> formatContent(
    String content, {
    String indent = '　　',
    bool includeTitle = true,
  }) {
    final contents = <String>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      var paragraph = lines[i].trim();
      // 去除不可见字符
      paragraph = paragraph.replaceAll(
          RegExp(r'^[\x00-\x20\u3000]+|[\x00-\x20\u3000]+$'), '');

      if (paragraph.isNotEmpty) {
        if (contents.isEmpty && includeTitle) {
          // 第一段是标题，不缩进
          contents.add(paragraph);
        } else {
          // 其他段落添加缩进
          contents.add('$indent$paragraph');
        }
      }
    }

    return contents;
  }

  /// 处理图片标签
  /// 提取内容中的图片 URL
  ///
  /// [content] 正文内容
  /// 返回图片 URL 列表
  static List<String> extractImageUrls(String content) {
    final urls = <String>[];
    final pattern = RegExp(r'''<img[^>]*src=["']([^"']+)["'][^>]*>''',
        caseSensitive: false);
    final matches = pattern.allMatches(content);

    for (final match in matches) {
      final src = match.group(1);
      if (src != null && src.isNotEmpty) {
        urls.add(src);
      }
    }

    return urls;
  }

  /// 移除 HTML 标签
  ///
  /// [content] 包含 HTML 的内容
  /// [keepImages] 是否保留图片标签
  static String removeHtmlTags(String content, {bool keepImages = true}) {
    if (keepImages) {
      // 保留图片标签，移除其他 HTML 标签
      return content.replaceAll(RegExp(r'<(?!img\b)[^>]+>'), '');
    } else {
      // 移除所有 HTML 标签
      return content.replaceAll(RegExp(r'<[^>]+>'), '');
    }
  }

  /// 规范化空白字符
  ///
  /// [content] 正文内容
  static String normalizeWhitespace(String content) {
    return content
        .replaceAll(RegExp(r'\r\n'), '\n')
        .replaceAll(RegExp(r'\r'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
