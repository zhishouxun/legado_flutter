import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/book_source_entity.dart';
import '../data/models/book_source.dart';
import '../data/mappers/entity_mapper.dart';
import 'repository_providers.dart';

/// 书源列表Provider (使用Repository)
final bookSourceListProvider = FutureProvider<List<BookSource>>((ref) async {
  final repository = ref.read(bookSourceRepositoryProvider);
  final entities = await repository.getAllBookSources();
  return entities.map((e) => EntityMapper.bookSourceFromEntity(e)).toList();
});

/// 启用的书源列表Provider (使用Repository)
final enabledBookSourceListProvider =
    FutureProvider<List<BookSource>>((ref) async {
  final repository = ref.read(bookSourceRepositoryProvider);
  final entities = await repository.getEnabledBookSources();
  return entities.map((e) => EntityMapper.bookSourceFromEntity(e)).toList();
});

/// 书源分组列表Provider (使用Repository)
final bookSourceGroupListProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.read(bookSourceRepositoryProvider);
  return await repository.getAllGroups();
});

/// 单个书源Provider (使用Repository)
final bookSourceProvider =
    FutureProvider.family<BookSource?, String>((ref, url) async {
  final repository = ref.read(bookSourceRepositoryProvider);
  final entity = await repository.getBookSourceByUrl(url);
  return entity != null ? EntityMapper.bookSourceFromEntity(entity) : null;
});

/// 刷新书源列表的Provider (使用Repository)
final refreshBookSourceListProvider =
    FutureProvider.family<List<BookSource>, void>((ref, _) async {
  final repository = ref.read(bookSourceRepositoryProvider);
  final entities = await repository.getAllBookSources();
  return entities.map((e) => EntityMapper.bookSourceFromEntity(e)).toList();
});

/// 书源操作Provider
final bookSourceOperationsProvider = Provider((ref) => BookSourceOperations());

/// 书源操作类 (使用Repository)
class BookSourceOperations {
  /// 添加书源
  Future<void> addBookSource(BookSource bookSource, WidgetRef ref) async {
    final repository = ref.read(bookSourceRepositoryProvider);
    final entity = EntityMapper.bookSourceToEntity(bookSource);
    await repository.saveBookSource(entity);
    ref.invalidate(refreshBookSourceListProvider);
  }

  /// 更新书源
  Future<void> updateBookSource(BookSource bookSource, WidgetRef ref) async {
    final repository = ref.read(bookSourceRepositoryProvider);
    final entity = EntityMapper.bookSourceToEntity(bookSource);
    await repository.updateBookSource(entity);
    ref.invalidate(refreshBookSourceListProvider);
  }

  /// 删除书源
  Future<void> deleteBookSource(String url, WidgetRef ref) async {
    final repository = ref.read(bookSourceRepositoryProvider);
    await repository.deleteBookSource(url);
    ref.invalidate(refreshBookSourceListProvider);
  }

  /// 启用/禁用书源
  Future<void> setEnabled(String url, bool enabled, WidgetRef ref) async {
    final repository = ref.read(bookSourceRepositoryProvider);
    await repository.toggleBookSource(url, enabled);
    ref.invalidate(refreshBookSourceListProvider);
  }

  /// 批量导入书源
  Future<Map<String, int>> importBookSources(
      List<BookSource> bookSources, WidgetRef ref) async {
    final repository = ref.read(bookSourceRepositoryProvider);
    // 使用saveBookSources批量保存
    final entities =
        bookSources.map((s) => EntityMapper.bookSourceToEntity(s)).toList();
    await repository.saveBookSources(entities);
    ref.invalidate(refreshBookSourceListProvider);
    // 返回统计信息
    return {'success': bookSources.length, 'failed': 0, 'exists': 0};
  }
}
