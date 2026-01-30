/// Domain层的书源实体 - 纯净的业务对象，不依赖任何第三方库
/// 参考：Clean Architecture - Entity Layer
class BookSourceEntity {
  final String bookSourceUrl; // 书源URL，唯一标识
  final String bookSourceName; // 书源名称
  final String? bookSourceGroup; // 书源分组
  final int bookSourceType; // 书源类型 (0:文本 1:音频 2:图片 3:文件)
  final String? bookUrlPattern; // 详情页URL正则
  final int customOrder; // 手动排序编号
  final bool enabled; // 是否启用
  final bool enabledExplore; // 是否启用发现
  final String? jsLib; // JS库
  final bool enabledCookieJar; // 是否启用Cookie自动保存
  final String? concurrentRate; // 并发率
  final String? header; // 请求头
  final String? loginUrl; // 登录地址
  final String? loginUi; // 登录UI
  final String? loginCheckJs; // 登录检测JS
  final String? coverDecodeJs; // 封面解密JS
  final String? bookSourceComment; // 注释
  final String? variableComment; // 自定义变量说明
  final int lastUpdateTime; // 最后更新时间
  final int respondTime; // 响应时间
  final int weight; // 智能排序权重
  final String? exploreUrl; // 发现URL
  final String? exploreScreen; // 发现筛选规则
  final String? searchUrl; // 搜索URL

  // 规则对象(使用Map存储，保持纯净性)
  final Map<String, dynamic>? ruleExplore; // 发现规则
  final Map<String, dynamic>? ruleSearch; // 搜索规则
  final Map<String, dynamic>? ruleBookInfo; // 书籍信息规则
  final Map<String, dynamic>? ruleToc; // 目录规则
  final Map<String, dynamic>? ruleContent; // 正文规则

  const BookSourceEntity({
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup,
    required this.bookSourceType,
    this.bookUrlPattern,
    required this.customOrder,
    required this.enabled,
    required this.enabledExplore,
    this.jsLib,
    required this.enabledCookieJar,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.bookSourceComment,
    this.variableComment,
    required this.lastUpdateTime,
    required this.respondTime,
    required this.weight,
    this.exploreUrl,
    this.exploreScreen,
    this.searchUrl,
    this.ruleExplore,
    this.ruleSearch,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
  });

  /// 是否可以搜索
  bool get hasSearch => searchUrl != null && ruleSearch != null;

  /// 是否可以发现
  bool get hasExplore => exploreUrl != null && ruleExplore != null;

  /// 是否需要登录
  bool get hasLogin => loginUrl != null && loginUrl!.isNotEmpty;

  /// 复制并修改部分字段
  BookSourceEntity copyWith({
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
    String? searchUrl,
    Map<String, dynamic>? ruleExplore,
    Map<String, dynamic>? ruleSearch,
    Map<String, dynamic>? ruleBookInfo,
    Map<String, dynamic>? ruleToc,
    Map<String, dynamic>? ruleContent,
  }) {
    return BookSourceEntity(
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
      searchUrl: searchUrl ?? this.searchUrl,
      ruleExplore: ruleExplore ?? this.ruleExplore,
      ruleSearch: ruleSearch ?? this.ruleSearch,
      ruleBookInfo: ruleBookInfo ?? this.ruleBookInfo,
      ruleToc: ruleToc ?? this.ruleToc,
      ruleContent: ruleContent ?? this.ruleContent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookSourceEntity && other.bookSourceUrl == bookSourceUrl;
  }

  @override
  int get hashCode => bookSourceUrl.hashCode;
}
