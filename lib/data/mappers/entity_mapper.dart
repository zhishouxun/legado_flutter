import '../../domain/entities/book_entity.dart';
import '../../domain/entities/book_source_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../models/book.dart';
import '../models/book_chapter.dart';
import '../models/book_source.dart';
import '../models/book_source_rule.dart';

/// Domain Entity 与 Data Model 之间的映射器
/// 参考：Clean Architecture - Data Mapper Pattern
class EntityMapper {
  /// Book Model -> Entity
  static BookEntity bookToEntity(Book model) {
    return BookEntity(
      bookUrl: model.bookUrl,
      tocUrl: model.tocUrl,
      origin: model.origin,
      originName: model.originName,
      name: model.name,
      author: model.author,
      kind: model.kind,
      customTag: model.customTag,
      coverUrl: model.coverUrl,
      customCoverUrl: model.customCoverUrl,
      intro: model.intro,
      customIntro: model.customIntro,
      charset: model.charset,
      type: model.type,
      group: model.group,
      latestChapterTitle: model.latestChapterTitle,
      latestChapterTime: model.latestChapterTime,
      lastCheckTime: model.lastCheckTime,
      lastCheckCount: model.lastCheckCount,
      totalChapterNum: model.totalChapterNum,
      durChapterTitle: model.durChapterTitle,
      durChapterIndex: model.durChapterIndex,
      durChapterPos: model.durChapterPos,
      durChapterTime: model.durChapterTime,
      wordCount: model.wordCount,
      canUpdate: model.canUpdate,
      order: model.order,
      originOrder: model.originOrder,
      variable: model.variable,
      syncTime: model.syncTime,
    );
  }

  /// Book Entity -> Model
  static Book bookFromEntity(BookEntity entity) {
    return Book(
      bookUrl: entity.bookUrl,
      tocUrl: entity.tocUrl,
      origin: entity.origin,
      originName: entity.originName,
      name: entity.name,
      author: entity.author,
      kind: entity.kind,
      customTag: entity.customTag,
      coverUrl: entity.coverUrl,
      customCoverUrl: entity.customCoverUrl,
      intro: entity.intro,
      customIntro: entity.customIntro,
      charset: entity.charset,
      type: entity.type,
      group: entity.group,
      latestChapterTitle: entity.latestChapterTitle,
      latestChapterTime: entity.latestChapterTime,
      lastCheckTime: entity.lastCheckTime,
      lastCheckCount: entity.lastCheckCount,
      totalChapterNum: entity.totalChapterNum,
      durChapterTitle: entity.durChapterTitle,
      durChapterIndex: entity.durChapterIndex,
      durChapterPos: entity.durChapterPos,
      durChapterTime: entity.durChapterTime,
      wordCount: entity.wordCount,
      canUpdate: entity.canUpdate,
      order: entity.order,
      originOrder: entity.originOrder,
      variable: entity.variable,
      syncTime: entity.syncTime,
    );
  }

  /// BookSource Model -> Entity
  static BookSourceEntity bookSourceToEntity(BookSource model) {
    return BookSourceEntity(
      bookSourceUrl: model.bookSourceUrl,
      bookSourceName: model.bookSourceName,
      bookSourceGroup: model.bookSourceGroup,
      bookSourceType: model.bookSourceType,
      bookUrlPattern: model.bookUrlPattern,
      customOrder: model.customOrder,
      enabled: model.enabled,
      enabledExplore: model.enabledExplore,
      jsLib: model.jsLib,
      enabledCookieJar: model.enabledCookieJar,
      concurrentRate: model.concurrentRate,
      header: model.header,
      loginUrl: model.loginUrl,
      loginUi: model.loginUi,
      loginCheckJs: model.loginCheckJs,
      coverDecodeJs: model.coverDecodeJs,
      bookSourceComment: model.bookSourceComment,
      variableComment: model.variableComment,
      lastUpdateTime: model.lastUpdateTime,
      respondTime: model.respondTime,
      weight: model.weight,
      exploreUrl: model.exploreUrl,
      exploreScreen: model.exploreScreen,
      searchUrl: model.searchUrl,
      ruleExplore: model.ruleExplore?.toJson(),
      ruleSearch: model.ruleSearch?.toJson(),
      ruleBookInfo: model.ruleBookInfo?.toJson(),
      ruleToc: model.ruleToc?.toJson(),
      ruleContent: model.ruleContent?.toJson(),
    );
  }

  /// BookSource Entity -> Model
  static BookSource bookSourceFromEntity(BookSourceEntity entity) {
    return BookSource(
      bookSourceUrl: entity.bookSourceUrl,
      bookSourceName: entity.bookSourceName,
      bookSourceGroup: entity.bookSourceGroup,
      bookSourceType: entity.bookSourceType,
      bookUrlPattern: entity.bookUrlPattern,
      customOrder: entity.customOrder,
      enabled: entity.enabled,
      enabledExplore: entity.enabledExplore,
      jsLib: entity.jsLib,
      enabledCookieJar: entity.enabledCookieJar,
      concurrentRate: entity.concurrentRate,
      header: entity.header,
      loginUrl: entity.loginUrl,
      loginUi: entity.loginUi,
      loginCheckJs: entity.loginCheckJs,
      coverDecodeJs: entity.coverDecodeJs,
      bookSourceComment: entity.bookSourceComment,
      variableComment: entity.variableComment,
      lastUpdateTime: entity.lastUpdateTime,
      respondTime: entity.respondTime,
      weight: entity.weight,
      exploreUrl: entity.exploreUrl,
      exploreScreen: entity.exploreScreen,
      searchUrl: entity.searchUrl,
      // 规则对象需要从Map重建
      ruleExplore: entity.ruleExplore != null
          ? ExploreRule.fromJson(entity.ruleExplore!)
          : null,
      ruleSearch: entity.ruleSearch != null
          ? SearchRule.fromJson(entity.ruleSearch!)
          : null,
      ruleBookInfo: entity.ruleBookInfo != null
          ? BookInfoRule.fromJson(entity.ruleBookInfo!)
          : null,
      ruleToc:
          entity.ruleToc != null ? TocRule.fromJson(entity.ruleToc!) : null,
      ruleContent: entity.ruleContent != null
          ? ContentRule.fromJson(entity.ruleContent!)
          : null,
    );
  }

  /// BookChapter Model -> Entity
  static ChapterEntity chapterToEntity(BookChapter model) {
    return ChapterEntity(
      url: model.url,
      bookUrl: model.bookUrl,
      title: model.title,
      isVolume: model.isVolume,
      baseUrl: model.baseUrl,
      index: model.index,
      isVip: model.isVip,
      isPay: model.isPay,
      resourceUrl: model.resourceUrl,
      tag: model.tag,
      wordCount: model.wordCount,
      start: model.start,
      end: model.end,
      startFragmentId: model.startFragmentId,
      endFragmentId: model.endFragmentId,
      variable: model.variable,
    );
  }

  /// BookChapter Entity -> Model
  static BookChapter chapterFromEntity(ChapterEntity entity) {
    return BookChapter(
      url: entity.url,
      bookUrl: entity.bookUrl,
      title: entity.title,
      isVolume: entity.isVolume,
      baseUrl: entity.baseUrl,
      index: entity.index,
      isVip: entity.isVip,
      isPay: entity.isPay,
      resourceUrl: entity.resourceUrl,
      tag: entity.tag,
      wordCount: entity.wordCount,
      start: entity.start,
      end: entity.end,
      startFragmentId: entity.startFragmentId,
      endFragmentId: entity.endFragmentId,
      variable: entity.variable,
    );
  }

  /// 批量转换 Book List
  static List<BookEntity> booksToEntities(List<Book> models) {
    return models.map((m) => bookToEntity(m)).toList();
  }

  static List<Book> booksFromEntities(List<BookEntity> entities) {
    return entities.map((e) => bookFromEntity(e)).toList();
  }

  /// 批量转换 BookSource List
  static List<BookSourceEntity> bookSourcesToEntities(List<BookSource> models) {
    return models.map((m) => bookSourceToEntity(m)).toList();
  }

  static List<BookSource> bookSourcesFromEntities(
      List<BookSourceEntity> entities) {
    return entities.map((e) => bookSourceFromEntity(e)).toList();
  }

  /// 批量转换 Chapter List
  static List<ChapterEntity> chaptersToEntities(List<BookChapter> models) {
    return models.map((m) => chapterToEntity(m)).toList();
  }

  static List<BookChapter> chaptersFromEntities(List<ChapterEntity> entities) {
    return entities.map((e) => chapterFromEntity(e)).toList();
  }
}
