import 'dart:convert';

/// 页脚对齐方式
class MangaFooterAlignment {
  static const int left = 0;
  static const int center = 1;
}

/// 漫画页脚配置
/// 参考项目：MangaFooterConfig.kt
class MangaFooterConfig {
  bool hideChapterLabel; // 隐藏章节标签
  bool hideChapter; // 隐藏章节号
  bool hidePageNumberLabel; // 隐藏页码标签
  bool hidePageNumber; // 隐藏页码
  bool hideProgressRatioLabel; // 隐藏进度比例标签
  bool hideProgressRatio; // 隐藏进度比例
  int footerOrientation; // 页脚对齐方式 (0=左对齐, 1=居中)
  bool hideFooter; // 隐藏页脚
  bool hideChapterName; // 隐藏章节名称

  MangaFooterConfig({
    this.hideChapterLabel = false,
    this.hideChapter = false,
    this.hidePageNumberLabel = false,
    this.hidePageNumber = false,
    this.hideProgressRatioLabel = false,
    this.hideProgressRatio = false,
    this.footerOrientation = MangaFooterAlignment.left,
    this.hideFooter = false,
    this.hideChapterName = false,
  });

  /// 从JSON创建
  factory MangaFooterConfig.fromJson(Map<String, dynamic> json) {
    return MangaFooterConfig(
      hideChapterLabel: json['hideChapterLabel'] ?? false,
      hideChapter: json['hideChapter'] ?? false,
      hidePageNumberLabel: json['hidePageNumberLabel'] ?? false,
      hidePageNumber: json['hidePageNumber'] ?? false,
      hideProgressRatioLabel: json['hideProgressRatioLabel'] ?? false,
      hideProgressRatio: json['hideProgressRatio'] ?? false,
      footerOrientation: json['footerOrientation'] ?? MangaFooterAlignment.left,
      hideFooter: json['hideFooter'] ?? false,
      hideChapterName: json['hideChapterName'] ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'hideChapterLabel': hideChapterLabel,
      'hideChapter': hideChapter,
      'hidePageNumberLabel': hidePageNumberLabel,
      'hidePageNumber': hidePageNumber,
      'hideProgressRatioLabel': hideProgressRatioLabel,
      'hideProgressRatio': hideProgressRatio,
      'footerOrientation': footerOrientation,
      'hideFooter': hideFooter,
      'hideChapterName': hideChapterName,
    };
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 从JSON字符串创建
  factory MangaFooterConfig.fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) {
      return MangaFooterConfig();
    }
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return MangaFooterConfig.fromJson(json);
    } catch (e) {
      return MangaFooterConfig();
    }
  }
}

