import 'package:json_annotation/json_annotation.dart';

/// RSS源数据模型
@JsonSerializable()
class RssSource {
  /// 源URL（主键）
  @JsonKey(name: 'sourceUrl')
  final String sourceUrl;

  /// 源名称
  @JsonKey(name: 'sourceName')
  String sourceName;

  /// 源图标
  @JsonKey(name: 'sourceIcon')
  String? sourceIcon;

  /// 分组
  @JsonKey(name: 'sourceGroup')
  String? sourceGroup;

  /// 注释
  @JsonKey(name: 'sourceComment')
  String? sourceComment;

  /// 是否启用
  @JsonKey(name: 'enabled')
  bool enabled;

  /// 自定义变量说明
  @JsonKey(name: 'variableComment')
  String? variableComment;

  /// JS库
  @JsonKey(name: 'jsLib')
  String? jsLib;

  /// 启用CookieJar
  @JsonKey(name: 'enabledCookieJar')
  bool enabledCookieJar;

  /// 并发率
  @JsonKey(name: 'concurrentRate')
  String? concurrentRate;

  /// 请求头
  @JsonKey(name: 'header')
  String? header;

  /// 登录地址
  @JsonKey(name: 'loginUrl')
  String? loginUrl;

  /// 登录UI
  @JsonKey(name: 'loginUi')
  String? loginUi;

  /// 登录检测JS
  @JsonKey(name: 'loginCheckJs')
  String? loginCheckJs;

  /// 封面解密JS
  @JsonKey(name: 'coverDecodeJs')
  String? coverDecodeJs;

  /// 分类URL
  @JsonKey(name: 'sortUrl')
  String? sortUrl;

  /// 是否单URL源
  @JsonKey(name: 'singleUrl')
  bool singleUrl;

  /// 文章样式（0,1,2）
  @JsonKey(name: 'articleStyle')
  int articleStyle;

  /// 列表规则
  @JsonKey(name: 'ruleArticles')
  String? ruleArticles;

  /// 下一页规则
  @JsonKey(name: 'ruleNextPage')
  String? ruleNextPage;

  /// 标题规则
  @JsonKey(name: 'ruleTitle')
  String? ruleTitle;

  /// 发布日期规则
  @JsonKey(name: 'rulePubDate')
  String? rulePubDate;

  /// 描述规则
  @JsonKey(name: 'ruleDescription')
  String? ruleDescription;

  /// 图片规则
  @JsonKey(name: 'ruleImage')
  String? ruleImage;

  /// 链接规则
  @JsonKey(name: 'ruleLink')
  String? ruleLink;

  /// 正文规则
  @JsonKey(name: 'ruleContent')
  String? ruleContent;

  /// 正文URL白名单
  @JsonKey(name: 'contentWhitelist')
  String? contentWhitelist;

  /// 正文URL黑名单
  @JsonKey(name: 'contentBlacklist')
  String? contentBlacklist;

  /// 跳转URL拦截JS
  @JsonKey(name: 'shouldOverrideUrlLoading')
  String? shouldOverrideUrlLoading;

  /// WebView样式
  @JsonKey(name: 'style')
  String? style;

  /// 启用JS
  @JsonKey(name: 'enableJs')
  bool enableJs;

  /// 使用BaseURL加载
  @JsonKey(name: 'loadWithBaseUrl')
  bool loadWithBaseUrl;

  /// 注入JS
  @JsonKey(name: 'injectJs')
  String? injectJs;

  /// 最后更新时间
  @JsonKey(name: 'lastUpdateTime')
  int lastUpdateTime;

  /// 自定义排序
  @JsonKey(name: 'customOrder')
  int customOrder;

  RssSource({
    required this.sourceUrl,
    required this.sourceName,
    this.sourceIcon,
    this.sourceGroup,
    this.sourceComment,
    this.enabled = true,
    this.variableComment,
    this.jsLib,
    this.enabledCookieJar = true,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.sortUrl,
    this.singleUrl = false,
    this.articleStyle = 0,
    this.ruleArticles,
    this.ruleNextPage,
    this.ruleTitle,
    this.rulePubDate,
    this.ruleDescription,
    this.ruleImage,
    this.ruleLink,
    this.ruleContent,
    this.contentWhitelist,
    this.contentBlacklist,
    this.shouldOverrideUrlLoading,
    this.style,
    this.enableJs = true,
    this.loadWithBaseUrl = true,
    this.injectJs,
    this.lastUpdateTime = 0,
    this.customOrder = 0,
  });

  /// 从JSON创建
  factory RssSource.fromJson(Map<String, dynamic> json) {
    return RssSource(
      sourceUrl: json['sourceUrl'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      sourceIcon: json['sourceIcon'] as String?,
      sourceGroup: json['sourceGroup'] as String?,
      sourceComment: json['sourceComment'] as String?,
      enabled: json['enabled'] == true || json['enabled'] == 1,
      variableComment: json['variableComment'] as String?,
      jsLib: json['jsLib'] as String?,
      enabledCookieJar:
          json['enabledCookieJar'] != false && json['enabledCookieJar'] != 0,
      concurrentRate: json['concurrentRate'] as String?,
      header: json['header'] as String?,
      loginUrl: json['loginUrl'] as String?,
      loginUi: json['loginUi'] as String?,
      loginCheckJs: json['loginCheckJs'] as String?,
      coverDecodeJs: json['coverDecodeJs'] as String?,
      sortUrl: json['sortUrl'] as String?,
      singleUrl: json['singleUrl'] == true || json['singleUrl'] == 1,
      articleStyle: json['articleStyle'] as int? ?? 0,
      ruleArticles: json['ruleArticles'] as String?,
      ruleNextPage: json['ruleNextPage'] as String?,
      ruleTitle: json['ruleTitle'] as String?,
      rulePubDate: json['rulePubDate'] as String?,
      ruleDescription: json['ruleDescription'] as String?,
      ruleImage: json['ruleImage'] as String?,
      ruleLink: json['ruleLink'] as String?,
      ruleContent: json['ruleContent'] as String?,
      contentWhitelist: json['contentWhitelist'] as String?,
      contentBlacklist: json['contentBlacklist'] as String?,
      shouldOverrideUrlLoading: json['shouldOverrideUrlLoading'] as String?,
      style: json['style'] as String?,
      enableJs: json['enableJs'] != false && json['enableJs'] != 0,
      loadWithBaseUrl:
          json['loadWithBaseUrl'] != false && json['loadWithBaseUrl'] != 0,
      injectJs: json['injectJs'] as String?,
      lastUpdateTime: json['lastUpdateTime'] as int? ?? 0,
      customOrder: json['customOrder'] as int? ?? 0,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'sourceIcon': sourceIcon,
      'sourceGroup': sourceGroup,
      'sourceComment': sourceComment,
      'enabled': enabled ? 1 : 0,
      'variableComment': variableComment,
      'jsLib': jsLib,
      'enabledCookieJar': enabledCookieJar ? 1 : 0,
      'concurrentRate': concurrentRate,
      'header': header,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'loginCheckJs': loginCheckJs,
      'coverDecodeJs': coverDecodeJs,
      'sortUrl': sortUrl,
      'singleUrl': singleUrl ? 1 : 0,
      'articleStyle': articleStyle,
      'ruleArticles': ruleArticles,
      'ruleNextPage': ruleNextPage,
      'ruleTitle': ruleTitle,
      'rulePubDate': rulePubDate,
      'ruleDescription': ruleDescription,
      'ruleImage': ruleImage,
      'ruleLink': ruleLink,
      'ruleContent': ruleContent,
      'contentWhitelist': contentWhitelist,
      'contentBlacklist': contentBlacklist,
      'shouldOverrideUrlLoading': shouldOverrideUrlLoading,
      'style': style,
      'enableJs': enableJs ? 1 : 0,
      'loadWithBaseUrl': loadWithBaseUrl ? 1 : 0,
      'injectJs': injectJs,
      'lastUpdateTime': lastUpdateTime,
      'customOrder': customOrder,
    };
  }

  /// 复制
  RssSource copyWith({
    String? sourceUrl,
    String? sourceName,
    String? sourceIcon,
    String? sourceGroup,
    String? sourceComment,
    bool? enabled,
    String? variableComment,
    String? jsLib,
    bool? enabledCookieJar,
    String? concurrentRate,
    String? header,
    String? loginUrl,
    String? loginUi,
    String? loginCheckJs,
    String? coverDecodeJs,
    String? sortUrl,
    bool? singleUrl,
    int? articleStyle,
    String? ruleArticles,
    String? ruleNextPage,
    String? ruleTitle,
    String? rulePubDate,
    String? ruleDescription,
    String? ruleImage,
    String? ruleLink,
    String? ruleContent,
    String? contentWhitelist,
    String? contentBlacklist,
    String? shouldOverrideUrlLoading,
    String? style,
    bool? enableJs,
    bool? loadWithBaseUrl,
    String? injectJs,
    int? lastUpdateTime,
    int? customOrder,
  }) {
    return RssSource(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceName: sourceName ?? this.sourceName,
      sourceIcon: sourceIcon ?? this.sourceIcon,
      sourceGroup: sourceGroup ?? this.sourceGroup,
      sourceComment: sourceComment ?? this.sourceComment,
      enabled: enabled ?? this.enabled,
      variableComment: variableComment ?? this.variableComment,
      jsLib: jsLib ?? this.jsLib,
      enabledCookieJar: enabledCookieJar ?? this.enabledCookieJar,
      concurrentRate: concurrentRate ?? this.concurrentRate,
      header: header ?? this.header,
      loginUrl: loginUrl ?? this.loginUrl,
      loginUi: loginUi ?? this.loginUi,
      loginCheckJs: loginCheckJs ?? this.loginCheckJs,
      coverDecodeJs: coverDecodeJs ?? this.coverDecodeJs,
      sortUrl: sortUrl ?? this.sortUrl,
      singleUrl: singleUrl ?? this.singleUrl,
      articleStyle: articleStyle ?? this.articleStyle,
      ruleArticles: ruleArticles ?? this.ruleArticles,
      ruleNextPage: ruleNextPage ?? this.ruleNextPage,
      ruleTitle: ruleTitle ?? this.ruleTitle,
      rulePubDate: rulePubDate ?? this.rulePubDate,
      ruleDescription: ruleDescription ?? this.ruleDescription,
      ruleImage: ruleImage ?? this.ruleImage,
      ruleLink: ruleLink ?? this.ruleLink,
      ruleContent: ruleContent ?? this.ruleContent,
      contentWhitelist: contentWhitelist ?? this.contentWhitelist,
      contentBlacklist: contentBlacklist ?? this.contentBlacklist,
      shouldOverrideUrlLoading:
          shouldOverrideUrlLoading ?? this.shouldOverrideUrlLoading,
      style: style ?? this.style,
      enableJs: enableJs ?? this.enableJs,
      loadWithBaseUrl: loadWithBaseUrl ?? this.loadWithBaseUrl,
      injectJs: injectJs ?? this.injectJs,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      customOrder: customOrder ?? this.customOrder,
    );
  }

  /// 获取显示名称（含分组）
  String getDisplayNameGroup() {
    if (sourceGroup == null || sourceGroup!.isEmpty) {
      return sourceName;
    }
    return '$sourceName ($sourceGroup)';
  }
}
