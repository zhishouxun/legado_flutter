import 'package:json_annotation/json_annotation.dart';
import '../../core/constants/app_status.dart';
import '../../utils/helpers/book_help.dart';
import 'book_chapter.dart';

// part 'book.g.dart'; // 运行 build_runner 后取消注释

/// 书籍类型
/// 参考项目：io.legado.app.constant.BookType
/// 注意：当前使用简单整数类型，如需支持多种类型组合，可使用 AppStatus 中的位标志类型
class BookType {
  // 简单类型（用于书源类型，不支持组合）
  static const int text = 0; // 文本
  static const int audio = 1; // 音频
  static const int image = 2; // 图片
  static const int file = 3; // 文件

  // 本地书籍标签
  static const String localTag = 'local';

  // WebDAV 标签前缀
  static const String webDavTag = 'webDav::';

  // ========== 位运算支持方法（可选，用于支持多种类型组合）==========
  /// 检查书籍类型是否包含指定类型（位运算）
  /// 使用 AppStatus 中的位标志类型
  static bool hasType(int bookType, int typeFlag) {
    return (bookType & typeFlag) != 0;
  }

  /// 添加书籍类型（位运算）
  static int addType(int bookType, int typeFlag) {
    return bookType | typeFlag;
  }

  /// 移除书籍类型（位运算）
  static int removeType(int bookType, int typeFlag) {
    return bookType & ~typeFlag;
  }

  /// 检查是否是文本类型
  static bool isText(int bookType) {
    return hasType(bookType, AppStatus.bookTypeText);
  }

  /// 检查是否是音频类型
  static bool isAudio(int bookType) {
    return hasType(bookType, AppStatus.bookTypeAudio);
  }

  /// 检查是否是图片类型
  static bool isImage(int bookType) {
    return hasType(bookType, AppStatus.bookTypeImage);
  }

  /// 检查是否是本地类型
  static bool isLocal(int bookType) {
    return hasType(bookType, AppStatus.bookTypeLocal);
  }

  /// 检查是否更新失败
  static bool isUpdateError(int bookType) {
    return hasType(bookType, AppStatus.bookTypeUpdateError);
  }
}

@JsonSerializable()
class Book {
  /// 详情页Url(本地书源存储完整文件路径)
  @JsonKey(name: 'bookUrl')
  final String bookUrl;

  /// 目录页Url
  @JsonKey(name: 'tocUrl')
  String tocUrl;

  /// 书源URL(默认BookType.local)
  @JsonKey(name: 'origin')
  String origin;

  /// 书源名称 or 本地书籍文件名
  @JsonKey(name: 'originName')
  String originName;

  /// 书籍名称
  @JsonKey(name: 'name')
  String name;

  /// 作者名称
  @JsonKey(name: 'author')
  String author;

  /// 分类信息(书源获取)
  @JsonKey(name: 'kind')
  String? kind;

  /// 分类信息(用户修改)
  @JsonKey(name: 'customTag')
  String? customTag;

  /// 封面Url(书源获取)
  @JsonKey(name: 'coverUrl')
  String? coverUrl;

  /// 封面Url(用户修改)
  @JsonKey(name: 'customCoverUrl')
  String? customCoverUrl;

  /// 简介内容(书源获取)
  @JsonKey(name: 'intro')
  String? intro;

  /// 简介内容(用户修改)
  @JsonKey(name: 'customIntro')
  String? customIntro;

  /// 自定义字符集名称(仅适用于本地书籍)
  @JsonKey(name: 'charset')
  String? charset;

  /// 类型
  @JsonKey(name: 'type')
  int type;

  /// 自定义分组索引号
  @JsonKey(name: 'group')
  int group;

  /// 最新章节标题
  @JsonKey(name: 'latestChapterTitle')
  String? latestChapterTitle;

  /// 最新章节标题更新时间
  @JsonKey(name: 'latestChapterTime')
  int latestChapterTime;

  /// 最近一次更新书籍信息的时间
  @JsonKey(name: 'lastCheckTime')
  int lastCheckTime;

  /// 最近一次发现新章节的数量
  @JsonKey(name: 'lastCheckCount')
  int lastCheckCount;

  /// 书籍目录总数
  @JsonKey(name: 'totalChapterNum')
  int totalChapterNum;

  /// 当前章节名称
  @JsonKey(name: 'durChapterTitle')
  String? durChapterTitle;

  /// 当前章节索引
  @JsonKey(name: 'durChapterIndex')
  int durChapterIndex;

  /// 当前阅读的进度(首行字符的索引位置)
  @JsonKey(name: 'durChapterPos')
  int durChapterPos;

  /// 最近一次阅读书籍的时间
  @JsonKey(name: 'durChapterTime')
  int durChapterTime;

  /// 字数
  @JsonKey(name: 'wordCount')
  String? wordCount;

  /// 刷新书架时更新书籍信息
  @JsonKey(name: 'canUpdate')
  bool canUpdate;

  /// 手动排序
  @JsonKey(name: 'order')
  int order;

  /// 书源排序
  @JsonKey(name: 'originOrder')
  int originOrder;

  /// 自定义书籍变量信息
  @JsonKey(name: 'variable')
  String? variable;

  /// 阅读设置
  @JsonKey(name: 'readConfig')
  ReadConfig? readConfig;

  /// 同步时间
  @JsonKey(name: 'syncTime')
  int syncTime;

  Book({
    required this.bookUrl,
    this.tocUrl = '',
    this.origin = BookType.localTag,
    this.originName = '',
    this.name = '',
    this.author = '',
    this.kind,
    this.customTag,
    this.coverUrl,
    this.customCoverUrl,
    this.intro,
    this.customIntro,
    this.charset,
    this.type = BookType.text,
    this.group = 0,
    this.latestChapterTitle,
    int? latestChapterTime,
    int? lastCheckTime,
    this.lastCheckCount = 0,
    this.totalChapterNum = 0,
    this.durChapterTitle,
    this.durChapterIndex = 0,
    this.durChapterPos = 0,
    int? durChapterTime,
    this.wordCount,
    this.canUpdate = true,
    this.order = 0,
    this.originOrder = 0,
    this.variable,
    this.readConfig,
    this.syncTime = 0,
  })  : latestChapterTime =
            latestChapterTime ?? DateTime.now().millisecondsSinceEpoch,
        lastCheckTime = lastCheckTime ?? DateTime.now().millisecondsSinceEpoch,
        durChapterTime =
            durChapterTime ?? DateTime.now().millisecondsSinceEpoch;

  factory Book.fromJson(Map<String, dynamic> json) {
    // TODO: 使用 json_serializable 生成代码后取消注释
    // return _$BookFromJson(json);
    return Book(
      bookUrl: json['bookUrl'] ?? '',
      tocUrl: json['tocUrl'] ?? '',
      origin: json['origin'] ?? BookType.localTag,
      originName: json['originName'] ?? '',
      name: json['name'] ?? '',
      author: json['author'] ?? '',
      kind: json['kind'],
      customTag: json['customTag'],
      coverUrl: json['coverUrl'],
      customCoverUrl: json['customCoverUrl'],
      intro: json['intro'],
      customIntro: json['customIntro'],
      charset: json['charset'],
      type: json['type'] ?? BookType.text,
      group: json['group'] ?? 0,
      latestChapterTitle: json['latestChapterTitle'],
      latestChapterTime: json['latestChapterTime'],
      lastCheckTime: json['lastCheckTime'],
      lastCheckCount: json['lastCheckCount'] ?? 0,
      totalChapterNum: json['totalChapterNum'] ?? 0,
      durChapterTitle: json['durChapterTitle'],
      durChapterIndex: json['durChapterIndex'] ?? 0,
      durChapterPos: json['durChapterPos'] ?? 0,
      durChapterTime: json['durChapterTime'],
      wordCount: json['wordCount'],
      canUpdate: json['canUpdate'] ?? true,
      order: json['order'] ?? 0,
      originOrder: json['originOrder'] ?? 0,
      variable: json['variable'],
      readConfig: json['readConfig'] != null
          ? ReadConfig.fromJson(json['readConfig'])
          : null,
      syncTime: json['syncTime'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    // TODO: 使用 json_serializable 生成代码后取消注释
    // return _$BookToJson(this);
    return {
      'bookUrl': bookUrl,
      'tocUrl': tocUrl,
      'origin': origin,
      'originName': originName,
      'name': name,
      'author': author,
      'kind': kind,
      'customTag': customTag,
      'coverUrl': coverUrl,
      'customCoverUrl': customCoverUrl,
      'intro': intro,
      'customIntro': customIntro,
      'charset': charset,
      'type': type,
      'group': group,
      'latestChapterTitle': latestChapterTitle,
      'latestChapterTime': latestChapterTime,
      'lastCheckTime': lastCheckTime,
      'lastCheckCount': lastCheckCount,
      'totalChapterNum': totalChapterNum,
      'durChapterTitle': durChapterTitle,
      'durChapterIndex': durChapterIndex,
      'durChapterPos': durChapterPos,
      'durChapterTime': durChapterTime,
      'wordCount': wordCount,
      'canUpdate': canUpdate,
      'order': order,
      'originOrder': originOrder,
      'variable': variable,
      'readConfig': readConfig?.toJson(),
      'syncTime': syncTime,
    };
  }

  /// 获取显示名称
  String get displayName => name.isNotEmpty ? name : '未知书籍';

  /// 获取显示作者
  String get displayAuthor => author.isNotEmpty ? author : '未知作者';

  /// 获取显示封面
  String? get displayCover => customCoverUrl ?? coverUrl;

  /// 获取显示简介
  String? get displayIntro => customIntro ?? intro;

  /// 是否本地书籍
  bool get isLocal => origin == BookType.localTag;

  /// 复制并更新
  Book copyWith({
    String? bookUrl,
    String? tocUrl,
    String? origin,
    String? originName,
    String? name,
    String? author,
    String? kind,
    String? customTag,
    String? coverUrl,
    String? customCoverUrl,
    String? intro,
    String? customIntro,
    String? charset,
    int? type,
    int? group,
    String? latestChapterTitle,
    int? latestChapterTime,
    int? lastCheckTime,
    int? lastCheckCount,
    int? totalChapterNum,
    String? durChapterTitle,
    int? durChapterIndex,
    int? durChapterPos,
    int? durChapterTime,
    String? wordCount,
    bool? canUpdate,
    int? order,
    int? originOrder,
    String? variable,
    ReadConfig? readConfig,
    int? syncTime,
  }) {
    return Book(
      bookUrl: bookUrl ?? this.bookUrl,
      tocUrl: tocUrl ?? this.tocUrl,
      origin: origin ?? this.origin,
      originName: originName ?? this.originName,
      name: name ?? this.name,
      author: author ?? this.author,
      kind: kind ?? this.kind,
      customTag: customTag ?? this.customTag,
      coverUrl: coverUrl ?? this.coverUrl,
      customCoverUrl: customCoverUrl ?? this.customCoverUrl,
      intro: intro ?? this.intro,
      customIntro: customIntro ?? this.customIntro,
      charset: charset ?? this.charset,
      type: type ?? this.type,
      group: group ?? this.group,
      latestChapterTitle: latestChapterTitle ?? this.latestChapterTitle,
      latestChapterTime: latestChapterTime ?? this.latestChapterTime,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      lastCheckCount: lastCheckCount ?? this.lastCheckCount,
      totalChapterNum: totalChapterNum ?? this.totalChapterNum,
      durChapterTitle: durChapterTitle ?? this.durChapterTitle,
      durChapterIndex: durChapterIndex ?? this.durChapterIndex,
      durChapterPos: durChapterPos ?? this.durChapterPos,
      durChapterTime: durChapterTime ?? this.durChapterTime,
      wordCount: wordCount ?? this.wordCount,
      canUpdate: canUpdate ?? this.canUpdate,
      order: order ?? this.order,
      originOrder: originOrder ?? this.originOrder,
      variable: variable ?? this.variable,
      readConfig: readConfig ?? this.readConfig,
      syncTime: syncTime ?? this.syncTime,
    );
  }

  /// 迁移旧书籍的信息到新书籍中
  /// 参考项目：io.legado.app.data.entities.Book.migrateTo
  ///
  /// 用于换源时，将旧书籍的阅读进度、分组、自定义信息等迁移到新书籍
  ///
  /// [newBook] 新书籍对象
  /// [toc] 新书籍的章节列表
  ///
  /// 返回更新后的新书籍对象
  Book migrateTo(Book newBook, List<BookChapter> toc) {
    // 使用章节定位算法找到对应的章节索引
    final newDurChapterIndex = BookHelp.getDurChapter(
      durChapterIndex,
      durChapterTitle,
      toc,
      totalChapterNum,
    );

    // 获取新章节的标题
    String? newDurChapterTitle;
    if (toc.isNotEmpty && newDurChapterIndex < toc.length) {
      newDurChapterTitle = toc[newDurChapterIndex].title;
    }

    // 更新新书籍的阅读进度和用户设置
    newBook.durChapterIndex = newDurChapterIndex;
    newBook.durChapterTitle = newDurChapterTitle;
    newBook.durChapterPos = durChapterPos;
    newBook.durChapterTime = durChapterTime;
    newBook.group = group;
    newBook.order = order;
    newBook.customCoverUrl = customCoverUrl;
    newBook.customIntro = customIntro;
    newBook.customTag = customTag;
    newBook.canUpdate = canUpdate;
    newBook.readConfig = readConfig;

    return newBook;
  }
}

@JsonSerializable()
class ReadConfig {
  @JsonKey(name: 'fontSize')
  double fontSize;

  @JsonKey(name: 'lineHeight')
  double lineHeight;

  @JsonKey(name: 'paragraphSpacing')
  double paragraphSpacing;

  @JsonKey(name: 'letterSpacing')
  double letterSpacing; // 字距

  @JsonKey(name: 'paragraphIndent')
  String paragraphIndent; // 段落缩进（使用全角空格"　"）

  @JsonKey(name: 'fontFamily')
  String? fontFamily;

  @JsonKey(name: 'textColor')
  int textColor;

  @JsonKey(name: 'backgroundColor')
  int backgroundColor;

  @JsonKey(name: 'bold')
  bool bold;

  @JsonKey(name: 'fontWeight')
  int fontWeight; // 0: 细, 1: 中, 2: 粗

  @JsonKey(name: 'paddingHorizontal')
  double paddingHorizontal;

  @JsonKey(name: 'paddingVertical')
  double paddingVertical;

  // 正文边距
  @JsonKey(name: 'paddingTop')
  double paddingTop;

  @JsonKey(name: 'paddingBottom')
  double paddingBottom;

  @JsonKey(name: 'paddingLeft')
  double paddingLeft;

  @JsonKey(name: 'paddingRight')
  double paddingRight;

  // 页眉边距
  @JsonKey(name: 'headerPaddingTop')
  double headerPaddingTop;

  @JsonKey(name: 'headerPaddingBottom')
  double headerPaddingBottom;

  @JsonKey(name: 'headerPaddingLeft')
  double headerPaddingLeft;

  @JsonKey(name: 'headerPaddingRight')
  double headerPaddingRight;

  @JsonKey(name: 'showHeaderLine')
  bool showHeaderLine;

  // 页脚边距
  @JsonKey(name: 'footerPaddingTop')
  double footerPaddingTop;

  @JsonKey(name: 'footerPaddingBottom')
  double footerPaddingBottom;

  @JsonKey(name: 'footerPaddingLeft')
  double footerPaddingLeft;

  @JsonKey(name: 'footerPaddingRight')
  double footerPaddingRight;

  @JsonKey(name: 'showFooterLine')
  bool showFooterLine;

  @JsonKey(name: 'pageMode')
  int pageMode; // 0: 滚动模式, 1: 翻页模式

  @JsonKey(name: 'pageAnimation')
  int pageAnimation; // 0: 覆盖, 1: 滑动, 2: 仿真, 3: 滚动, 4: 无动画

  @JsonKey(name: 'styleName')
  String? styleName; // 样式名称

  @JsonKey(name: 'darkStatusIcon')
  bool darkStatusIcon; // 深色状态栏图标

  @JsonKey(name: 'underline')
  bool underline; // 文字下划线

  @JsonKey(name: 'bgAlpha')
  int bgAlpha; // 背景透明度 (0-100)

  @JsonKey(name: 'bgImage')
  String? bgImage; // 背景图片路径或名称

  // 正文标题设置
  @JsonKey(name: 'titleMode')
  int titleMode; // 0: 靠左, 1: 居中, 2: 隐藏

  @JsonKey(name: 'titleSize')
  int titleSize; // 标题字号（相对值，0为基础）

  @JsonKey(name: 'titleTopSpacing')
  int titleTopSpacing; // 标题上边距

  @JsonKey(name: 'titleBottomSpacing')
  int titleBottomSpacing; // 标题下边距

  // 页眉页脚提示信息
  @JsonKey(name: 'tipHeaderLeft')
  int tipHeaderLeft; // 页眉左侧内容类型

  @JsonKey(name: 'tipHeaderMiddle')
  int tipHeaderMiddle; // 页眉中间内容类型

  @JsonKey(name: 'tipHeaderRight')
  int tipHeaderRight; // 页眉右侧内容类型

  @JsonKey(name: 'tipFooterLeft')
  int tipFooterLeft; // 页脚左侧内容类型

  @JsonKey(name: 'tipFooterMiddle')
  int tipFooterMiddle; // 页脚中间内容类型

  @JsonKey(name: 'tipFooterRight')
  int tipFooterRight; // 页脚右侧内容类型

  @JsonKey(name: 'tipColor')
  int tipColor; // 页眉页脚文字颜色（0: 跟随正文，其他: 自定义颜色值）

  @JsonKey(name: 'tipDividerColor')
  int tipDividerColor; // 分隔线颜色（-1: 默认, 0: 跟随内容, 其他: 自定义颜色值）

  @JsonKey(name: 'headerMode')
  int headerMode; // 页眉显示模式（0: 状态栏显示时隐藏, 1: 显示, 2: 隐藏）

  @JsonKey(name: 'footerMode')
  int footerMode; // 页脚显示模式（0: 显示, 1: 隐藏）

  // ========== 模拟阅读相关 ==========
  @JsonKey(name: 'simulateReading')
  bool? simulateReading; // 是否启用模拟阅读

  @JsonKey(name: 'simulateStartDate')
  DateTime? simulateStartDate; // 模拟阅读开始日期（时间戳，毫秒）

  @JsonKey(name: 'simulateChaptersPerDay')
  int? simulateChaptersPerDay; // 每天解锁的章节数

  // ========== 内容处理相关 ==========
  @JsonKey(name: 'useReplaceRule')
  bool useReplaceRule; // 是否使用替换规则

  @JsonKey(name: 'reSegment')
  bool reSegment; // 是否重新分段

  ReadConfig({
    this.fontSize = 18.0,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 1.0,
    this.letterSpacing = 0.0,
    this.paragraphIndent = '　　', // 默认两字符缩进
    this.fontFamily,
    this.textColor = 0xFF000000,
    this.backgroundColor = 0xFFFFFFFF,
    this.bold = false,
    this.fontWeight = 1, // 默认中等
    this.paddingHorizontal = 20.0,
    this.paddingVertical = 30.0,
    // 正文边距
    this.paddingTop = 6.0,
    this.paddingBottom = 6.0,
    this.paddingLeft = 16.0,
    this.paddingRight = 16.0,
    // 页眉边距
    this.headerPaddingTop = 8.0,
    this.headerPaddingBottom = 8.0,
    this.headerPaddingLeft = 8.0,
    this.headerPaddingRight = 8.0,
    this.showHeaderLine = false,
    // 页脚边距
    this.footerPaddingTop = 8.0,
    this.footerPaddingBottom = 8.0,
    this.footerPaddingLeft = 8.0,
    this.footerPaddingRight = 8.0,
    this.showFooterLine = true,
    this.pageMode = AppStatus.pageModePage, // 默认翻页模式
    this.pageAnimation = AppStatus.pageAnimCover, // 默认覆盖动画
    this.styleName,
    this.darkStatusIcon = false,
    this.underline = false,
    this.bgAlpha = 100,
    this.bgImage,
    // 正文标题设置
    this.titleMode = 0, // 默认靠左
    this.titleSize = 0, // 默认字号
    this.titleTopSpacing = 0, // 默认上边距
    this.titleBottomSpacing = 0, // 默认下边距
    // 页眉页脚提示信息（参考 ReadTipConfig 常量）
    this.tipHeaderLeft = 2, // 默认时间
    this.tipHeaderMiddle = 0, // 默认无
    this.tipHeaderRight = 3, // 默认电量
    this.tipFooterLeft = 1, // 默认标题
    this.tipFooterMiddle = 0, // 默认无
    this.tipFooterRight = 6, // 默认页数及进度
    this.tipColor = 0, // 默认跟随正文
    this.tipDividerColor = -1, // 默认
    this.headerMode = 0, // 默认状态栏显示时隐藏
    this.footerMode = 0, // 默认显示
    // 模拟阅读相关
    this.simulateReading = false, // 默认不启用
    this.simulateStartDate, // 默认无开始日期
    this.simulateChaptersPerDay = 1, // 默认每天解锁1章
    // 内容处理相关
    this.useReplaceRule = true, // 默认启用替换规则
    this.reSegment = false, // 默认不重新分段
  });

  factory ReadConfig.fromJson(Map<String, dynamic> json) {
    return ReadConfig(
      fontSize: (json['fontSize'] ?? 18.0).toDouble(),
      lineHeight: (json['lineHeight'] ?? 1.6).toDouble(),
      paragraphSpacing: (json['paragraphSpacing'] ?? 1.0).toDouble(),
      letterSpacing: (json['letterSpacing'] ?? 0.0).toDouble(),
      paragraphIndent: json['paragraphIndent'] ?? '　　',
      fontFamily: json['fontFamily'],
      textColor: _parseColor(json['textColor']) ?? 0xFF000000,
      backgroundColor: _parseColor(json['backgroundColor']) ?? 0xFFFFFFFF,
      bold: json['bold'] ?? false,
      fontWeight: json['fontWeight'] ?? 1,
      paddingHorizontal: (json['paddingHorizontal'] ?? 20.0).toDouble(),
      paddingVertical: (json['paddingVertical'] ?? 30.0).toDouble(),
      pageMode: json['pageMode'] ?? AppStatus.pageModePage,
      pageAnimation: json['pageAnimation'] ?? AppStatus.pageAnimCover,
      styleName: json['styleName'],
      darkStatusIcon: json['darkStatusIcon'] ?? false,
      underline: json['underline'] ?? false,
      bgAlpha: json['bgAlpha'] ?? 100,
      bgImage: json['bgImage'],
      // 正文标题设置
      titleMode: json['titleMode'] ?? 0,
      titleSize: json['titleSize'] ?? 0,
      titleTopSpacing: json['titleTopSpacing'] ?? 0,
      titleBottomSpacing: json['titleBottomSpacing'] ?? 0,
      // 页眉页脚提示信息
      tipHeaderLeft: json['tipHeaderLeft'] ?? 2,
      tipHeaderMiddle: json['tipHeaderMiddle'] ?? 0,
      tipHeaderRight: json['tipHeaderRight'] ?? 3,
      tipFooterLeft: json['tipFooterLeft'] ?? 1,
      tipFooterMiddle: json['tipFooterMiddle'] ?? 0,
      tipFooterRight: json['tipFooterRight'] ?? 6,
      tipColor: json['tipColor'] ?? 0,
      tipDividerColor: json['tipDividerColor'] ?? -1,
      headerMode: json['headerMode'] ?? 0,
      footerMode: json['footerMode'] ?? 0,
      // 模拟阅读相关
      simulateReading: json['simulateReading'] == null
          ? false
          : (json['simulateReading'] is bool
              ? json['simulateReading'] as bool
              : json['simulateReading'] == 1),
      // 内容处理相关
      useReplaceRule: json['useReplaceRule'] ?? true,
      reSegment: json['reSegment'] ?? false,
      simulateStartDate: json['simulateStartDate'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['simulateStartDate'] is int
              ? json['simulateStartDate'] as int
              : int.tryParse(json['simulateStartDate'].toString()) ?? 0),
      simulateChaptersPerDay: json['simulateChaptersPerDay'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'paragraphSpacing': paragraphSpacing,
      'letterSpacing': letterSpacing,
      'paragraphIndent': paragraphIndent,
      'fontFamily': fontFamily,
      'textColor': textColor,
      'backgroundColor': backgroundColor,
      'bold': bold,
      'fontWeight': fontWeight,
      'paddingHorizontal': paddingHorizontal,
      'paddingVertical': paddingVertical,
      // 正文边距
      'paddingTop': paddingTop,
      'paddingBottom': paddingBottom,
      'paddingLeft': paddingLeft,
      'paddingRight': paddingRight,
      // 页眉边距
      'headerPaddingTop': headerPaddingTop,
      'headerPaddingBottom': headerPaddingBottom,
      'headerPaddingLeft': headerPaddingLeft,
      'headerPaddingRight': headerPaddingRight,
      'showHeaderLine': showHeaderLine,
      // 页脚边距
      'footerPaddingTop': footerPaddingTop,
      'footerPaddingBottom': footerPaddingBottom,
      'footerPaddingLeft': footerPaddingLeft,
      'footerPaddingRight': footerPaddingRight,
      'showFooterLine': showFooterLine,
      'pageMode': pageMode,
      'pageAnimation': pageAnimation,
      'styleName': styleName,
      'darkStatusIcon': darkStatusIcon,
      'underline': underline,
      'bgAlpha': bgAlpha,
      'bgImage': bgImage,
      // 正文标题设置
      'titleMode': titleMode,
      'titleSize': titleSize,
      'titleTopSpacing': titleTopSpacing,
      'titleBottomSpacing': titleBottomSpacing,
      // 页眉页脚提示信息
      'tipHeaderLeft': tipHeaderLeft,
      'tipHeaderMiddle': tipHeaderMiddle,
      'tipHeaderRight': tipHeaderRight,
      'tipFooterLeft': tipFooterLeft,
      'tipFooterMiddle': tipFooterMiddle,
      'tipFooterRight': tipFooterRight,
      'tipColor': tipColor,
      'tipDividerColor': tipDividerColor,
      'headerMode': headerMode,
      'footerMode': footerMode,
      // 模拟阅读相关
      'simulateReading': simulateReading ?? false,
      'simulateStartDate': simulateStartDate?.millisecondsSinceEpoch,
      'simulateChaptersPerDay': simulateChaptersPerDay ?? 1,
      // 内容处理相关
      'useReplaceRule': useReplaceRule,
      'reSegment': reSegment,
    };
  }

  ReadConfig copyWith({
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? letterSpacing,
    String? paragraphIndent,
    String? fontFamily,
    int? textColor,
    int? backgroundColor,
    bool? bold,
    int? fontWeight,
    double? paddingHorizontal,
    double? paddingVertical,
    // 正文边距
    double? paddingTop,
    double? paddingBottom,
    double? paddingLeft,
    double? paddingRight,
    // 页眉边距
    double? headerPaddingTop,
    double? headerPaddingBottom,
    double? headerPaddingLeft,
    double? headerPaddingRight,
    bool? showHeaderLine,
    // 页脚边距
    double? footerPaddingTop,
    double? footerPaddingBottom,
    double? footerPaddingLeft,
    double? footerPaddingRight,
    bool? showFooterLine,
    int? pageMode,
    int? pageAnimation,
    String? styleName,
    bool? darkStatusIcon,
    bool? underline,
    int? bgAlpha,
    String? bgImage,
    // 正文标题设置
    int? titleMode,
    int? titleSize,
    int? titleTopSpacing,
    int? titleBottomSpacing,
    // 页眉页脚提示信息
    int? tipHeaderLeft,
    int? tipHeaderMiddle,
    int? tipHeaderRight,
    int? tipFooterLeft,
    int? tipFooterMiddle,
    int? tipFooterRight,
    int? tipColor,
    int? tipDividerColor,
    int? headerMode,
    int? footerMode,
    // 模拟阅读相关
    bool? simulateReading,
    DateTime? simulateStartDate,
    int? simulateChaptersPerDay,
    bool? useReplaceRule,
    bool? reSegment,
  }) {
    return ReadConfig(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      fontFamily: fontFamily ?? this.fontFamily,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      bold: bold ?? this.bold,
      fontWeight: fontWeight ?? this.fontWeight,
      paddingHorizontal: paddingHorizontal ?? this.paddingHorizontal,
      paddingVertical: paddingVertical ?? this.paddingVertical,
      // 正文边距
      paddingTop: paddingTop ?? this.paddingTop,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingRight: paddingRight ?? this.paddingRight,
      // 页眉边距
      headerPaddingTop: headerPaddingTop ?? this.headerPaddingTop,
      headerPaddingBottom: headerPaddingBottom ?? this.headerPaddingBottom,
      headerPaddingLeft: headerPaddingLeft ?? this.headerPaddingLeft,
      headerPaddingRight: headerPaddingRight ?? this.headerPaddingRight,
      showHeaderLine: showHeaderLine ?? this.showHeaderLine,
      // 页脚边距
      footerPaddingTop: footerPaddingTop ?? this.footerPaddingTop,
      footerPaddingBottom: footerPaddingBottom ?? this.footerPaddingBottom,
      footerPaddingLeft: footerPaddingLeft ?? this.footerPaddingLeft,
      footerPaddingRight: footerPaddingRight ?? this.footerPaddingRight,
      showFooterLine: showFooterLine ?? this.showFooterLine,
      pageMode: pageMode ?? this.pageMode,
      pageAnimation: pageAnimation ?? this.pageAnimation,
      styleName: styleName ?? this.styleName,
      darkStatusIcon: darkStatusIcon ?? this.darkStatusIcon,
      underline: underline ?? this.underline,
      bgAlpha: bgAlpha ?? this.bgAlpha,
      bgImage: bgImage ?? this.bgImage,
      // 正文标题设置
      titleMode: titleMode ?? this.titleMode,
      titleSize: titleSize ?? this.titleSize,
      titleTopSpacing: titleTopSpacing ?? this.titleTopSpacing,
      titleBottomSpacing: titleBottomSpacing ?? this.titleBottomSpacing,
      // 页眉页脚提示信息
      tipHeaderLeft: tipHeaderLeft ?? this.tipHeaderLeft,
      tipHeaderMiddle: tipHeaderMiddle ?? this.tipHeaderMiddle,
      tipHeaderRight: tipHeaderRight ?? this.tipHeaderRight,
      tipFooterLeft: tipFooterLeft ?? this.tipFooterLeft,
      tipFooterMiddle: tipFooterMiddle ?? this.tipFooterMiddle,
      tipFooterRight: tipFooterRight ?? this.tipFooterRight,
      tipColor: tipColor ?? this.tipColor,
      tipDividerColor: tipDividerColor ?? this.tipDividerColor,
      headerMode: headerMode ?? this.headerMode,
      footerMode: footerMode ?? this.footerMode,
      // 模拟阅读相关
      simulateReading: simulateReading ?? this.simulateReading,
      simulateStartDate: simulateStartDate ?? this.simulateStartDate,
      simulateChaptersPerDay:
          simulateChaptersPerDay ?? this.simulateChaptersPerDay,
      useReplaceRule: useReplaceRule ?? this.useReplaceRule,
      reSegment: reSegment ?? this.reSegment,
    );
  }

  /// 获取布局相关的配置（用于共用布局）
  ReadConfig getLayoutConfig() {
    return ReadConfig(
      fontSize: fontSize,
      lineHeight: lineHeight,
      paragraphSpacing: paragraphSpacing,
      letterSpacing: letterSpacing,
      paragraphIndent: paragraphIndent,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      bold: bold,
      paddingHorizontal: paddingHorizontal,
      paddingVertical: paddingVertical,
      pageMode: pageMode,
      pageAnimation: pageAnimation,
      // 不包含颜色配置
      textColor: 0xFF000000,
      backgroundColor: 0xFFFFFFFF,
    );
  }

  /// 应用布局配置（用于共用布局）
  ReadConfig applyLayoutConfig(ReadConfig layoutConfig) {
    return ReadConfig(
      fontSize: layoutConfig.fontSize,
      lineHeight: layoutConfig.lineHeight,
      paragraphSpacing: layoutConfig.paragraphSpacing,
      letterSpacing: layoutConfig.letterSpacing,
      fontFamily: layoutConfig.fontFamily,
      fontWeight: layoutConfig.fontWeight,
      bold: layoutConfig.bold,
      paddingHorizontal: layoutConfig.paddingHorizontal,
      paddingVertical: layoutConfig.paddingVertical,
      pageMode: layoutConfig.pageMode,
      pageAnimation: layoutConfig.pageAnimation,
      // 保留当前的颜色配置
      textColor: textColor,
      backgroundColor: backgroundColor,
    );
  }

  /// 解析颜色值，支持字符串格式（如"#FFFFFF"）和整数格式
  static int? _parseColor(dynamic color) {
    if (color == null) return null;
    if (color is int) return color;
    if (color is String) {
      try {
        // 移除 # 号并添加 0xFF 前缀
        String colorStr = color.replaceAll('#', '');
        // 如果没有透明度，添加 FF（完全不透明）
        if (colorStr.length == 6) {
          colorStr = 'FF$colorStr';
        }
        return int.parse(colorStr, radix: 16);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
