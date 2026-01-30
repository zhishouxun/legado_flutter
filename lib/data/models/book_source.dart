import 'package:json_annotation/json_annotation.dart';
import 'book_source_rule.dart';

// part 'book_source.g.dart'; // 运行 build_runner 后取消注释

@JsonSerializable()
class BookSource {
  /// 地址，包括 http/https
  @JsonKey(name: 'bookSourceUrl')
  final String bookSourceUrl;

  /// 名称
  @JsonKey(name: 'bookSourceName')
  String bookSourceName;

  /// 分组
  @JsonKey(name: 'bookSourceGroup')
  String? bookSourceGroup;

  /// 类型，0 文本，1 音频, 2 图片, 3 文件
  @JsonKey(name: 'bookSourceType')
  int bookSourceType;

  /// 详情页url正则
  @JsonKey(name: 'bookUrlPattern')
  String? bookUrlPattern;

  /// 手动排序编号
  @JsonKey(name: 'customOrder')
  int customOrder;

  /// 是否启用
  @JsonKey(name: 'enabled')
  bool enabled;

  /// 启用发现
  @JsonKey(name: 'enabledExplore')
  bool enabledExplore;

  /// js库
  @JsonKey(name: 'jsLib')
  String? jsLib;

  /// 启用okhttp CookieJAr 自动保存每次请求的cookie
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

  /// 登录检测js
  @JsonKey(name: 'loginCheckJs')
  String? loginCheckJs;

  /// 封面解密js
  @JsonKey(name: 'coverDecodeJs')
  String? coverDecodeJs;

  /// 注释
  @JsonKey(name: 'bookSourceComment')
  String? bookSourceComment;

  /// 自定义变量说明
  @JsonKey(name: 'variableComment')
  String? variableComment;

  /// 最后更新时间
  @JsonKey(name: 'lastUpdateTime')
  int lastUpdateTime;

  /// 响应时间
  @JsonKey(name: 'respondTime')
  int respondTime;

  /// 智能排序的权重
  @JsonKey(name: 'weight')
  int weight;

  /// 发现url
  @JsonKey(name: 'exploreUrl')
  String? exploreUrl;

  /// 发现筛选规则
  @JsonKey(name: 'exploreScreen')
  String? exploreScreen;

  /// 发现规则
  @JsonKey(name: 'ruleExplore')
  ExploreRule? ruleExplore;

  /// 搜索url
  @JsonKey(name: 'searchUrl')
  String? searchUrl;

  /// 搜索规则
  @JsonKey(name: 'ruleSearch')
  SearchRule? ruleSearch;

  /// 书籍信息页规则
  @JsonKey(name: 'ruleBookInfo')
  BookInfoRule? ruleBookInfo;

  /// 目录页规则
  @JsonKey(name: 'ruleToc')
  TocRule? ruleToc;

  /// 正文页规则
  @JsonKey(name: 'ruleContent')
  ContentRule? ruleContent;

  BookSource({
    required this.bookSourceUrl,
    this.bookSourceName = '',
    this.bookSourceGroup,
    this.bookSourceType = 0,
    this.bookUrlPattern,
    this.customOrder = 0,
    this.enabled = true,
    this.enabledExplore = true,
    this.jsLib,
    this.enabledCookieJar = true,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.bookSourceComment,
    this.variableComment,
    this.lastUpdateTime = 0,
    this.respondTime = 180000,
    this.weight = 0,
    this.exploreUrl,
    this.exploreScreen,
    this.ruleExplore,
    this.searchUrl,
    this.ruleSearch,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
  });

  factory BookSource.fromJson(Map<String, dynamic> json) {
    return BookSource(
      bookSourceUrl: json['bookSourceUrl'] ?? '',
      bookSourceName: json['bookSourceName'] ?? '',
      bookSourceGroup: json['bookSourceGroup'],
      bookSourceType: json['bookSourceType'] ?? 0,
      bookUrlPattern: json['bookUrlPattern'],
      customOrder: json['customOrder'] ?? 0,
      enabled: json['enabled'] ?? true,
      enabledExplore: json['enabledExplore'] ?? true,
      jsLib: json['jsLib'],
      enabledCookieJar: json['enabledCookieJar'] ?? true,
      concurrentRate: json['concurrentRate'],
      header: json['header'],
      loginUrl: json['loginUrl'],
      loginUi: json['loginUi'],
      loginCheckJs: json['loginCheckJs'],
      coverDecodeJs: json['coverDecodeJs'],
      bookSourceComment: json['bookSourceComment'],
      variableComment: json['variableComment'],
      lastUpdateTime: json['lastUpdateTime'] ?? 0,
      respondTime: json['respondTime'] ?? 180000,
      weight: json['weight'] ?? 0,
      exploreUrl: json['exploreUrl'],
      exploreScreen: json['exploreScreen'],
      ruleExplore: json['ruleExplore'] != null 
          ? ExploreRule.fromJson(json['ruleExplore']) 
          : null,
      searchUrl: json['searchUrl'],
      ruleSearch: json['ruleSearch'] != null 
          ? SearchRule.fromJson(json['ruleSearch']) 
          : null,
      ruleBookInfo: json['ruleBookInfo'] != null 
          ? BookInfoRule.fromJson(json['ruleBookInfo']) 
          : null,
      ruleToc: json['ruleToc'] != null 
          ? TocRule.fromJson(json['ruleToc']) 
          : null,
      ruleContent: json['ruleContent'] != null 
          ? ContentRule.fromJson(json['ruleContent']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'bookSourceUrl': bookSourceUrl,
      'bookSourceName': bookSourceName,
      'bookSourceGroup': bookSourceGroup,
      'bookSourceType': bookSourceType,
      'bookUrlPattern': bookUrlPattern,
      'customOrder': customOrder,
      'enabled': enabled,
      'enabledExplore': enabledExplore,
      'jsLib': jsLib,
      'enabledCookieJar': enabledCookieJar,
      'concurrentRate': concurrentRate,
      'header': header,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'loginCheckJs': loginCheckJs,
      'coverDecodeJs': coverDecodeJs,
      'bookSourceComment': bookSourceComment,
      'variableComment': variableComment,
      'lastUpdateTime': lastUpdateTime,
      'respondTime': respondTime,
      'weight': weight,
      'exploreUrl': exploreUrl,
      'exploreScreen': exploreScreen,
      'ruleExplore': ruleExplore?.toJson(),
      'searchUrl': searchUrl,
      'ruleSearch': ruleSearch?.toJson(),
      'ruleBookInfo': ruleBookInfo?.toJson(),
      'ruleToc': ruleToc?.toJson(),
      'ruleContent': ruleContent?.toJson(),
    };
  }

  BookSource copyWith({
    String? bookSourceUrl,
    String? bookSourceName,
    String? bookSourceGroup,
    int? bookSourceType,
    String? bookUrlPattern,
    int? customOrder,
    bool? enabled,
    bool? enabledExplore,
    String? jsLib,
    bool? enabledCookieJar,
    String? concurrentRate,
    String? header,
    String? loginUrl,
    String? loginUi,
    String? loginCheckJs,
    String? coverDecodeJs,
    String? bookSourceComment,
    String? variableComment,
    int? lastUpdateTime,
    int? respondTime,
    int? weight,
    String? exploreUrl,
    String? exploreScreen,
    ExploreRule? ruleExplore,
    String? searchUrl,
    SearchRule? ruleSearch,
    BookInfoRule? ruleBookInfo,
    TocRule? ruleToc,
    ContentRule? ruleContent,
  }) {
    return BookSource(
      bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
      bookSourceName: bookSourceName ?? this.bookSourceName,
      bookSourceGroup: bookSourceGroup ?? this.bookSourceGroup,
      bookSourceType: bookSourceType ?? this.bookSourceType,
      bookUrlPattern: bookUrlPattern ?? this.bookUrlPattern,
      customOrder: customOrder ?? this.customOrder,
      enabled: enabled ?? this.enabled,
      enabledExplore: enabledExplore ?? this.enabledExplore,
      jsLib: jsLib ?? this.jsLib,
      enabledCookieJar: enabledCookieJar ?? this.enabledCookieJar,
      concurrentRate: concurrentRate ?? this.concurrentRate,
      header: header ?? this.header,
      loginUrl: loginUrl ?? this.loginUrl,
      loginUi: loginUi ?? this.loginUi,
      loginCheckJs: loginCheckJs ?? this.loginCheckJs,
      coverDecodeJs: coverDecodeJs ?? this.coverDecodeJs,
      bookSourceComment: bookSourceComment ?? this.bookSourceComment,
      variableComment: variableComment ?? this.variableComment,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      respondTime: respondTime ?? this.respondTime,
      weight: weight ?? this.weight,
      exploreUrl: exploreUrl ?? this.exploreUrl,
      exploreScreen: exploreScreen ?? this.exploreScreen,
      ruleExplore: ruleExplore ?? this.ruleExplore,
      searchUrl: searchUrl ?? this.searchUrl,
      ruleSearch: ruleSearch ?? this.ruleSearch,
      ruleBookInfo: ruleBookInfo ?? this.ruleBookInfo,
      ruleToc: ruleToc ?? this.ruleToc,
      ruleContent: ruleContent ?? this.ruleContent,
    );
  }
}

