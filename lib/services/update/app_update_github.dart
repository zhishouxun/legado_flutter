import 'dart:convert';
import '../network/network_service.dart';
import '../../utils/app_log.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../config/app_config.dart';
import '../../utils/coroutine/coroutine.dart';
import 'app_release_info.dart';
import 'app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub 应用更新
/// 参考项目：io.legado.app.help.update.AppUpdateGitHub
class AppUpdateGitHub implements AppUpdateInterface {
  static final AppUpdateGitHub instance = AppUpdateGitHub._init();
  AppUpdateGitHub._init();

  /// 获取检查变体
  AppVariant _getCheckVariant() {
    final variantStr = AppConfig.getUpdateToVariant();
    switch (variantStr) {
      case 'official_version':
        return AppVariant.official;
      case 'beta_release_version':
        return AppVariant.betaRelease;
      case 'beta_releaseA_version':
        return AppVariant.betaReleaseA;
      default:
        // 使用当前应用变体（暂时返回 official）
        return AppVariant.official;
    }
  }

  /// 获取最新发布版本
  Future<List<AppReleaseInfo>> _getLatestRelease() async {
    final checkVariant = _getCheckVariant();
    final lastReleaseUrl = checkVariant.isBeta()
        ? 'https://api.github.com/repos/gedoor/legado/releases/tags/beta'
        : 'https://api.github.com/repos/gedoor/legado/releases/latest';

    try {
      final response = await NetworkService.instance.get(
        lastReleaseUrl,
        retryCount: 1,
      );

      if (response.statusCode != 200) {
        throw NoStackTraceException('获取新版本出错(${response.statusCode})');
      }

      final body = await NetworkService.getResponseText(response);
      if (body.isEmpty) {
        throw NoStackTraceException('获取新版本出错');
      }

      final githubRelease = jsonDecode(body) as Map<String, dynamic>;
      final assets = githubRelease['assets'] as List<dynamic>?;

      if (assets == null || assets.isEmpty) {
        throw NoStackTraceException('获取新版本出错：没有找到资源文件');
      }

      // 过滤有效的资源文件（APK 文件）
      final validAssets = assets.where((asset) {
        final contentType = asset['content_type'] as String?;
        final state = asset['state'] as String?;
        return contentType == 'application/vnd.android.package-archive' &&
            state == 'uploaded';
      }).toList();

      if (validAssets.isEmpty) {
        throw NoStackTraceException('获取新版本出错：没有找到有效的 APK 文件');
      }

      // 转换为 AppReleaseInfo
      final releaseInfos = validAssets
          .map((asset) => AppReleaseInfo.fromGithubRelease(
                githubRelease,
                asset as Map<String, dynamic>,
              ))
          .toList();

      // 按创建时间降序排序
      releaseInfos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return releaseInfos;
    } catch (e) {
      if (e is NoStackTraceException) {
        rethrow;
      }
      AppLog.instance.put('获取最新发布版本失败', error: e);
      throw NoStackTraceException('获取新版本出错: ${e.toString()}');
    }
  }

  @override
  Coroutine<UpdateInfo> check() {
    return Coroutine.async<UpdateInfo>(() async {
      final releases = await _getLatestRelease();
      final checkVariant = _getCheckVariant();

      // 获取当前应用版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionName = packageInfo.version;

      // 过滤匹配变体的发布版本
      final matchingReleases = releases
          .where((release) => release.appVariant == checkVariant)
          .toList();

      if (matchingReleases.isEmpty) {
        throw NoStackTraceException('已是最新版本');
      }

      // 找到第一个版本号大于当前版本的发布
      for (final release in matchingReleases) {
        if (_compareVersion(release.versionName, currentVersionName) > 0) {
          return UpdateInfo(
            tagName: release.versionName,
            updateLog: release.note,
            downloadUrl: release.downloadUrl,
            fileName: release.name,
          );
        }
      }

      throw NoStackTraceException('已是最新版本');
    }).timeout(const Duration(seconds: 10));
  }

  /// 比较版本号
  /// 返回：>0 表示 version1 > version2，<0 表示 version1 < version2，0 表示相等
  int _compareVersion(String version1, String version2) {
    final parts1 = version1.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final parts2 = version2.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < maxLength; i++) {
      final v1 = i < parts1.length ? parts1[i] : 0;
      final v2 = i < parts2.length ? parts2[i] : 0;

      if (v1 > v2) return 1;
      if (v1 < v2) return -1;
    }

    return 0;
  }
}

