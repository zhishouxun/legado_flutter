import '../../../data/models/interfaces/base_source.dart';
import '../../../data/models/book_source.dart';
import '../../../data/models/rss_source.dart';
import '../../../core/constants/app_status.dart';
import '../../../utils/js_engine.dart';

/// 基础源扩展方法
/// 参考项目：io.legado.app.help.source.BaseSourceExtensions
extension BaseSourceExtensions on BaseSource {
  /// 获取共享 JavaScript 作用域
  /// 参考项目：BaseSource.getShareScope()
  ///
  /// 注意：Flutter 中使用 JSEngine，这里返回 JSEngine 实例
  JSEngine getShareScope() {
    // 在 Flutter 中，JSEngine 是全局单例，不需要创建新的作用域
    // 如果需要隔离作用域，可以在 JSEngine 中实现
    return JSEngine();
  }

  /// 获取源类型
  /// 参考项目：BaseSource.getSourceType()
  int getSourceType() {
    if (this is BookSource) {
      return AppStatus.sourceTypeBook;
    } else if (this is RssSource) {
      return AppStatus.sourceTypeRss;
    } else {
      throw Exception('未知的源类型: $runtimeType');
    }
  }
}
