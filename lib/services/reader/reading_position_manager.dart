import 'package:flutter/material.dart';
import 'models/page_range.dart';
import 'paginator.dart';
import 'pagination_cache.dart';

/// 阅读位置管理器 (参考Gemini文档的阅读位置保持功能)
///
/// **核心问题：**
/// 用户在字体大小15时读到第10页，改为字体20后，第10页的内容变了
///
/// **解决方案：**
/// 不记录"第几页"，而记录**"当前页起始字符在整章中的索引(Offset)"**
/// 重新分页后，寻找包含该Offset的新页码
class ReadingPositionManager {
  /// 保存阅读位置
  ///
  /// [chapterUrl] 章节URL
  /// [pageIndex] 当前页码
  /// [pages] 分页列表
  /// [onSave] 保存回调(将字符偏移量保存到数据库)
  static Future<void> savePosition({
    required String chapterUrl,
    required int pageIndex,
    required List<PageRange> pages,
    required Future<void> Function(String chapterUrl, int charOffset) onSave,
  }) async {
    if (pages.isEmpty || pageIndex < 0 || pageIndex >= pages.length) {
      debugPrint('无效的页码: $pageIndex');
      return;
    }

    // 获取当前页的字符偏移量
    final charOffset = pages[pageIndex].start;

    debugPrint('保存阅读位置: $chapterUrl, 页码=$pageIndex, 字符偏移=$charOffset');

    // 保存到数据库
    await onSave(chapterUrl, charOffset);
  }

  /// 恢复阅读位置
  ///
  /// **重点：字体大小改变后，使用字符偏移量重新定位页码**
  ///
  /// [chapterUrl] 章节URL
  /// [charOffset] 字符偏移量(从数据库读取)
  /// [pages] 重新分页后的列表
  ///
  /// Returns: 新的页码
  static int restorePosition({
    required String chapterUrl,
    required int charOffset,
    required List<PageRange> pages,
  }) {
    if (pages.isEmpty) return 0;
    if (charOffset <= 0) return 0;

    // 使用Paginator的查找方法
    final pageIndex = Paginator.findPageByCharOffset(pages, charOffset);

    debugPrint('恢复阅读位置: $chapterUrl, 字符偏移=$charOffset, 新页码=$pageIndex');

    return pageIndex;
  }

  /// 获取阅读进度百分比
  ///
  /// [currentPage] 当前页码
  /// [pages] 分页列表
  /// [totalChars] 章节总字符数
  ///
  /// Returns: 进度百分比(0.0-1.0)
  static double getProgress({
    required int currentPage,
    required List<PageRange> pages,
    required int totalChars,
  }) {
    if (pages.isEmpty || totalChars <= 0) return 0.0;
    if (currentPage < 0) return 0.0;
    if (currentPage >= pages.length) return 1.0;

    final currentCharOffset = pages[currentPage].start;
    return currentCharOffset / totalChars;
  }

  /// 根据进度百分比获取页码
  ///
  /// [progress] 进度百分比(0.0-1.0)
  /// [pages] 分页列表
  /// [totalChars] 章节总字符数
  ///
  /// Returns: 页码
  static int getPageByProgress({
    required double progress,
    required List<PageRange> pages,
    required int totalChars,
  }) {
    if (pages.isEmpty) return 0;

    final charOffset = (totalChars * progress).round();
    return Paginator.findPageByCharOffset(pages, charOffset);
  }
}

/// 阅读配置 (完整的样式配置模型)
/// 参考Gemini文档: 分页渲染算法-样式配置模型 (ReaderConfig).md
class ReadingConfig {
  // 屏幕尺寸
  final double maxWidth;
  final double maxHeight;

  // 字体设置
  final double fontSize;
  final double lineHeight; // 行高倍数
  final String? fontFamily;
  final FontWeight fontWeight;

  // 间距设置
  final double letterSpacing;
  final double paragraphSpacing; // 段落间距
  final EdgeInsets padding; // 屏幕四周留白

  // 颜色与主题
  final Color backgroundColor;
  final Color textColor;
  final String themeName; // 预设主题名称：'羊皮纸', '夜间', '护眼'

  // 交互逻辑
  final bool clickToFlip; // 点击翻页
  final bool volumeKeyFlip; // 音量键翻页

  const ReadingConfig({
    required this.maxWidth,
    required this.maxHeight,
    this.fontSize = 18.0,
    this.lineHeight = 1.6,
    this.fontFamily,
    this.fontWeight = FontWeight.normal,
    this.letterSpacing = 0.5,
    this.paragraphSpacing = 10.0,
    this.padding = const EdgeInsets.fromLTRB(20, 40, 20, 20),
    this.backgroundColor = const Color(0xFFF2E6D0), // 羊皮纸色
    this.textColor = const Color(0xFF2C2C2C),
    this.themeName = '默认',
    this.clickToFlip = true,
    this.volumeKeyFlip = false,
  });

  /// 计算可见区域尺寸
  double get visibleWidth => maxWidth - padding.left - padding.right;
  double get visibleHeight => maxHeight - padding.top - padding.bottom;

  /// 实际渲染宽度(扣除内边距)
  double get renderWidth => visibleWidth;

  /// 实际渲染高度(扣除内边距)
  double get renderHeight => visibleHeight;

  /// 获取文本样式
  TextStyle get textStyle => TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        letterSpacing: letterSpacing,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
      );

  /// 用于持久化存储
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'fontFamily': fontFamily,
      'fontWeight': fontWeight.index,
      'letterSpacing': letterSpacing,
      'paragraphSpacing': paragraphSpacing,
      'paddingLeft': padding.left,
      'paddingTop': padding.top,
      'paddingRight': padding.right,
      'paddingBottom': padding.bottom,
      'backgroundColor': backgroundColor.value,
      'textColor': textColor.value,
      'themeName': themeName,
      'clickToFlip': clickToFlip,
      'volumeKeyFlip': volumeKeyFlip,
    };
  }

  /// 从JSON恢复
  factory ReadingConfig.fromJson(
      Map<String, dynamic> json, double maxWidth, double maxHeight) {
    return ReadingConfig(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      fontSize: json['fontSize'] ?? 18.0,
      lineHeight: json['lineHeight'] ?? 1.6,
      fontFamily: json['fontFamily'],
      fontWeight: FontWeight.values[json['fontWeight'] ?? 3],
      letterSpacing: json['letterSpacing'] ?? 0.5,
      paragraphSpacing: json['paragraphSpacing'] ?? 10.0,
      padding: EdgeInsets.fromLTRB(
        json['paddingLeft'] ?? 20.0,
        json['paddingTop'] ?? 40.0,
        json['paddingRight'] ?? 20.0,
        json['paddingBottom'] ?? 20.0,
      ),
      backgroundColor: Color(json['backgroundColor'] ?? 0xFFF2E6D0),
      textColor: Color(json['textColor'] ?? 0xFF2C2C2C),
      themeName: json['themeName'] ?? '默认',
      clickToFlip: json['clickToFlip'] ?? true,
      volumeKeyFlip: json['volumeKeyFlip'] ?? false,
    );
  }

  /// 复制并修改部分配置
  ReadingConfig copyWith({
    double? maxWidth,
    double? maxHeight,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    FontWeight? fontWeight,
    String? fontFamily,
    EdgeInsets? padding,
    double? paragraphSpacing,
    Color? backgroundColor,
    Color? textColor,
    String? themeName,
    bool? clickToFlip,
    bool? volumeKeyFlip,
  }) {
    return ReadingConfig(
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      padding: padding ?? this.padding,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      themeName: themeName ?? this.themeName,
      clickToFlip: clickToFlip ?? this.clickToFlip,
      volumeKeyFlip: volumeKeyFlip ?? this.volumeKeyFlip,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadingConfig &&
        other.maxWidth == maxWidth &&
        other.maxHeight == maxHeight &&
        other.fontSize == fontSize &&
        other.lineHeight == lineHeight &&
        other.letterSpacing == letterSpacing &&
        other.fontWeight == fontWeight &&
        other.fontFamily == fontFamily &&
        other.padding == padding &&
        other.paragraphSpacing == paragraphSpacing &&
        other.backgroundColor == backgroundColor &&
        other.textColor == textColor &&
        other.themeName == themeName &&
        other.clickToFlip == clickToFlip &&
        other.volumeKeyFlip == volumeKeyFlip;
  }

  @override
  int get hashCode => Object.hash(
        maxWidth,
        maxHeight,
        fontSize,
        lineHeight,
        letterSpacing,
        fontWeight,
        fontFamily,
        padding,
        paragraphSpacing,
        backgroundColor,
        textColor,
        themeName,
        clickToFlip,
        volumeKeyFlip,
      );
}

/// 分页状态
class PaginationState {
  /// 分页列表
  final List<PageRange> pages;

  /// 当前页码
  final int currentPage;

  /// 章节内容
  final String content;

  /// 是否正在分页
  final bool isPaginating;

  /// 分页错误
  final String? error;

  const PaginationState({
    this.pages = const [],
    this.currentPage = 0,
    this.content = '',
    this.isPaginating = false,
    this.error,
  });

  /// 是否已完成分页
  bool get isCompleted => pages.isNotEmpty && !isPaginating;

  /// 总页数
  int get totalPages => pages.length;

  /// 是否有错误
  bool get hasError => error != null;

  /// 复制并修改部分字段
  PaginationState copyWith({
    List<PageRange>? pages,
    int? currentPage,
    String? content,
    bool? isPaginating,
    String? error,
  }) {
    return PaginationState(
      pages: pages ?? this.pages,
      currentPage: currentPage ?? this.currentPage,
      content: content ?? this.content,
      isPaginating: isPaginating ?? this.isPaginating,
      error: error,
    );
  }
}
