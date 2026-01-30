import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/base/base_service.dart';
import '../utils/app_log.dart';

/// 本地配置服务
/// 参考项目：io.legado.app.help.config.LocalConfig
///
/// 管理本地配置，包括密码、备份时间、帮助版本等
class LocalConfigService extends BaseService {
  static final LocalConfigService instance = LocalConfigService._init();
  SharedPreferences? _prefs;

  LocalConfigService._init();

  @override
  Future<void> onInit() async {
    // 使用独立的 SharedPreferences 实例，名称与参考项目一致
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取 SharedPreferences 实例
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ========== 本地密码管理 ==========

  /// 本地密码
  /// 用来对需要备份的敏感信息加密，如 webdav 配置等
  /// 参考项目：LocalConfig.password
  String? get password {
    if (_prefs == null) return null;
    return _prefs!.getString('password');
  }

  Future<void> setPassword(String? value) async {
    final prefs = await _getPrefs();
    if (value != null) {
      await prefs.setString('password', value);
    } else {
      await prefs.remove('password');
    }
  }

  // ========== 备份相关 ==========

  /// 最后备份时间
  /// 参考项目：LocalConfig.lastBackup
  int get lastBackup {
    if (_prefs == null) return 0;
    return _prefs!.getInt('lastBackup') ?? 0;
  }

  Future<void> setLastBackup(int value) async {
    final prefs = await _getPrefs();
    await prefs.setInt('lastBackup', value);
  }

  // ========== 隐私政策 ==========

  /// 隐私政策确认
  /// 参考项目：LocalConfig.privacyPolicyOk
  bool get privacyPolicyOk {
    if (_prefs == null) return false;
    return _prefs!.getBool('privacyPolicyOk') ?? false;
  }

  Future<void> setPrivacyPolicyOk(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool('privacyPolicyOk', value);
  }

  // ========== 帮助版本检查 ==========

  /// 检查帮助版本是否为最新
  /// 参考项目：LocalConfig.isLastVersion()
  bool _isLastVersion(int lastVersion, String versionKey,
      {String? firstOpenKey}) {
    if (_prefs == null) return false;

    var version = _prefs!.getInt(versionKey) ?? 0;
    if (version == 0 && firstOpenKey != null) {
      // 如果版本为0且存在首次打开键，检查是否首次打开
      if (!(_prefs!.getBool(firstOpenKey) ?? true)) {
        version = 1;
      }
    }

    return version >= lastVersion;
  }

  /// 阅读帮助版本是否为最新
  /// 参考项目：LocalConfig.readHelpVersionIsLast
  bool get readHelpVersionIsLast {
    return _isLastVersion(1, 'readHelpVersion', firstOpenKey: 'firstRead');
  }

  /// 备份帮助版本是否为最新
  /// 参考项目：LocalConfig.backupHelpVersionIsLast
  bool get backupHelpVersionIsLast {
    return _isLastVersion(1, 'backupHelpVersion', firstOpenKey: 'firstBackup');
  }

  /// 阅读菜单帮助版本是否为最新
  /// 参考项目：LocalConfig.readMenuHelpVersionIsLast
  bool get readMenuHelpVersionIsLast {
    return _isLastVersion(1, 'readMenuHelpVersion',
        firstOpenKey: 'firstReadMenu');
  }

  /// 书源帮助版本是否为最新
  /// 参考项目：LocalConfig.bookSourcesHelpVersionIsLast
  bool get bookSourcesHelpVersionIsLast {
    return _isLastVersion(1, 'bookSourceHelpVersion',
        firstOpenKey: 'firstOpenBookSources');
  }

  /// WebDAV书籍帮助版本是否为最新
  /// 参考项目：LocalConfig.webDavBookHelpVersionIsLast
  bool get webDavBookHelpVersionIsLast {
    return _isLastVersion(1, 'webDavBookHelpVersion',
        firstOpenKey: 'firstOpenWebDavBook');
  }

  /// 规则帮助版本是否为最新
  /// 参考项目：LocalConfig.ruleHelpVersionIsLast
  bool get ruleHelpVersionIsLast {
    return _isLastVersion(1, 'ruleHelpVersion');
  }

  // ========== 数据更新检查 ==========

  /// 需要更新 HTTP TTS
  /// 参考项目：LocalConfig.needUpHttpTTS
  bool get needUpHttpTTS {
    return !_isLastVersion(6, 'httpTtsVersion');
  }

  /// 需要更新 TXT 目录规则
  /// 参考项目：LocalConfig.needUpTxtTocRule
  bool get needUpTxtTocRule {
    return !_isLastVersion(3, 'txtTocRuleVersion');
  }

  /// 需要更新 RSS 源
  /// 参考项目：LocalConfig.needUpRssSources
  bool get needUpRssSources {
    return !_isLastVersion(6, 'rssSourceVersion');
  }

  /// 需要更新字典规则
  /// 参考项目：LocalConfig.needUpDictRule
  bool get needUpDictRule {
    return !_isLastVersion(2, 'needUpDictRule');
  }

  /// 设置数据版本
  /// [versionKey] 版本键
  /// [version] 版本号
  Future<void> setDataVersion(String versionKey, int version) async {
    final prefs = await _getPrefs();
    await prefs.setInt(versionKey, version);
  }

  /// 获取数据版本
  /// [versionKey] 版本键
  /// 返回版本号，如果不存在则返回 0
  int getDataVersion(String versionKey) {
    if (_prefs == null) return 0;
    return _prefs!.getInt(versionKey) ?? 0;
  }

  // ========== 应用版本 ==========

  /// 应用版本号
  /// 参考项目：LocalConfig.versionCode
  int get versionCode {
    if (_prefs == null) return 0;
    return _prefs!.getInt('appVersionCode') ?? 0;
  }

  Future<void> setVersionCode(int value) async {
    final prefs = await _getPrefs();
    await prefs.setInt('appVersionCode', value);
  }

  /// 是否首次打开应用
  /// 参考项目：LocalConfig.isFirstOpenApp
  /// 注意：调用此方法后会自动设置为 false
  bool get isFirstOpenApp {
    if (_prefs == null) return true;

    final value = _prefs!.getBool('firstOpen') ?? true;
    if (value) {
      // 自动设置为 false
      _prefs!.setBool('firstOpen', false);
    }
    return value;
  }

  /// 设置首次打开标志
  Future<void> setFirstOpen(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool('firstOpen', value);
  }

  /// 初始化应用版本号
  /// 从 package_info_plus 获取当前版本号并保存
  Future<void> initVersionCode() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      await setVersionCode(buildNumber);
    } catch (e) {
      AppLog.instance.put('初始化应用版本号失败', error: e);
    }
  }

  /// 检查是否需要更新应用版本
  /// 如果当前保存的版本号小于当前应用版本号，返回 true
  Future<bool> needUpdateVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final savedVersionCode = versionCode;
      return currentBuildNumber > savedVersionCode;
    } catch (e) {
      AppLog.instance.put('检查应用版本失败', error: e);
      return false;
    }
  }
}
