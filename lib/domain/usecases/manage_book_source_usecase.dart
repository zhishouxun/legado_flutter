import '../entities/book_source_entity.dart';
import '../repositories/book_source_repository.dart';

/// 管理书源用例(添加/更新/删除)
///
/// 业务逻辑：
/// 1. 提供书源的CRUD操作
/// 2. 支持批量操作
class ManageBookSourceUseCase {
  final BookSourceRepository bookSourceRepository;

  ManageBookSourceUseCase({
    required this.bookSourceRepository,
  });

  /// 添加单个书源
  ///
  /// @param source 书源实体
  Future<void> addSource(BookSourceEntity source) async {
    await bookSourceRepository.saveBookSource(source);
  }

  /// 批量添加书源
  ///
  /// @param sources 书源列表
  /// @return 成功添加的数量
  Future<int> addSourcesBatch(List<BookSourceEntity> sources) async {
    try {
      await bookSourceRepository.saveBookSources(sources);
      return sources.length;
    } catch (e) {
      return 0;
    }
  }

  /// 更新书源
  ///
  /// @param source 书源实体
  Future<void> updateSource(BookSourceEntity source) async {
    await bookSourceRepository.updateBookSource(source);
  }

  /// 删除单个书源
  ///
  /// @param url 书源URL
  Future<void> deleteSource(String url) async {
    await bookSourceRepository.deleteBookSource(url);
  }

  /// 批量删除书源
  ///
  /// @param urls 书源URL列表
  /// @return 成功删除的数量
  Future<int> deleteSourcesBatch(List<String> urls) async {
    int successCount = 0;
    for (final url in urls) {
      try {
        await deleteSource(url);
        successCount++;
      } catch (e) {
        continue;
      }
    }
    return successCount;
  }

  /// 清空所有书源
  Future<void> clearAll() async {
    await bookSourceRepository.clearAllBookSources();
  }
}
