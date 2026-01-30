import '../models/book_source.dart';
import '../../services/source/book_source_service.dart';
import 'book_source_local_datasource.dart';

/// BookSourceLocalDataSource 的实现类
/// 封装现有的 BookSourceService,使其符合 DataSource 接口
class BookSourceLocalDataSourceImpl implements BookSourceLocalDataSource {
  final BookSourceService _service;

  BookSourceLocalDataSourceImpl({BookSourceService? service})
      : _service = service ?? BookSourceService.instance;

  @override
  Future<List<BookSource>> getAllBookSources({bool enabledOnly = false}) async {
    return await _service.getAllBookSources(enabledOnly: enabledOnly);
  }

  @override
  Future<List<BookSource>> getEnabledBookSources() async {
    return await _service.getEnabledBookSources();
  }

  @override
  Future<List<BookSource>> getDisabledBookSources() async {
    return await _service.getDisabledBookSources();
  }

  @override
  Future<BookSource?> getBookSourceByUrl(String url) async {
    return await _service.getBookSourceByUrl(url);
  }

  @override
  Future<List<BookSource>> getBookSourcesByGroup(String group) async {
    return await _service.getBookSourcesByGroup(group);
  }

  @override
  Future<List<String>> getAllGroups() async {
    return await _service.getAllGroups();
  }

  @override
  Future<void> saveBookSource(BookSource bookSource) async {
    await _service.addBookSource(bookSource);
  }

  @override
  Future<void> saveBookSources(List<BookSource> bookSources) async {
    // 使用 importBookSources 批量导入
    await _service.importBookSources(bookSources);
  }

  @override
  Future<void> deleteBookSource(String bookSourceUrl) async {
    await _service.deleteBookSource(bookSourceUrl);
  }

  @override
  Future<void> deleteBookSources(List<String> bookSourceUrls) async {
    await _service.batchDeleteBookSources(bookSourceUrls);
  }

  @override
  Future<void> updateBookSource(BookSource bookSource) async {
    await _service.updateBookSource(bookSource);
  }

  @override
  Future<void> toggleBookSource(String bookSourceUrl, bool enabled) async {
    final source = await _service.getBookSourceByUrl(bookSourceUrl);
    if (source != null) {
      final updated = source.copyWith(enabled: enabled);
      await _service.updateBookSource(updated);
    }
  }

  @override
  Future<void> toggleBookSources(
      List<String> bookSourceUrls, bool enabled) async {
    for (final url in bookSourceUrls) {
      await toggleBookSource(url, enabled);
    }
  }

  @override
  Future<void> updateBookSourceOrder(String bookSourceUrl, int order) async {
    final source = await _service.getBookSourceByUrl(bookSourceUrl);
    if (source != null) {
      final updated = source.copyWith(customOrder: order);
      await _service.updateBookSource(updated);
    }
  }

  @override
  Future<void> updateRespondTime(String bookSourceUrl, int respondTime) async {
    final source = await _service.getBookSourceByUrl(bookSourceUrl);
    if (source != null) {
      final updated = source.copyWith(respondTime: respondTime);
      await _service.updateBookSource(updated);
    }
  }

  @override
  Future<List<BookSource>> searchBookSources(String keyword) async {
    return await _service.searchBookSources(keyword);
  }

  @override
  Future<void> clearAllBookSources() async {
    // 获取所有书源URL后批量删除
    final allSources = await _service.getAllBookSources();
    final urls = allSources.map((s) => s.bookSourceUrl).toList();
    if (urls.isNotEmpty) {
      await _service.batchDeleteBookSources(urls);
    }
  }
}
