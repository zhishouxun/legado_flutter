import 'package:legado_flutter/domain/entities/book_entity.dart';
import 'package:legado_flutter/domain/entities/book_source_entity.dart';
import 'package:legado_flutter/domain/entities/chapter_entity.dart';

/// 测试辅助函数 - 创建测试用的Entity对象

BookEntity createTestBookEntity({
  String bookUrl = 'https://test.com/book1',
  String name = '测试书籍',
  String author = '测试作者',
  int group = 0,
  int durChapterTime = 0,
  int latestChapterTime = 0,
}) {
  return BookEntity(
    bookUrl: bookUrl,
    tocUrl: '$bookUrl/toc',
    origin: 'https://test.com',
    originName: '测试书源',
    name: name,
    author: author,
    kind: '玄幻',
    customTag: null,
    coverUrl: '$bookUrl/cover.jpg',
    customCoverUrl: null,
    intro: '这是一本测试书籍',
    customIntro: null,
    charset: null,
    type: 0,
    group: group,
    latestChapterTitle: '第1章',
    latestChapterTime: latestChapterTime,
    lastCheckTime: 0,
    lastCheckCount: 0,
    totalChapterNum: 100,
    durChapterTitle: '第1章',
    durChapterIndex: 0,
    durChapterPos: 0,
    durChapterTime: durChapterTime,
    wordCount: '100万字',
    canUpdate: true,
    order: 0,
    originOrder: 0,
    variable: null,
    syncTime: 0,
  );
}

BookSourceEntity createTestBookSourceEntity({
  String bookSourceUrl = 'https://source.com',
  String bookSourceName = '测试书源',
  bool enabled = true,
}) {
  return BookSourceEntity(
    bookSourceUrl: bookSourceUrl,
    bookSourceName: bookSourceName,
    bookSourceGroup: '测试',
    bookSourceType: 0,
    enabled: enabled,
    enabledExplore: true,
    enabledCookieJar: false,
    concurrentRate: '',
    header: '',
    loginUrl: '',
    loginUi: '',
    loginCheckJs: '',
    bookUrlPattern: '',
    coverDecodeJs: '',
    bookSourceComment: '',
    lastUpdateTime: 0,
    respondTime: 0,
    weight: 0,
    exploreUrl: '',
    ruleExplore: null,
    searchUrl: '$bookSourceUrl/search',
    ruleSearch: null,
    ruleBookInfo: null,
    ruleToc: null,
    ruleContent: null,
    customOrder: 0,
  );
}

ChapterEntity createTestChapterEntity({
  String bookUrl = 'https://test.com/book1',
  String url = 'https://test.com/book1/chapter1',
  String title = '第1章',
  int index = 0,
}) {
  return ChapterEntity(
    bookUrl: bookUrl,
    url: url,
    title: title,
    index: index,
    isVolume: false,
    baseUrl: '',
    bookmarkText: null,
    isVip: false,
    isPay: false,
    resourceUrl: null,
    tag: null,
    start: null,
    end: null,
    startFragmentId: null,
    endFragmentId: null,
    variable: null,
  );
}
