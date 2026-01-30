import '../entities/book_source_entity.dart';

/// 书源仓库接口 - Domain层的抽象契约
/// 参考：Clean Architecture - Repository Interface
abstract class BookSourceRepository {
  /// 获取所有书源
  /// @param enabledOnly 是否只获取启用的书源
  Future<List<BookSourceEntity>> getAllBookSources({bool enabledOnly = false});

  /// 获取启用的书源
  Future<List<BookSourceEntity>> getEnabledBookSources();

  /// 获取禁用的书源
  Future<List<BookSourceEntity>> getDisabledBookSources();

  /// 根据URL获取书源
  Future<BookSourceEntity?> getBookSourceByUrl(String url);

  /// 根据分组获取书源
  Future<List<BookSourceEntity>> getBookSourcesByGroup(String group);

  /// 获取所有书源分组
  Future<List<String>> getAllGroups();

  /// 保存书源
  Future<void> saveBookSource(BookSourceEntity bookSource);

  /// 批量保存书源
  Future<void> saveBookSources(List<BookSourceEntity> bookSources);

  /// 删除书源
  Future<void> deleteBookSource(String bookSourceUrl);

  /// 批量删除书源
  Future<void> deleteBookSources(List<String> bookSourceUrls);

  /// 更新书源
  Future<void> updateBookSource(BookSourceEntity bookSource);

  /// 启用/禁用书源
  Future<void> toggleBookSource(String bookSourceUrl, bool enabled);

  /// 批量启用/禁用书源
  Future<void> toggleBookSources(List<String> bookSourceUrls, bool enabled);

  /// 更新书源排序
  Future<void> updateBookSourceOrder(String bookSourceUrl, int order);

  /// 更新书源响应时间
  Future<void> updateRespondTime(String bookSourceUrl, int respondTime);

  /// 搜索书源(按名称或URL)
  Future<List<BookSourceEntity>> searchBookSources(String keyword);

  /// 清空所有书源
  Future<void> clearAllBookSources();

  /// 导入书源(从JSON)
  Future<int> importFromJson(String jsonString);

  /// 导出书源(到JSON)
  Future<String> exportToJson(List<BookSourceEntity> bookSources);
}
