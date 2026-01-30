import '../repositories/book_source_repository.dart';

/// 切换书源启用状态用例
///
/// 业务逻辑：
/// 1. 启用或禁用书源
/// 2. 支持批量操作
class ToggleBookSourceUseCase {
  final BookSourceRepository bookSourceRepository;

  ToggleBookSourceUseCase({
    required this.bookSourceRepository,
  });

  /// 切换单个书源状态
  ///
  /// @param url 书源URL
  /// @param enabled 是否启用
  Future<void> execute(String url, bool enabled) async {
    await bookSourceRepository.toggleBookSource(url, enabled);
  }

  /// 启用书源
  ///
  /// @param url 书源URL
  Future<void> enable(String url) async {
    await execute(url, true);
  }

  /// 禁用书源
  ///
  /// @param url 书源URL
  Future<void> disable(String url) async {
    await execute(url, false);
  }

  /// 批量切换书源状态
  ///
  /// @param urls 书源URL列表
  /// @param enabled 是否启用
  /// @return 成功切换的数量
  Future<int> executeBatch(List<String> urls, bool enabled) async {
    try {
      await bookSourceRepository.toggleBookSources(urls, enabled);
      return urls.length;
    } catch (e) {
      return 0;
    }
  }

  /// 批量启用书源
  ///
  /// @param urls 书源URL列表
  Future<int> enableBatch(List<String> urls) async {
    return await executeBatch(urls, true);
  }

  /// 批量禁用书源
  ///
  /// @param urls 书源URL列表
  Future<int> disableBatch(List<String> urls) async {
    return await executeBatch(urls, false);
  }
}
