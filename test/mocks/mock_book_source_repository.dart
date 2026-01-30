import 'package:legado_flutter/domain/entities/book_source_entity.dart';
import 'package:legado_flutter/domain/repositories/book_source_repository.dart';

/// Mock implementation of BookSourceRepository for testing
class MockBookSourceRepository implements BookSourceRepository {
  // 可配置的返回值
  List<BookSourceEntity> _allSources = [];
  BookSourceEntity? _sourceByUrl;
  List<String> _groups = [];

  // 调用计数器
  int getAllBookSourcesCallCount = 0;
  int saveBookSourceCallCount = 0;
  int deleteBookSourceCallCount = 0;
  int toggleBookSourceCallCount = 0;

  // 设置返回值的方法
  void setAllSources(List<BookSourceEntity> sources) => _allSources = sources;
  void setSourceByUrl(BookSourceEntity? source) => _sourceByUrl = source;
  void setGroups(List<String> groups) => _groups = groups;

  @override
  Future<List<BookSourceEntity>> getAllBookSources(
      {bool enabledOnly = false}) async {
    getAllBookSourcesCallCount++;
    if (enabledOnly) {
      return _allSources.where((s) => s.enabled).toList();
    }
    return _allSources;
  }

  @override
  Future<List<BookSourceEntity>> getEnabledBookSources() async {
    return _allSources.where((s) => s.enabled).toList();
  }

  @override
  Future<List<BookSourceEntity>> getDisabledBookSources() async {
    return _allSources.where((s) => !s.enabled).toList();
  }

  @override
  Future<BookSourceEntity?> getBookSourceByUrl(String url) async {
    return _sourceByUrl ??
        _allSources.firstWhere(
          (s) => s.bookSourceUrl == url,
          orElse: () => _allSources.first,
        );
  }

  @override
  Future<List<BookSourceEntity>> getBookSourcesByGroup(String group) async {
    return _allSources.where((s) => s.bookSourceGroup == group).toList();
  }

  @override
  Future<List<String>> getAllGroups() async {
    return _groups;
  }

  @override
  Future<void> saveBookSource(BookSourceEntity bookSource) async {
    saveBookSourceCallCount++;
    _allSources.add(bookSource);
  }

  @override
  Future<void> saveBookSources(List<BookSourceEntity> bookSources) async {
    for (var source in bookSources) {
      await saveBookSource(source);
    }
  }

  @override
  Future<void> deleteBookSource(String bookSourceUrl) async {
    deleteBookSourceCallCount++;
    _allSources.removeWhere((s) => s.bookSourceUrl == bookSourceUrl);
  }

  @override
  Future<void> deleteBookSources(List<String> bookSourceUrls) async {
    for (var url in bookSourceUrls) {
      await deleteBookSource(url);
    }
  }

  @override
  Future<void> updateBookSource(BookSourceEntity bookSource) async {
    final index = _allSources
        .indexWhere((s) => s.bookSourceUrl == bookSource.bookSourceUrl);
    if (index != -1) {
      _allSources[index] = bookSource;
    }
  }

  @override
  Future<void> toggleBookSource(String bookSourceUrl, bool enabled) async {
    toggleBookSourceCallCount++;
    final index =
        _allSources.indexWhere((s) => s.bookSourceUrl == bookSourceUrl);
    if (index != -1) {
      _allSources[index] = _allSources[index].copyWith(enabled: enabled);
    }
  }

  @override
  Future<void> toggleBookSources(
      List<String> bookSourceUrls, bool enabled) async {
    for (var url in bookSourceUrls) {
      await toggleBookSource(url, enabled);
    }
  }

  @override
  Future<void> updateBookSourceOrder(String bookSourceUrl, int order) async {
    final index =
        _allSources.indexWhere((s) => s.bookSourceUrl == bookSourceUrl);
    if (index != -1) {
      _allSources[index] = _allSources[index].copyWith(weight: order);
    }
  }

  @override
  Future<void> updateRespondTime(String bookSourceUrl, int respondTime) async {
    // Mock implementation
  }

  @override
  Future<List<BookSourceEntity>> searchBookSources(String keyword) async {
    return _allSources
        .where((s) =>
            s.bookSourceName.contains(keyword) ||
            s.bookSourceUrl.contains(keyword))
        .toList();
  }

  @override
  Future<void> clearAllBookSources() async {
    _allSources.clear();
  }

  @override
  Future<int> importFromJson(String jsonString) async {
    return 0;
  }

  @override
  Future<String> exportToJson(List<BookSourceEntity> bookSources) async {
    return '[]';
  }

  // 重置所有计数器
  void resetCounters() {
    getAllBookSourcesCallCount = 0;
    saveBookSourceCallCount = 0;
    deleteBookSourceCallCount = 0;
    toggleBookSourceCallCount = 0;
  }
}
