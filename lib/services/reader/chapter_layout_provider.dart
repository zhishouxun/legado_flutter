import 'package:flutter/material.dart';
import '../../ui/pages/reader/models/text_page.dart';
import '../../ui/pages/reader/models/text_chapter.dart';
import '../../data/models/book_chapter.dart';

/// 章节布局提供者（参考项目：ChapterProvider.kt + TextChapterLayout.kt）
/// 实现按行精确分页的核心算法
class ChapterLayoutProvider {
  /// 单例模式
  static final ChapterLayoutProvider _instance =
      ChapterLayoutProvider._internal();
  factory ChapterLayoutProvider() => _instance;
  ChapterLayoutProvider._internal();

  /// 分页配置
  double _viewWidth = 0;
  double _viewHeight = 0;
  double _paddingLeft = 0;
  double _paddingRight = 0;
  double _paddingTop = 0;
  double _paddingBottom = 0;
  double _lineSpacingExtra = 1.0; // 行间距倍数
  double _paragraphSpacing = 0; // 段间距（像素）
  double _fontSize = 18.0;
  double _letterSpacing = 0;
  FontWeight _fontWeight = FontWeight.normal;
  String? _fontFamily;
  double _titleSize = 0; // 标题相对大小
  double _titleTopSpacing = 0; // 标题顶部间距
  double _titleBottomSpacing = 0; // 标题底部间距
  int _titleMode = 0; // 标题模式：0-显示，1-隐藏，2-完全隐藏
  String _paragraphIndent = '　　'; // 段落缩进

  /// 可见区域尺寸
  double get visibleWidth => _viewWidth - _paddingLeft - _paddingRight;
  double get visibleHeight => _viewHeight - _paddingTop - _paddingBottom;

  /// 更新布局配置
  void updateConfig({
    required double viewWidth,
    required double viewHeight,
    required double paddingHorizontal,
    required double paddingVertical,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required int fontWeight,
    String? fontFamily,
    required double titleSize,
    required double titleTopSpacing,
    required double titleBottomSpacing,
    required int titleMode,
    required String paragraphIndent,
    required int paragraphSpacing,
  }) {
    _viewWidth = viewWidth;
    _viewHeight = viewHeight;
    _paddingLeft = paddingHorizontal;
    _paddingRight = paddingHorizontal;
    _paddingTop = paddingVertical;
    _paddingBottom = paddingVertical;
    _fontSize = fontSize;
    _lineSpacingExtra = lineHeight;
    _letterSpacing = letterSpacing;
    _fontWeight = fontWeight == 0
        ? FontWeight.w300
        : (fontWeight == 2 ? FontWeight.bold : FontWeight.normal);
    _fontFamily = fontFamily;
    _titleSize = titleSize;
    _titleTopSpacing = titleTopSpacing;
    _titleBottomSpacing = titleBottomSpacing;
    _titleMode = titleMode;
    _paragraphIndent = paragraphIndent;
    // 参考项目：段间距转换为行高比例
    _paragraphSpacing = paragraphSpacing * fontSize * lineHeight / 10;
  }

  /// 获取正文样式
  TextStyle get contentStyle => TextStyle(
        fontSize: _fontSize,
        height: _lineSpacingExtra,
        letterSpacing: _letterSpacing,
        fontWeight: _fontWeight,
        fontFamily: _fontFamily,
      );

  /// 获取标题样式
  TextStyle get titleStyle => TextStyle(
        fontSize: _fontSize + _titleSize * 0.5,
        height: _lineSpacingExtra,
        letterSpacing: _letterSpacing,
        fontWeight: FontWeight.bold,
        fontFamily: _fontFamily,
      );

  /// 计算文本行高度（参考项目：textHeight）
  double getTextHeight(TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: '测', style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.height;
  }

  /// 执行分页（参考项目：getTextChapter）
  /// 返回 TextChapter 对象，包含分页后的 TextPage 列表
  TextChapter layoutChapter({
    required BookChapter chapter,
    required String content,
    required int chapterIndex,
    required int chaptersSize,
  }) {
    final textChapter = TextChapter(
      chapter: chapter,
      displayTitle: chapter.title,
      chapterIndex: chapterIndex,
      chaptersSize: chaptersSize,
    );

    if (visibleWidth <= 0 || visibleHeight <= 0) {
      // 布局尺寸无效，返回单页
      final page = TextPage(
        text: content,
        title: chapter.title,
        chapterPosition: 0,
      );
      textChapter.addPage(page);
      textChapter.markCompleted();
      return textChapter;
    }

    if (content.trim().isEmpty) {
      final page = TextPage(
        text: '本章节内容为空',
        title: chapter.title,
        chapterPosition: 0,
        isMsgPage: true,
      );
      textChapter.addPage(page);
      textChapter.markCompleted();
      return textChapter;
    }

    // 计算文本高度
    final contentTextHeight = getTextHeight(contentStyle);
    final titleTextHeight = getTextHeight(titleStyle);

    // 开始分页
    double durY = 0;
    final pageInfoHeight = 35.0; // 页码信息区域高度
    final maxHeight = visibleHeight - pageInfoHeight;
    final StringBuilder stringBuilder = StringBuilder();
    var currentPage = TextPage(title: chapter.title);
    int chapterPosition = 0;

    // 处理标题（参考项目：titleMode）
    if (_titleMode != 2 && chapter.title.isNotEmpty) {
      durY += _titleTopSpacing;

      // 标题可能有多行
      final titleLines = _getTextLines(chapter.title, titleStyle, visibleWidth);
      for (final line in titleLines) {
        // 检查是否需要分页
        if (durY + titleTextHeight > maxHeight && stringBuilder.isNotEmpty) {
          // 保存当前页
          currentPage.text = stringBuilder.toString();
          currentPage.chapterPosition =
              chapterPosition - currentPage.text.length;
          currentPage.height = durY;
          textChapter.addPage(currentPage);
          // 创建新页
          currentPage = TextPage(title: chapter.title);
          stringBuilder.clear();
          durY = 0;
        }

        stringBuilder.append(line);
        durY += titleTextHeight;
      }
      stringBuilder.append('\n');
      chapterPosition += chapter.title.length + 1;
      durY += _titleBottomSpacing;
    }

    // 处理正文段落（参考项目：contents.forEach）
    final paragraphs = content.split('\n');
    bool isFirstParagraph = true;

    for (final paragraph in paragraphs) {
      final trimmedParagraph = paragraph.trim();
      if (trimmedParagraph.isEmpty) continue;

      // 跳过与标题重复的内容
      if (isFirstParagraph && trimmedParagraph == chapter.title.trim()) {
        isFirstParagraph = false;
        continue;
      }
      isFirstParagraph = false;

      // 添加段落缩进（参考项目：paragraphIndent）
      final indentedParagraph = _paragraphIndent + trimmedParagraph;

      // 获取段落的所有行
      final lines =
          _getTextLines(indentedParagraph, contentStyle, visibleWidth);

      for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        final line = lines[lineIndex];

        // 检查是否需要分页（参考项目：prepareNextPageIfNeed）
        if (durY + contentTextHeight > maxHeight && stringBuilder.isNotEmpty) {
          // 保存当前页
          currentPage.text = stringBuilder.toString();
          currentPage.chapterPosition =
              chapterPosition - currentPage.text.length;
          currentPage.height = durY;
          textChapter.addPage(currentPage);
          // 创建新页
          currentPage = TextPage(title: chapter.title);
          stringBuilder.clear();
          durY = 0;
        }

        // 添加行内容
        stringBuilder.append(line);
        chapterPosition += line.length;
        durY += contentTextHeight;
      }

      // 段落结束，添加换行符和段间距
      stringBuilder.append('\n');
      chapterPosition += 1;
      durY += _paragraphSpacing;
    }

    // 保存最后一页
    if (stringBuilder.isNotEmpty) {
      currentPage.text = stringBuilder.toString();
      currentPage.chapterPosition = chapterPosition - currentPage.text.length;
      currentPage.height = durY;
      textChapter.addPage(currentPage);
    }

    textChapter.setContent(content);
    textChapter.markCompleted();
    return textChapter;
  }

  /// 将文本拆分成行（参考项目：StaticLayout）
  /// 使用 Flutter 的 TextPainter 实现类似 Android StaticLayout 的功能
  List<String> _getTextLines(String text, TextStyle style, double maxWidth) {
    final lines = <String>[];
    if (text.isEmpty) return lines;

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: maxWidth);

    // 获取行信息
    final lineMetrics = textPainter.computeLineMetrics();
    int startOffset = 0;

    for (int i = 0; i < lineMetrics.length; i++) {
      // 计算当前行的结束位置
      int endOffset;
      if (i < lineMetrics.length - 1) {
        // 使用下一行的开始位置来确定当前行的结束
        final nextLineStart = textPainter
            .getPositionForOffset(
              Offset(
                  0, lineMetrics[i + 1].baseline - lineMetrics[i + 1].ascent),
            )
            .offset;
        endOffset = nextLineStart;
      } else {
        endOffset = text.length;
      }

      // 提取行文本
      if (endOffset > startOffset) {
        lines.add(text.substring(startOffset, endOffset));
        startOffset = endOffset;
      }
    }

    // 如果没有成功提取行，返回原始文本
    if (lines.isEmpty) {
      lines.add(text);
    }

    return lines;
  }

  /// 简化的分页方法 - 直接返回页面字符串列表（兼容旧接口）
  List<String> paginateContent({
    required String content,
    required String chapterTitle,
    required double screenWidth,
    required double screenHeight,
    required double paddingHorizontal,
    required double paddingVertical,
    required double fontSize,
    required double lineHeight,
    required double letterSpacing,
    required int fontWeight,
    String? fontFamily,
    required int titleMode,
    required String paragraphIndent,
    required int paragraphSpacing,
    required double titleSize,
    required double titleTopSpacing,
    required double titleBottomSpacing,
  }) {
    // 更新配置
    updateConfig(
      viewWidth: screenWidth,
      viewHeight: screenHeight,
      paddingHorizontal: paddingHorizontal,
      paddingVertical: paddingVertical,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontFamily: fontFamily,
      titleSize: titleSize,
      titleTopSpacing: titleTopSpacing,
      titleBottomSpacing: titleBottomSpacing,
      titleMode: titleMode,
      paragraphIndent: paragraphIndent,
      paragraphSpacing: paragraphSpacing,
    );

    if (visibleWidth <= 0 || visibleHeight <= 0) {
      return [content];
    }

    if (content.trim().isEmpty) {
      return ['本章节内容为空'];
    }

    // 使用精确的按行分页算法
    return _paginateByLine(content, chapterTitle);
  }

  /// 按行精确分页（核心算法）
  List<String> _paginateByLine(String content, String chapterTitle) {
    final pages = <String>[];
    final contentTextHeight = getTextHeight(contentStyle);

    final pageInfoHeight = 35.0;
    final maxHeight = visibleHeight - pageInfoHeight;

    double durY = 0;
    final currentPageLines = <String>[];
    bool isFirstPage = true;
    double firstPageMaxHeight = maxHeight;

    // 处理标题
    if (_titleMode != 2 && chapterTitle.isNotEmpty) {
      final titleHeight = _calculateTitleHeight(chapterTitle);
      firstPageMaxHeight = maxHeight - titleHeight;
    }

    // 处理正文段落
    final paragraphs = content.split('\n');
    bool isFirstParagraph = true;

    for (final paragraph in paragraphs) {
      final trimmedParagraph = paragraph.trim();
      if (trimmedParagraph.isEmpty) continue;

      // 跳过与标题重复的内容
      if (isFirstParagraph && trimmedParagraph == chapterTitle.trim()) {
        isFirstParagraph = false;
        continue;
      }
      isFirstParagraph = false;

      // 添加段落缩进
      final indentedParagraph = _paragraphIndent + trimmedParagraph;

      // 获取段落的所有行
      final lines =
          _getTextLines(indentedParagraph, contentStyle, visibleWidth);

      for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        final line = lines[lineIndex];
        final currentMaxHeight = isFirstPage ? firstPageMaxHeight : maxHeight;

        // 检查是否需要分页
        if (durY + contentTextHeight > currentMaxHeight &&
            currentPageLines.isNotEmpty) {
          // 保存当前页
          pages.add(currentPageLines.join(''));
          currentPageLines.clear();
          durY = 0;
          isFirstPage = false;
        }

        // 添加行内容
        currentPageLines.add(line);
        durY += contentTextHeight;
      }

      // 段落结束，添加换行符
      if (currentPageLines.isNotEmpty) {
        // 在最后一行后添加换行
        final lastLine = currentPageLines.removeLast();
        currentPageLines.add('$lastLine\n');
      }
      // 段间距
      durY += _paragraphSpacing;
    }

    // 保存最后一页
    if (currentPageLines.isNotEmpty) {
      pages.add(currentPageLines.join(''));
    }

    if (pages.isEmpty) {
      pages.add(content);
    }

    return pages;
  }

  /// 计算标题高度
  double _calculateTitleHeight(String title) {
    double height = _titleTopSpacing;
    final titleTextHeight = getTextHeight(titleStyle);
    final lines = _getTextLines(title, titleStyle, visibleWidth);
    height += lines.length * titleTextHeight;
    height += _titleBottomSpacing;
    return height;
  }
}

/// StringBuilder 辅助类
class StringBuilder {
  final StringBuffer _buffer = StringBuffer();

  void append(String str) {
    _buffer.write(str);
  }

  void clear() {
    _buffer.clear();
  }

  bool get isNotEmpty => _buffer.isNotEmpty;
  bool get isEmpty => _buffer.isEmpty;

  @override
  String toString() => _buffer.toString();
}
