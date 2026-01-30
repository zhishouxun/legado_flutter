import '../entities/book_source_entity.dart';
import '../repositories/book_source_repository.dart';

/// 获取书源列表用例
///
/// 业务逻辑：
/// 1. 从本地数据库获取书源列表
/// 2. 可选：只获取启用的书源
/// 3. 可选：按分组过滤
class GetBookSourcesUseCase {
  final BookSourceRepository bookSourceRepository;

  GetBookSourcesUseCase({
    required this.bookSourceRepository,
  });

  /// 获取所有书源
  ///
  /// @param enabledOnly 是否只获取启用的书源
  /// @return 书源列表
  Future<List<BookSourceEntity>> execute({bool enabledOnly = false}) async {
    if (enabledOnly) {
      return await bookSourceRepository.getEnabledBookSources();
    }
    return await bookSourceRepository.getAllBookSources();
  }

  /// 获取启用的书源
  Future<List<BookSourceEntity>> executeEnabled() async {
    return await bookSourceRepository.getEnabledBookSources();
  }

  /// 获取禁用的书源
  Future<List<BookSourceEntity>> executeDisabled() async {
    return await bookSourceRepository.getDisabledBookSources();
  }

  /// 根据分组获取书源
  ///
  /// @param group 分组名称
  /// @return 书源列表
  Future<List<BookSourceEntity>> executeByGroup(String group) async {
    return await bookSourceRepository.getBookSourcesByGroup(group);
  }

  /// 获取所有分组
  Future<List<String>> getAllGroups() async {
    return await bookSourceRepository.getAllGroups();
  }

  /// 根据URL获取单个书源
  ///
  /// @param url 书源URL
  /// @return 书源实体(可能为null)
  Future<BookSourceEntity?> getByUrl(String url) async {
    return await bookSourceRepository.getBookSourceByUrl(url);
  }

  /// 搜索书源
  ///
  /// @param keyword 搜索关键词(匹配书源名称或URL)
  /// @return 匹配的书源列表
  Future<List<BookSourceEntity>> search(String keyword) async {
    return await bookSourceRepository.searchBookSources(keyword);
  }
}
