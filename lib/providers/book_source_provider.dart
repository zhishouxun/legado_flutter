import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/book_source.dart';
import '../services/source/book_source_service.dart';

/// 书源列表Provider
final bookSourceListProvider = FutureProvider<List<BookSource>>((ref) async {
  final service = BookSourceService.instance;
  return await service.getAllBookSources();
});

/// 启用的书源列表Provider
final enabledBookSourceListProvider = FutureProvider<List<BookSource>>((ref) async {
  final service = BookSourceService.instance;
  return await service.getAllBookSources(enabledOnly: true);
});

/// 书源分组列表Provider
final bookSourceGroupListProvider = FutureProvider<List<String>>((ref) async {
  final service = BookSourceService.instance;
  return await service.getAllGroups();
});

/// 单个书源Provider
final bookSourceProvider = FutureProvider.family<BookSource?, String>((ref, url) async {
  final service = BookSourceService.instance;
  return await service.getBookSourceByUrl(url);
});

/// 刷新书源列表的Provider
final refreshBookSourceListProvider = FutureProvider.family<List<BookSource>, void>((ref, _) async {
  final service = BookSourceService.instance;
  return await service.getAllBookSources();
});

/// 书源操作Provider
final bookSourceOperationsProvider = Provider((ref) => BookSourceOperations());

/// 书源操作类
class BookSourceOperations {
  final BookSourceService _service = BookSourceService.instance;

  /// 添加书源
  Future<void> addBookSource(BookSource bookSource, WidgetRef ref) async {
    await _service.addBookSource(bookSource);
    ref.invalidate(refreshBookSourceListProvider);
  }

  /// 更新书源
  Future<void> updateBookSource(BookSource bookSource, WidgetRef ref) async {
    await _service.updateBookSource(bookSource);
    ref.invalidate(refreshBookSourceListProvider);
  }

  /// 删除书源
  Future<void> deleteBookSource(String url, WidgetRef ref) async {
    await _service.deleteBookSource(url);
    ref.invalidate(refreshBookSourceListProvider);
  }

  /// 启用/禁用书源
  Future<void> setEnabled(String url, bool enabled, WidgetRef ref) async {
    await _service.setBookSourceEnabled(url, enabled);
    ref.invalidate(refreshBookSourceListProvider);
  }

  /// 批量导入书源
  Future<Map<String, int>> importBookSources(List<BookSource> bookSources, WidgetRef ref) async {
    final result = await _service.importBookSources(bookSources);
    ref.invalidate(refreshBookSourceListProvider);
    return result;
  }
}

