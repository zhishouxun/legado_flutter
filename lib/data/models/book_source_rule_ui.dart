import 'dart:convert';

/// UI规则相关数据模型
/// 参考项目：io.legado.app.data.entities.rule

/// 行UI规则
/// 参考项目：io.legado.app.data.entities.rule.RowUi
class RowUi {
  /// 名称
  final String name;

  /// 类型（text, password, button）
  final String type;

  /// 操作
  final String? action;

  /// 样式
  final FlexChildStyle? style;

  RowUi({
    this.name = '',
    this.type = 'text',
    this.action,
    this.style,
  });

  factory RowUi.fromJson(Map<String, dynamic> json) {
    return RowUi(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      action: json['action'] as String?,
      style: json['style'] != null
          ? FlexChildStyle.fromJson(json['style'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      if (action != null) 'action': action,
      if (style != null) 'style': style!.toJson(),
    };
  }

  /// 获取样式（如果为空则返回默认样式）
  FlexChildStyle getStyle() {
    return style ?? FlexChildStyle.defaultStyle();
  }

  /// 类型常量
  static const String typeText = 'text';
  static const String typePassword = 'password';
  static const String typeButton = 'button';
}

/// 弹性子样式
/// 参考项目：io.legado.app.data.entities.rule.FlexChildStyle
/// 
/// 注意：Flutter 使用不同的布局系统，此模型主要用于数据存储和序列化
class FlexChildStyle {
  /// 弹性增长
  final double layoutFlexGrow;

  /// 弹性收缩
  final double layoutFlexShrink;

  /// 对齐方式（auto, flex_start, flex_end, center, baseline, stretch）
  final String layoutAlignSelf;

  /// 弹性基础百分比
  final double layoutFlexBasisPercent;

  /// 是否在之前换行
  final bool layoutWrapBefore;

  FlexChildStyle({
    this.layoutFlexGrow = 0.0,
    this.layoutFlexShrink = 1.0,
    this.layoutAlignSelf = 'auto',
    this.layoutFlexBasisPercent = -1.0,
    this.layoutWrapBefore = false,
  });

  factory FlexChildStyle.fromJson(Map<String, dynamic> json) {
    return FlexChildStyle(
      layoutFlexGrow: (json['layout_flexGrow'] as num?)?.toDouble() ?? 0.0,
      layoutFlexShrink: (json['layout_flexShrink'] as num?)?.toDouble() ?? 1.0,
      layoutAlignSelf: json['layout_alignSelf'] as String? ?? 'auto',
      layoutFlexBasisPercent:
          (json['layout_flexBasisPercent'] as num?)?.toDouble() ?? -1.0,
      layoutWrapBefore: json['layout_wrapBefore'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'layout_flexGrow': layoutFlexGrow,
      'layout_flexShrink': layoutFlexShrink,
      'layout_alignSelf': layoutAlignSelf,
      'layout_flexBasisPercent': layoutFlexBasisPercent,
      'layout_wrapBefore': layoutWrapBefore,
    };
  }

  /// 获取对齐方式枚举值
  /// 返回：-1=auto, 0=flex_start, 1=flex_end, 2=center, 3=baseline, 4=stretch
  int alignSelf() {
    switch (layoutAlignSelf) {
      case 'auto':
        return -1;
      case 'flex_start':
        return 0;
      case 'flex_end':
        return 1;
      case 'center':
        return 2;
      case 'baseline':
        return 3;
      case 'stretch':
        return 4;
      default:
        return -1;
    }
  }

  /// 默认样式
  static FlexChildStyle defaultStyle() {
    return FlexChildStyle();
  }

  /// 对齐方式常量
  static const String alignSelfAuto = 'auto';
  static const String alignSelfFlexStart = 'flex_start';
  static const String alignSelfFlexEnd = 'flex_end';
  static const String alignSelfCenter = 'center';
  static const String alignSelfBaseline = 'baseline';
  static const String alignSelfStretch = 'stretch';
}

/// 评论规则
/// 参考项目：io.legado.app.data.entities.rule.ReviewRule
class ReviewRule {
  /// 段评URL
  final String? reviewUrl;

  /// 段评发布者头像规则
  final String? avatarRule;

  /// 段评内容规则
  final String? contentRule;

  /// 段评发布时间规则
  final String? postTimeRule;

  /// 获取段评回复URL
  final String? reviewQuoteUrl;

  /// 点赞URL
  final String? voteUpUrl;

  /// 点踩URL
  final String? voteDownUrl;

  /// 发送回复URL
  final String? postReviewUrl;

  /// 发送回复段评URL
  final String? postQuoteUrl;

  /// 删除段评URL
  final String? deleteUrl;

  ReviewRule({
    this.reviewUrl,
    this.avatarRule,
    this.contentRule,
    this.postTimeRule,
    this.reviewQuoteUrl,
    this.voteUpUrl,
    this.voteDownUrl,
    this.postReviewUrl,
    this.postQuoteUrl,
    this.deleteUrl,
  });

  factory ReviewRule.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ReviewRule();
    }

    return ReviewRule(
      reviewUrl: json['reviewUrl'] as String?,
      avatarRule: json['avatarRule'] as String?,
      contentRule: json['contentRule'] as String?,
      postTimeRule: json['postTimeRule'] as String?,
      reviewQuoteUrl: json['reviewQuoteUrl'] as String?,
      voteUpUrl: json['voteUpUrl'] as String?,
      voteDownUrl: json['voteDownUrl'] as String?,
      postReviewUrl: json['postReviewUrl'] as String?,
      postQuoteUrl: json['postQuoteUrl'] as String?,
      deleteUrl: json['deleteUrl'] as String?,
    );
  }

  /// 从JSON字符串创建
  factory ReviewRule.fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return ReviewRule();
    }

    try {
      // 如果字符串本身是JSON对象字符串，需要解析
      if (jsonString.trim().startsWith('{')) {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        return ReviewRule.fromJson(decoded);
      } else {
        // 如果字符串是JSON字符串的字符串表示，需要双重解析
        final decoded = jsonDecode(jsonString) as String;
        final innerDecoded = jsonDecode(decoded) as Map<String, dynamic>;
        return ReviewRule.fromJson(innerDecoded);
      }
    } catch (e) {
      return ReviewRule();
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (reviewUrl != null) map['reviewUrl'] = reviewUrl;
    if (avatarRule != null) map['avatarRule'] = avatarRule;
    if (contentRule != null) map['contentRule'] = contentRule;
    if (postTimeRule != null) map['postTimeRule'] = postTimeRule;
    if (reviewQuoteUrl != null) map['reviewQuoteUrl'] = reviewQuoteUrl;
    if (voteUpUrl != null) map['voteUpUrl'] = voteUpUrl;
    if (voteDownUrl != null) map['voteDownUrl'] = voteDownUrl;
    if (postReviewUrl != null) map['postReviewUrl'] = postReviewUrl;
    if (postQuoteUrl != null) map['postQuoteUrl'] = postQuoteUrl;
    if (deleteUrl != null) map['deleteUrl'] = deleteUrl;
    return map;
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }
}

