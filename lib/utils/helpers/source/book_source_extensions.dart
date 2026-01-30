import '../../../data/models/book_source.dart';
import '../../../data/models/explore_kind.dart';
import '../../../core/constants/app_status.dart';
import '../../../services/explore_service.dart';

/// 书源扩展方法
/// 参考项目：io.legado.app.help.source.BookSourceExtensions
extension BookSourceExtensions on BookSource {
  /// 获取发现分类列表
  /// 参考项目：BookSource.exploreKinds()
  Future<List<ExploreKind>> exploreKinds() async {
    return await ExploreService.instance.getExploreKinds(this);
  }

  /// 清除发现分类缓存
  /// 参考项目：BookSource.clearExploreKindsCache()
  Future<void> clearExploreKindsCache() async {
    await ExploreService.instance.clearExploreKindsCache(this);
  }

  /// 获取发现分类 JSON
  /// 参考项目：BookSource.exploreKindsJson()
  String exploreKindsJson() {
    // 如果 exploreUrl 是 JSON 数组格式，直接返回
    if (exploreUrl != null && exploreUrl!.trim().startsWith('[')) {
      return exploreUrl!;
    }
    return '';
  }

  /// 获取书籍类型
  /// 参考项目：BookSource.getBookType()
  int getBookType() {
    switch (bookSourceType) {
      case 3: // 文件类型
        return AppStatus.bookTypeText | AppStatus.bookTypeWebFile;
      case 2: // 图片类型
        return AppStatus.bookTypeImage;
      case 1: // 音频类型
        return AppStatus.bookTypeAudio;
      default: // 文本类型
        return AppStatus.bookTypeText;
    }
  }
}

