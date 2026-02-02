import 'package:json_annotation/json_annotation.dart';

// part 'book_source_rule.g.dart'; // 运行 build_runner 后取消注释

@JsonSerializable()
class SearchRule {
  @JsonKey(name: 'bookList')
  String? bookList;

  @JsonKey(name: 'name')
  String? name;

  @JsonKey(name: 'author')
  String? author;

  @JsonKey(name: 'kind')
  String? kind;

  @JsonKey(name: 'wordCount')
  String? wordCount;

  @JsonKey(name: 'lastChapter')
  String? lastChapter;

  @JsonKey(name: 'intro')
  String? intro;

  @JsonKey(name: 'coverUrl')
  String? coverUrl;

  @JsonKey(name: 'bookUrl')
  String? bookUrl;

  @JsonKey(name: 'checkKeyWord')
  String? checkKeyWord;

  SearchRule({
    this.bookList,
    this.name,
    this.author,
    this.kind,
    this.wordCount,
    this.lastChapter,
    this.intro,
    this.coverUrl,
    this.bookUrl,
    this.checkKeyWord,
  });

  factory SearchRule.fromJson(Map<String, dynamic> json) {
    return SearchRule(
      bookList: json['bookList'],
      name: json['name'],
      author: json['author'],
      kind: json['kind'],
      wordCount: json['wordCount'],
      lastChapter: json['lastChapter'],
      intro: json['intro'],
      coverUrl: json['coverUrl'],
      bookUrl: json['bookUrl'],
      checkKeyWord: json['checkKeyWord'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'bookList': bookList,
      'name': name,
      'author': author,
      'kind': kind,
      'wordCount': wordCount,
      'lastChapter': lastChapter,
      'intro': intro,
      'coverUrl': coverUrl,
      'bookUrl': bookUrl,
      'checkKeyWord': checkKeyWord,
    };
  }
}

@JsonSerializable()
class BookInfoRule {
  @JsonKey(name: 'init')
  String? init;

  @JsonKey(name: 'name')
  String? name;

  @JsonKey(name: 'author')
  String? author;

  @JsonKey(name: 'kind')
  String? kind;

  @JsonKey(name: 'wordCount')
  String? wordCount;

  @JsonKey(name: 'lastChapter')
  String? lastChapter;

  @JsonKey(name: 'intro')
  String? intro;

  @JsonKey(name: 'coverUrl')
  String? coverUrl;

  @JsonKey(name: 'tocUrl')
  String? tocUrl;

  @JsonKey(name: 'canReName')
  String? canReName;

  BookInfoRule({
    this.init,
    this.name,
    this.author,
    this.kind,
    this.wordCount,
    this.lastChapter,
    this.intro,
    this.coverUrl,
    this.tocUrl,
    this.canReName,
  });

  factory BookInfoRule.fromJson(Map<String, dynamic> json) {
    return BookInfoRule(
      init: json['init'],
      name: json['name'],
      author: json['author'],
      kind: json['kind'],
      wordCount: json['wordCount'],
      lastChapter: json['lastChapter'],
      intro: json['intro'],
      coverUrl: json['coverUrl'],
      tocUrl: json['tocUrl'],
      canReName: json['canReName'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'init': init,
      'name': name,
      'author': author,
      'kind': kind,
      'wordCount': wordCount,
      'lastChapter': lastChapter,
      'intro': intro,
      'coverUrl': coverUrl,
      'tocUrl': tocUrl,
      'canReName': canReName,
    };
  }
}

@JsonSerializable()
class TocRule {
  @JsonKey(name: 'preUpdateJs')
  String? preUpdateJs; // 解析目录前执行的JavaScript代码（参考项目支持）

  @JsonKey(name: 'chapterList')
  String? chapterList;

  @JsonKey(name: 'chapterName')
  String? chapterName;

  @JsonKey(name: 'chapterUrl')
  String? chapterUrl;

  @JsonKey(name: 'isVip')
  String? isVip;

  @JsonKey(name: 'isVolume')
  String? isVolume; // 卷名规则（参考项目支持）

  @JsonKey(name: 'updateTime')
  String? updateTime;

  @JsonKey(name: 'nextTocUrl')
  String? nextTocUrl;

  @JsonKey(name: 'formatJs')
  String? formatJs; // 格式化章节标题的JavaScript代码（参考项目支持）

  TocRule({
    this.preUpdateJs,
    this.chapterList,
    this.chapterName,
    this.chapterUrl,
    this.isVip,
    this.isVolume,
    this.updateTime,
    this.nextTocUrl,
    this.formatJs,
  });

  factory TocRule.fromJson(Map<String, dynamic> json) {
    return TocRule(
      preUpdateJs: json['preUpdateJs'],
      chapterList: json['chapterList'],
      chapterName: json['chapterName'],
      chapterUrl: json['chapterUrl'],
      isVip: json['isVip'],
      isVolume: json['isVolume'],
      updateTime: json['updateTime'],
      nextTocUrl: json['nextTocUrl'],
      formatJs: json['formatJs'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'preUpdateJs': preUpdateJs,
      'chapterList': chapterList,
      'chapterName': chapterName,
      'chapterUrl': chapterUrl,
      'isVip': isVip,
      'isVolume': isVolume,
      'updateTime': updateTime,
      'nextTocUrl': nextTocUrl,
      'formatJs': formatJs,
    };
  }
}

@JsonSerializable()
class ContentRule {
  @JsonKey(name: 'content')
  String? content;

  /// 漫画章节图片URL列表规则（可选）
  /// 优先于 [content] 提取图片列表，支持 CSS/XPath/JSONPath/JS/## 语法
  @JsonKey(name: 'images')
  String? images;

  @JsonKey(name: 'nextContentUrl')
  String? nextContentUrl;

  @JsonKey(name: 'webJs')
  String? webJs;

  @JsonKey(name: 'sourceRegex')
  String? sourceRegex;

  @JsonKey(name: 'replaceRegex')
  String? replaceRegex;

  @JsonKey(name: 'imageStyle')
  String? imageStyle;

  @JsonKey(name: 'imageDecode')
  String? imageDecode; // 图片解密JS

  ContentRule({
    this.content,
    this.images,
    this.nextContentUrl,
    this.webJs,
    this.sourceRegex,
    this.replaceRegex,
    this.imageStyle,
    this.imageDecode,
  });

  factory ContentRule.fromJson(Map<String, dynamic> json) {
    return ContentRule(
      content: json['content'],
      images: json['images'],
      nextContentUrl: json['nextContentUrl'],
      webJs: json['webJs'],
      sourceRegex: json['sourceRegex'],
      replaceRegex: json['replaceRegex'],
      imageStyle: json['imageStyle'],
      imageDecode: json['imageDecode'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'images': images,
      'nextContentUrl': nextContentUrl,
      'webJs': webJs,
      'sourceRegex': sourceRegex,
      'replaceRegex': replaceRegex,
      'imageStyle': imageStyle,
      'imageDecode': imageDecode,
    };
  }
}

@JsonSerializable()
class ExploreRule {
  @JsonKey(name: 'bookList')
  String? bookList;

  @JsonKey(name: 'name')
  String? name;

  @JsonKey(name: 'author')
  String? author;

  @JsonKey(name: 'kind')
  String? kind;

  @JsonKey(name: 'wordCount')
  String? wordCount;

  @JsonKey(name: 'lastChapter')
  String? lastChapter;

  @JsonKey(name: 'intro')
  String? intro;

  @JsonKey(name: 'coverUrl')
  String? coverUrl;

  @JsonKey(name: 'bookUrl')
  String? bookUrl;

  ExploreRule({
    this.bookList,
    this.name,
    this.author,
    this.kind,
    this.wordCount,
    this.lastChapter,
    this.intro,
    this.coverUrl,
    this.bookUrl,
  });

  factory ExploreRule.fromJson(Map<String, dynamic> json) {
    return ExploreRule(
      bookList: json['bookList'],
      name: json['name'],
      author: json['author'],
      kind: json['kind'],
      wordCount: json['wordCount'],
      lastChapter: json['lastChapter'],
      intro: json['intro'],
      coverUrl: json['coverUrl'],
      bookUrl: json['bookUrl'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'bookList': bookList,
      'name': name,
      'author': author,
      'kind': kind,
      'wordCount': wordCount,
      'lastChapter': lastChapter,
      'intro': intro,
      'coverUrl': coverUrl,
      'bookUrl': bookUrl,
    };
  }
}

