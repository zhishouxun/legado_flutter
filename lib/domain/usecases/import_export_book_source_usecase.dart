import '../entities/book_source_entity.dart';
import '../repositories/book_source_repository.dart';

/// 导入导出书源用例
///
/// 业务逻辑：
/// 1. 从JSON导入书源
/// 2. 导出书源到JSON
/// 3. 支持批量导入
class ImportExportBookSourceUseCase {
  final BookSourceRepository bookSourceRepository;

  ImportExportBookSourceUseCase({
    required this.bookSourceRepository,
  });

  /// 从JSON导入书源
  ///
  /// @param jsonString JSON字符串
  /// @return 成功导入的数量
  Future<int> importFromJson(String jsonString) async {
    return await bookSourceRepository.importFromJson(jsonString);
  }

  /// 批量导入书源实体
  ///
  /// @param sources 书源列表
  /// @return 成功导入的数量
  Future<int> importSources(List<BookSourceEntity> sources) async {
    try {
      await bookSourceRepository.saveBookSources(sources);
      return sources.length;
    } catch (e) {
      return 0;
    }
  }

  /// 导出书源到JSON
  ///
  /// @param sources 要导出的书源列表(可选,为空则导出所有)
  /// @return JSON字符串
  Future<String> exportToJson({List<BookSourceEntity>? sources}) async {
    final effectiveSources =
        sources ?? await bookSourceRepository.getAllBookSources();
    return await bookSourceRepository.exportToJson(effectiveSources);
  }

  /// 导出启用的书源
  Future<String> exportEnabledToJson() async {
    final sources = await bookSourceRepository.getEnabledBookSources();
    return await bookSourceRepository.exportToJson(sources);
  }

  /// 导出指定分组的书源
  ///
  /// @param group 分组名称
  Future<String> exportGroupToJson(String group) async {
    final sources = await bookSourceRepository.getBookSourcesByGroup(group);
    return await bookSourceRepository.exportToJson(sources);
  }
}
