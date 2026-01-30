import '../../utils/coroutine/coroutine.dart';

/// 应用更新信息
class UpdateInfo {
  /// 标签名称（版本号）
  final String tagName;

  /// 更新日志
  final String updateLog;

  /// 下载URL
  final String downloadUrl;

  /// 文件名
  final String fileName;

  UpdateInfo({
    required this.tagName,
    required this.updateLog,
    required this.downloadUrl,
    required this.fileName,
  });
}

/// 应用更新接口
abstract class AppUpdateInterface {
  /// 检查更新
  /// 返回协程，成功时返回 UpdateInfo，失败时抛出异常
  Coroutine<UpdateInfo> check();
}

/// 应用更新管理器
/// 参考项目：io.legado.app.help.update.AppUpdate
class AppUpdate {
  AppUpdate._();

  /// GitHub 更新接口
  /// 注意：使用时需要导入 app_update_github.dart
  static AppUpdateInterface? get gitHubUpdate {
    // 延迟加载，避免循环依赖
    // 实际使用时应该直接使用 AppUpdateGitHub.instance
    // 这里返回null，实际使用时需要导入app_update_github.dart并返回AppUpdateGitHub.instance
    return null;
  }
}

