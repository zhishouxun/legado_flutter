import '../models/book_source.dart';

/// 书源本地数据源接口 - Data层的数据访问抽象
/// 负责与本地存储(数据库)交互
abstract class BookSourceLocalDataSource {
  /// 获取所有书源
  Future<List<BookSource>> getAllBookSources({bool enabledOnly = false});

  /// 获取启用的书源
  Future<List<BookSource>> getEnabledBookSources();

  /// 获取禁用的书源
  Future<List<BookSource>> getDisabledBookSources();

  /// 根据URL获取书源
  Future<BookSource?> getBookSourceByUrl(String url);

  /// 根据分组获取书源
  Future<List<BookSource>> getBookSourcesByGroup(String group);

  /// 获取所有书源分组
  Future<List<String>> getAllGroups();

  /// 保存书源
  Future<void> saveBookSource(BookSource bookSource);

  /// 批量保存书源
  Future<void> saveBookSources(List<BookSource> bookSources);

  /// 删除书源
  Future<void> deleteBookSource(String bookSourceUrl);

  /// 批量删除书源
  Future<void> deleteBookSources(List<String> bookSourceUrls);

  /// 更新书源
  Future<void> updateBookSource(BookSource bookSource);

  /// 启用/禁用书源
  Future<void> toggleBookSource(String bookSourceUrl, bool enabled);

  /// 批量启用/禁用书源
  Future<void> toggleBookSources(List<String> bookSourceUrls, bool enabled);

  /// 更新书源排序
  Future<void> updateBookSourceOrder(String bookSourceUrl, int order);

  /// 更新书源响应时间
  Future<void> updateRespondTime(String bookSourceUrl, int respondTime);

  /// 搜索书源(按名称或URL)
  Future<List<BookSource>> searchBookSources(String keyword);

  /// 清空所有书源
  Future<void> clearAllBookSources();
}
