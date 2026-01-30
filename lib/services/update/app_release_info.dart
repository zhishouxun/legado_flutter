/// 应用发布信息
/// 参考项目：io.legado.app.help.update.AppReleaseInfo
class AppReleaseInfo {
  /// 应用变体
  final AppVariant appVariant;

  /// 创建时间（时间戳）
  final int createdAt;

  /// 更新日志
  final String note;

  /// 文件名
  final String name;

  /// 下载URL
  final String downloadUrl;

  /// 资源URL
  final String assetUrl;

  AppReleaseInfo({
    required this.appVariant,
    required this.createdAt,
    required this.note,
    required this.name,
    required this.downloadUrl,
    required this.assetUrl,
  });

  /// 版本名称（从文件名解析）
  String get versionName {
    final parts = name.split('_');
    if (parts.length >= 3) {
      // 格式：legado_xxx_version.apk
      final versionPart = parts[2];
      // 移除 .apk 后缀
      return versionPart.replaceAll(RegExp(r'\.apk$'), '');
    }
    return '';
  }

  /// 从 GitHub Release JSON 创建
  factory AppReleaseInfo.fromGithubRelease(
    Map<String, dynamic> githubRelease,
    Map<String, dynamic> asset,
  ) {
    final createdAtStr = asset['created_at'] as String? ?? '';
    final createdAt = DateTime.tryParse(createdAtStr)?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    final isPreRelease = githubRelease['prerelease'] as bool? ?? false;
    final assetName = asset['name'] as String? ?? '';

    // 判断应用变体
    AppVariant appVariant;
    if (isPreRelease && assetName.contains('releaseA')) {
      appVariant = AppVariant.betaReleaseA;
    } else if (isPreRelease && assetName.contains('release')) {
      appVariant = AppVariant.betaRelease;
    } else {
      appVariant = AppVariant.official;
    }

    return AppReleaseInfo(
      appVariant: appVariant,
      createdAt: createdAt,
      note: githubRelease['body'] as String? ?? '',
      name: assetName,
      downloadUrl: asset['browser_download_url'] as String? ?? '',
      assetUrl: asset['url'] as String? ?? '',
    );
  }
}

/// 应用变体
/// 参考项目：io.legado.app.help.update.AppVariant
enum AppVariant {
  /// 正式版
  official,

  /// Beta Release A
  betaReleaseA,

  /// Beta Release
  betaRelease,

  /// 未知
  unknown;

  /// 是否为 Beta 版本
  bool isBeta() {
    return this == betaRelease || this == betaReleaseA;
  }
}

