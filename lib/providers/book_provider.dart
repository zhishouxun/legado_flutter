import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/book_entity.dart';
import '../domain/entities/book_source_entity.dart';
import '../domain/entities/chapter_entity.dart';
import '../data/models/book.dart';
import '../data/models/book_chapter.dart';
import '../data/models/book_group.dart';
import '../data/mappers/entity_mapper.dart';
import '../services/book_group_service.dart';
import 'repository_providers.dart';

/// 书架书籍列表Provider (使用Repository)
final bookshelfBooksProvider = FutureProvider<List<Book>>((ref) async {
  final repository = ref.read(bookRepositoryProvider);
  final entities = await repository.getShelfBooks();
  return entities.map((e) => EntityMapper.bookFromEntity(e)).toList();
});

/// 书籍搜索Provider (使用Repository - Stream方式)
final bookSearchProvider =
    StreamProvider.family<List<Book>, String>((ref, keyword) {
  final repository = ref.read(bookRepositoryProvider);
  final sourceRepository = ref.read(bookSourceRepositoryProvider);

  return sourceRepository
      .getEnabledBookSources()
      .asStream()
      .asyncExpand((sourceEntities) {
    return repository
        .searchBooks(keyword, sources: sourceEntities)
        .map((entities) {
      return entities.map((e) => EntityMapper.bookFromEntity(e)).toList();
    });
  });
});

/// 书籍详情Provider (使用Repository)
final bookInfoProvider = FutureProvider.family<Book?, Book>((ref, book) async {
  final repository = ref.read(bookRepositoryProvider);
  final sourceRepository = ref.read(bookSourceRepositoryProvider);

  // 转换为Entity
  final bookEntity = EntityMapper.bookToEntity(book);

  // 获取书源
  final sourceEntities = await sourceRepository.getBookSourceByUrl(book.origin);
  if (sourceEntities == null) return null;

  // 获取书籍详情
  final updatedEntity =
      await repository.getBookInfo(bookEntity, sourceEntities);
  return EntityMapper.bookFromEntity(updatedEntity);
});

/// 章节列表Provider (使用Repository)
final chapterListProvider =
    FutureProvider.family<List<BookChapter>, Book>((ref, book) async {
  final repository = ref.read(bookRepositoryProvider);
  final sourceRepository = ref.read(bookSourceRepositoryProvider);

  // 转换为Entity
  final bookEntity = EntityMapper.bookToEntity(book);

  // 获取书源
  final sourceEntity = await sourceRepository.getBookSourceByUrl(book.origin);
  if (sourceEntity == null) return [];

  // 获取章节列表
  final chapterEntities =
      await repository.getChapterList(bookEntity, sourceEntity);
  return chapterEntities.map((e) => EntityMapper.chapterFromEntity(e)).toList();
});

/// 刷新书架列表的Provider (使用Repository)
final refreshBookshelfProvider =
    FutureProvider.family<List<Book>, void>((ref, _) async {
  final repository = ref.read(bookRepositoryProvider);
  final entities = await repository.getShelfBooks();
  return entities.map((e) => EntityMapper.bookFromEntity(e)).toList();
});

/// 书籍分组列表Provider
final bookGroupsProvider = FutureProvider<List<BookGroup>>((ref) async {
  final service = BookGroupService.instance;
  // 确保服务已初始化
  if (!service.isInitialized) {
    await service.init();
  }
  // 初始化默认分组
  await service.initDefaultGroups();
  return await service.getAllGroups(showOnly: true);
});

/// 根据分组获取书籍的Provider (使用Repository)
final booksByGroupProvider =
    FutureProvider.family<List<Book>, int>((ref, groupId) async {
  final repository = ref.read(bookRepositoryProvider);

  if (groupId == BookGroup.idAll) {
    final entities = await repository.getShelfBooks();
    return entities.map((e) => EntityMapper.bookFromEntity(e)).toList();
  }

  final entities = await repository.getBooksByGroup(groupId);
  return entities.map((e) => EntityMapper.bookFromEntity(e)).toList();
});

/// 书籍操作Provider
final bookOperationsProvider = Provider((ref) => BookOperations());

/// 书籍操作类 (使用Repository)
class BookOperations {
  /// 添加书籍到书架
  Future<void> addBook(Book book, WidgetRef ref) async {
    final repository = ref.read(bookRepositoryProvider);
    final bookEntity = EntityMapper.bookToEntity(book);
    await repository.saveBook(bookEntity);
    ref.invalidate(refreshBookshelfProvider);
  }

  /// 从书架删除书籍
  Future<void> removeBook(String bookUrl, WidgetRef ref) async {
    final repository = ref.read(bookRepositoryProvider);
    await repository.deleteBook(bookUrl);
    ref.invalidate(refreshBookshelfProvider);
  }

  /// 更新阅读进度
  Future<void> updateProgress(
    String bookUrl,
    int chapterIndex,
    int chapterPos,
    String? chapterTitle,
    WidgetRef ref,
  ) async {
    final repository = ref.read(bookRepositoryProvider);
    await repository.updateReadProgress(bookUrl, chapterIndex, chapterPos);
    ref.invalidate(refreshBookshelfProvider);
  }
}
