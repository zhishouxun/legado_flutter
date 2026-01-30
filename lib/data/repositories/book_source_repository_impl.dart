import 'dart:convert';
import '../../domain/entities/book_source_entity.dart';
import '../../domain/repositories/book_source_repository.dart';
import '../datasources/book_source_local_datasource.dart';
import '../mappers/entity_mapper.dart';
import '../models/book_source.dart';

/// BookSourceRepository 的实现类
/// 参考：Clean Architecture - Repository Implementation
class BookSourceRepositoryImpl implements BookSourceRepository {
  final BookSourceLocalDataSource localDataSource;

  BookSourceRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<List<BookSourceEntity>> getAllBookSources(
      {bool enabledOnly = false}) async {
    final models =
        await localDataSource.getAllBookSources(enabledOnly: enabledOnly);
    return EntityMapper.bookSourcesToEntities(models);
  }

  @override
  Future<List<BookSourceEntity>> getEnabledBookSources() async {
    final models = await localDataSource.getEnabledBookSources();
    return EntityMapper.bookSourcesToEntities(models);
  }

  @override
  Future<List<BookSourceEntity>> getDisabledBookSources() async {
    final models = await localDataSource.getDisabledBookSources();
    return EntityMapper.bookSourcesToEntities(models);
  }

  @override
  Future<BookSourceEntity?> getBookSourceByUrl(String url) async {
    final model = await localDataSource.getBookSourceByUrl(url);
    return model != null ? EntityMapper.bookSourceToEntity(model) : null;
  }

  @override
  Future<List<BookSourceEntity>> getBookSourcesByGroup(String group) async {
    final models = await localDataSource.getBookSourcesByGroup(group);
    return EntityMapper.bookSourcesToEntities(models);
  }

  @override
  Future<List<String>> getAllGroups() async {
    return await localDataSource.getAllGroups();
  }

  @override
  Future<void> saveBookSource(BookSourceEntity bookSource) async {
    final model = EntityMapper.bookSourceFromEntity(bookSource);
    await localDataSource.saveBookSource(model);
  }

  @override
  Future<void> saveBookSources(List<BookSourceEntity> bookSources) async {
    final models = EntityMapper.bookSourcesFromEntities(bookSources);
    await localDataSource.saveBookSources(models);
  }

  @override
  Future<void> deleteBookSource(String bookSourceUrl) async {
    await localDataSource.deleteBookSource(bookSourceUrl);
  }

  @override
  Future<void> deleteBookSources(List<String> bookSourceUrls) async {
    await localDataSource.deleteBookSources(bookSourceUrls);
  }

  @override
  Future<void> updateBookSource(BookSourceEntity bookSource) async {
    final model = EntityMapper.bookSourceFromEntity(bookSource);
    await localDataSource.updateBookSource(model);
  }

  @override
  Future<void> toggleBookSource(String bookSourceUrl, bool enabled) async {
    await localDataSource.toggleBookSource(bookSourceUrl, enabled);
  }

  @override
  Future<void> toggleBookSources(
      List<String> bookSourceUrls, bool enabled) async {
    await localDataSource.toggleBookSources(bookSourceUrls, enabled);
  }

  @override
  Future<void> updateBookSourceOrder(String bookSourceUrl, int order) async {
    await localDataSource.updateBookSourceOrder(bookSourceUrl, order);
  }

  @override
  Future<void> updateRespondTime(String bookSourceUrl, int respondTime) async {
    await localDataSource.updateRespondTime(bookSourceUrl, respondTime);
  }

  @override
  Future<List<BookSourceEntity>> searchBookSources(String keyword) async {
    final models = await localDataSource.searchBookSources(keyword);
    return EntityMapper.bookSourcesToEntities(models);
  }

  @override
  Future<void> clearAllBookSources() async {
    await localDataSource.clearAllBookSources();
  }

  @override
  Future<int> importFromJson(String jsonString) async {
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      final bookSources = jsonList
          .map((json) => BookSource.fromJson(json as Map<String, dynamic>))
          .toList();

      await localDataSource.saveBookSources(bookSources);
      return bookSources.length;
    } catch (e) {
      throw Exception('导入书源失败: $e');
    }
  }

  @override
  Future<String> exportToJson(List<BookSourceEntity> bookSources) async {
    try {
      final models = EntityMapper.bookSourcesFromEntities(bookSources);
      final jsonList = models.map((source) => source.toJson()).toList();
      return json.encode(jsonList);
    } catch (e) {
      throw Exception('导出书源失败: $e');
    }
  }
}
