import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/prefer_key.dart';

/// 应用配置管理
/// 参考项目：io.legado.app.help.Prefer
class AppConfig {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 获取字符串
  static String getString(String key, {String defaultValue = ''}) {
    return _prefs.getString(key) ?? defaultValue;
  }

  // 设置字符串
  static Future<bool> setString(String key, String value) {
    return _prefs.setString(key, value);
  }

  // 获取整数
  static int getInt(String key, {int defaultValue = 0}) {
    return _prefs.getInt(key) ?? defaultValue;
  }

  // 设置整数
  static Future<bool> setInt(String key, int value) {
    return _prefs.setInt(key, value);
  }

  // 获取布尔值
  static bool getBool(String key, {bool defaultValue = false}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  // 设置布尔值
  static Future<bool> setBool(String key, bool value) {
    return _prefs.setBool(key, value);
  }

  // 获取双精度浮点数
  static double getDouble(String key, {double defaultValue = 0.0}) {
    return _prefs.getDouble(key) ?? defaultValue;
  }

  // 设置双精度浮点数
  static Future<bool> setDouble(String key, double value) {
    return _prefs.setDouble(key, value);
  }

  // 删除
  static Future<bool> remove(String key) {
    return _prefs.remove(key);
  }

  // 清空
  static Future<bool> clear() {
    return _prefs.clear();
  }

  // ========== 书架相关配置 ==========
  /// 书架布局配置
  /// 0: 列表布局, 1-4: 网格布局（列数 = bookshelfLayout + 2）
  static int getBookshelfLayout() {
    return getInt(PreferKey.bookshelfLayout, defaultValue: 0);
  }

  static Future<bool> setBookshelfLayout(int layout) {
    return setInt(PreferKey.bookshelfLayout, layout);
  }

  /// 书架排序
  static int getBookshelfSort() {
    return getInt(PreferKey.bookshelfSort, defaultValue: 0);
  }

  static Future<bool> setBookshelfSort(int sort) {
    return setInt(PreferKey.bookshelfSort, sort);
  }

  /// 显示未读
  static bool getShowUnread() {
    return getBool(PreferKey.showUnread, defaultValue: false);
  }

  static Future<bool> setShowUnread(bool value) {
    return setBool(PreferKey.showUnread, value);
  }

  /// 显示发现
  static bool getShowDiscovery() {
    return getBool(PreferKey.showDiscovery, defaultValue: true);
  }

  static Future<bool> setShowDiscovery(bool value) {
    return setBool(PreferKey.showDiscovery, value);
  }

  /// 显示 RSS
  static bool getShowRss() {
    return getBool(PreferKey.showRss, defaultValue: true);
  }

  static Future<bool> setShowRss(bool value) {
    return setBool(PreferKey.showRss, value);
  }

  // ========== 共用布局配置 ==========
  /// 共用布局
  static bool getSharedLayout() {
    return getBool(PreferKey.shareLayout, defaultValue: false);
  }

  static Future<bool> setSharedLayout(bool value) {
    return setBool(PreferKey.shareLayout, value);
  }

  /// 获取共用布局配置（JSON字符串）
  static String? getSharedReadConfig() {
    return getString('shared_read_config');
  }

  /// 保存共用布局配置（JSON字符串）
  static Future<bool> setSharedReadConfig(String configJson) {
    return setString('shared_read_config', configJson);
  }

  // ========== 简繁转换 ==========
  /// 简繁转换类型：0: 关闭, 1: 繁体转简体, 2: 简体转繁体
  static int getChineseConverterType() {
    return getInt(PreferKey.chineseConverterType, defaultValue: 0);
  }

  static Future<bool> setChineseConverterType(int type) {
    return setInt(PreferKey.chineseConverterType, type);
  }

  // ========== 阅读记录 ==========
  /// 启用阅读记录
  static bool getEnableReadRecord() {
    return getBool(PreferKey.enableReadRecord, defaultValue: true);
  }

  static Future<bool> setEnableReadRecord(bool value) {
    return setBool(PreferKey.enableReadRecord, value);
  }

  // ========== 亮度相关 ==========
  /// 阅读亮度（0-255）
  /// 根据当前主题模式返回对应的亮度值
  /// 参考项目：AppConfig.readBrightness
  static int getReadBrightness({bool? systemIsDark}) {
    if (isNightTheme(systemIsDark: systemIsDark)) {
      return getNightBrightness();
    } else {
      return getBrightness();
    }
  }

  /// 设置阅读亮度
  /// 根据当前主题模式设置对应的亮度值
  static Future<bool> setReadBrightness(int brightness,
      {bool? systemIsDark}) async {
    if (isNightTheme(systemIsDark: systemIsDark)) {
      return await setNightBrightness(brightness);
    } else {
      return await setBrightness(brightness);
    }
  }

  /// 日间亮度
  static int getBrightness() {
    return getInt(PreferKey.brightness, defaultValue: 128);
  }

  static Future<bool> setBrightness(int brightness) {
    return setInt(PreferKey.brightness, brightness);
  }

  /// 夜间亮度
  static int getNightBrightness() {
    return getInt(PreferKey.nightBrightness, defaultValue: 128);
  }

  static Future<bool> setNightBrightness(int brightness) {
    return setInt(PreferKey.nightBrightness, brightness);
  }

  /// 亮度自动跟随
  static bool getBrightnessAuto() {
    return getBool(PreferKey.brightnessAuto, defaultValue: true);
  }

  static Future<bool> setBrightnessAuto(bool value) {
    return setBool(PreferKey.brightnessAuto, value);
  }

  /// 音量键翻页
  static bool getVolumeKeyPage() {
    return getBool(PreferKey.volumeKeyPage, defaultValue: true);
  }

  static Future<bool> setVolumeKeyPage(bool value) {
    return setBool(PreferKey.volumeKeyPage, value);
  }

  /// 显示亮度视图
  static bool getShowBrightnessView() {
    return getBool(PreferKey.showBrightnessView, defaultValue: true);
  }

  static Future<bool> setShowBrightnessView(bool value) {
    return setBool(PreferKey.showBrightnessView, value);
  }

  /// 保持屏幕常亮
  static bool getKeepLight() {
    return getBool(PreferKey.keepLight, defaultValue: false);
  }

  static Future<bool> setKeepLight(bool value) {
    return setBool(PreferKey.keepLight, value);
  }

  // ========== Web服务 ==========
  /// Web服务
  static bool getWebService() {
    return getBool(PreferKey.webService, defaultValue: false);
  }

  static Future<bool> setWebService(bool value) {
    return setBool(PreferKey.webService, value);
  }

  /// Web端口
  static int getWebPort() {
    return getInt(PreferKey.webPort, defaultValue: 1234);
  }

  static Future<bool> setWebPort(int port) {
    return setInt(PreferKey.webPort, port);
  }

  // ========== 语言和主题 ==========
  /// 语言
  static String getLanguage() {
    return getString(PreferKey.language, defaultValue: 'zh_CN');
  }

  static Future<bool> setLanguage(String language) {
    return setString(PreferKey.language, language);
  }

  /// 字体缩放
  static double getFontScale() {
    return getDouble(PreferKey.fontScale, defaultValue: 1.0);
  }

  static Future<bool> setFontScale(double scale) {
    return setDouble(PreferKey.fontScale, scale);
  }

  /// 主题模式
  /// 0: 跟随系统, 1: 日间, 2: 夜间, 3: 电子墨水
  static int getThemeMode() {
    return getInt(PreferKey.themeMode, defaultValue: 2); // 2: Auto
  }

  static Future<bool> setThemeMode(int mode) {
    return setInt(PreferKey.themeMode, mode);
  }

  /// 是否电子墨水模式
  /// 参考项目：AppConfig.isEInkMode
  static bool isEInkMode() {
    return getThemeMode() == 3;
  }

  /// 是否夜间主题
  /// 参考项目：AppConfig.isNightTheme
  /// 0: 跟随系统, 1: 日间, 2: 夜间, 3: 电子墨水
  /// 注意：Flutter 中需要手动检查系统夜间模式（通过 MediaQuery.platformBrightness）
  static bool isNightTheme({bool? systemIsDark}) {
    final themeMode = getThemeMode();
    switch (themeMode) {
      case 1: // 日间
        return false;
      case 2: // 夜间
        return true;
      case 3: // 电子墨水
        return false;
      default: // 0: 跟随系统
        // 如果提供了系统状态，使用提供的值；否则默认返回 false
        return systemIsDark ?? false;
    }
  }

  /// 设置夜间主题
  /// 参考项目：AppConfig.isNightTheme setter
  static Future<bool> setIsNightTheme(bool value) async {
    final currentIsNight = isNightTheme();
    if (currentIsNight != value) {
      if (value) {
        return await setThemeMode(2); // 夜间
      } else {
        return await setThemeMode(1); // 日间
      }
    }
    return true;
  }

  /// 用户代理
  static String getUserAgent() {
    return getString(PreferKey.userAgent, defaultValue: '');
  }

  static Future<bool> setUserAgent(String userAgent) {
    return setString(PreferKey.userAgent, userAgent);
  }

  // ========== 封面相关 ==========
  /// 使用默认封面
  static bool getUseDefaultCover() {
    return getBool(PreferKey.useDefaultCover, defaultValue: false);
  }

  static Future<bool> setUseDefaultCover(bool value) {
    return setBool(PreferKey.useDefaultCover, value);
  }

  /// 仅在 WiFi 下加载封面
  static bool getLoadCoverOnlyWifi() {
    return getBool(PreferKey.loadCoverOnlyWifi, defaultValue: false);
  }

  static Future<bool> setLoadCoverOnlyWifi(bool value) {
    return setBool(PreferKey.loadCoverOnlyWifi, value);
  }

  /// 封面显示名称
  static bool getCoverShowName() {
    return getBool(PreferKey.coverShowName, defaultValue: true);
  }

  static Future<bool> setCoverShowName(bool value) {
    return setBool(PreferKey.coverShowName, value);
  }

  /// 封面显示作者
  static bool getCoverShowAuthor() {
    return getBool(PreferKey.coverShowAuthor, defaultValue: true);
  }

  static Future<bool> setCoverShowAuthor(bool value) {
    return setBool(PreferKey.coverShowAuthor, value);
  }

  // ========== 预下载和缓存 ==========
  /// 预下载数量
  static int getPreDownloadNum() {
    return getInt(PreferKey.preDownloadNum, defaultValue: 3);
  }

  static Future<bool> setPreDownloadNum(int num) {
    return setInt(PreferKey.preDownloadNum, num);
  }

  /// 线程数
  static int getThreadCount() {
    return getInt(PreferKey.threadCount, defaultValue: 9);
  }

  static Future<bool> setThreadCount(int count) {
    return setInt(PreferKey.threadCount, count);
  }

  /// 自动清理过期缓存
  static bool getAutoClearExpired() {
    return getBool(PreferKey.autoClearExpired, defaultValue: false);
  }

  static Future<bool> setAutoClearExpired(bool value) {
    return setBool(PreferKey.autoClearExpired, value);
  }

  // ========== 导出相关 ==========
  /// 书籍导出文件名模板
  static String getBookExportFileName() {
    return getString(PreferKey.bookExportFileName, defaultValue: '{bookName}');
  }

  static Future<bool> setBookExportFileName(String template) {
    return setString(PreferKey.bookExportFileName, template);
  }

  /// 章节导出文件名模板
  static String getEpisodeExportFileName() {
    return getString(PreferKey.episodeExportFileName,
        defaultValue: '{bookName} [{epubIndex}]');
  }

  static Future<bool> setEpisodeExportFileName(String template) {
    return setString(PreferKey.episodeExportFileName, template);
  }

  /// 导出字符集
  static String getExportCharset() {
    return getString(PreferKey.exportCharset, defaultValue: 'UTF-8');
  }

  static Future<bool> setExportCharset(String charset) {
    return setString(PreferKey.exportCharset, charset);
  }

  /// 导出使用替换规则
  static bool getExportUseReplace() {
    return getBool(PreferKey.exportUseReplace, defaultValue: true);
  }

  static Future<bool> setExportUseReplace(bool value) {
    return setBool(PreferKey.exportUseReplace, value);
  }

  // ========== 换源相关 ==========
  /// 换源检查作者
  static bool getChangeSourceCheckAuthor() {
    return getBool(PreferKey.changeSourceCheckAuthor, defaultValue: true);
  }

  static Future<bool> setChangeSourceCheckAuthor(bool value) {
    return setBool(PreferKey.changeSourceCheckAuthor, value);
  }

  /// 换源加载目录
  static bool getChangeSourceLoadToc() {
    return getBool(PreferKey.changeSourceLoadToc, defaultValue: true);
  }

  static Future<bool> setChangeSourceLoadToc(bool value) {
    return setBool(PreferKey.changeSourceLoadToc, value);
  }

  /// 自动换源
  static bool getAutoChangeSource() {
    return getBool(PreferKey.autoChangeSource, defaultValue: false);
  }

  static Future<bool> setAutoChangeSource(bool value) {
    return setBool(PreferKey.autoChangeSource, value);
  }

  // ========== 其他设置 ==========
  /// 记录日志
  static bool getRecordLog() {
    return getBool(PreferKey.recordLog, defaultValue: false);
  }

  static Future<bool> setRecordLog(bool value) {
    return setBool(PreferKey.recordLog, value);
  }

  /// 目录统计字数
  static bool getTocCountWords() {
    return getBool(PreferKey.tocCountWords, defaultValue: false);
  }

  static Future<bool> setTocCountWords(bool value) {
    return setBool(PreferKey.tocCountWords, value);
  }

  /// 去除重复标题
  static bool getRemoveSameTitle() {
    return getBool(PreferKey.removeSameTitle, defaultValue: true);
  }

  static Future<bool> setRemoveSameTitle(bool value) {
    return setBool(PreferKey.removeSameTitle, value);
  }

  /// 精确搜索
  static bool getPrecisionSearch() {
    return getBool(PreferKey.precisionSearch, defaultValue: false);
  }

  static Future<bool> setPrecisionSearch(bool value) {
    return setBool(PreferKey.precisionSearch, value);
  }

  /// 显示最后更新时间
  static bool getShowLastUpdateTime() {
    return getBool(PreferKey.showLastUpdateTime, defaultValue: false);
  }

  static Future<bool> setShowLastUpdateTime(bool value) {
    return setBool(PreferKey.showLastUpdateTime, value);
  }

  /// 显示待更新数量
  static bool getShowWaitUpCount() {
    return getBool(PreferKey.showWaitUpCount, defaultValue: false);
  }

  static Future<bool> setShowWaitUpCount(bool value) {
    return setBool(PreferKey.showWaitUpCount, value);
  }

  /// 自动刷新
  static bool getAutoRefresh() {
    return getBool(PreferKey.autoRefresh, defaultValue: false);
  }

  static Future<bool> setAutoRefresh(bool value) {
    return setBool(PreferKey.autoRefresh, value);
  }

  // ========== 点击操作配置 ==========
  /// 顶部左侧点击操作
  /// 参考项目：AppConfig.clickActionTL
  /// 默认值：2
  static int getClickActionTL() {
    return getInt(PreferKey.clickActionTL, defaultValue: 2);
  }

  static Future<bool> setClickActionTL(int value) {
    return setInt(PreferKey.clickActionTL, value);
  }

  /// 顶部中间点击操作
  /// 参考项目：AppConfig.clickActionTC
  /// 默认值：2
  static int getClickActionTC() {
    return getInt(PreferKey.clickActionTC, defaultValue: 2);
  }

  static Future<bool> setClickActionTC(int value) {
    return setInt(PreferKey.clickActionTC, value);
  }

  /// 顶部右侧点击操作
  /// 参考项目：AppConfig.clickActionTR
  /// 默认值：1
  static int getClickActionTR() {
    return getInt(PreferKey.clickActionTR, defaultValue: 1);
  }

  static Future<bool> setClickActionTR(int value) {
    return setInt(PreferKey.clickActionTR, value);
  }

  /// 中间左侧点击操作
  /// 参考项目：AppConfig.clickActionML
  /// 默认值：2
  static int getClickActionML() {
    return getInt(PreferKey.clickActionML, defaultValue: 2);
  }

  static Future<bool> setClickActionML(int value) {
    return setInt(PreferKey.clickActionML, value);
  }

  /// 中间中间点击操作
  /// 参考项目：AppConfig.clickActionMC
  /// 默认值：0
  static int getClickActionMC() {
    return getInt(PreferKey.clickActionMC, defaultValue: 0);
  }

  static Future<bool> setClickActionMC(int value) {
    return setInt(PreferKey.clickActionMC, value);
  }

  /// 中间右侧点击操作
  /// 参考项目：AppConfig.clickActionMR
  /// 默认值：1
  static int getClickActionMR() {
    return getInt(PreferKey.clickActionMR, defaultValue: 1);
  }

  static Future<bool> setClickActionMR(int value) {
    return setInt(PreferKey.clickActionMR, value);
  }

  /// 底部左侧点击操作
  /// 参考项目：AppConfig.clickActionBL
  /// 默认值：2
  static int getClickActionBL() {
    return getInt(PreferKey.clickActionBL, defaultValue: 2);
  }

  static Future<bool> setClickActionBL(int value) {
    return setInt(PreferKey.clickActionBL, value);
  }

  /// 底部中间点击操作
  /// 参考项目：AppConfig.clickActionBC
  /// 默认值：1
  static int getClickActionBC() {
    return getInt(PreferKey.clickActionBC, defaultValue: 1);
  }

  static Future<bool> setClickActionBC(int value) {
    return setInt(PreferKey.clickActionBC, value);
  }

  /// 底部右侧点击操作
  /// 参考项目：AppConfig.clickActionBR
  /// 默认值：1
  static int getClickActionBR() {
    return getInt(PreferKey.clickActionBR, defaultValue: 1);
  }

  static Future<bool> setClickActionBR(int value) {
    return setInt(PreferKey.clickActionBR, value);
  }

  // ========== 其他配置 ==========
  /// 使用 Cronet
  /// 参考项目：AppConfig.isCronet
  static bool getCronet() {
    return getBool(PreferKey.cronet, defaultValue: false);
  }

  static Future<bool> setCronet(bool value) {
    return setBool(PreferKey.cronet, value);
  }

  /// 使用抗锯齿
  /// 参考项目：AppConfig.useAntiAlias
  static bool getAntiAlias() {
    return getBool(PreferKey.antiAlias, defaultValue: true);
  }

  static Future<bool> setAntiAlias(bool value) {
    return setBool(PreferKey.antiAlias, value);
  }

  /// 优化渲染
  /// 参考项目：AppConfig.optimizeRender
  static bool getOptimizeRender() {
    return getBool(PreferKey.optimizeRender, defaultValue: false);
  }

  static Future<bool> setOptimizeRender(bool value) {
    return setBool(PreferKey.optimizeRender, value);
  }

  // ========== UI 相关配置 ==========
  /// 文本可选择
  /// 参考项目：AppConfig.textSelectAble
  static bool getTextSelectAble() {
    return getBool(PreferKey.textSelectAble, defaultValue: true);
  }

  static Future<bool> setTextSelectAble(bool value) {
    return setBool(PreferKey.textSelectAble, value);
  }

  /// 透明状态栏
  /// 参考项目：AppConfig.isTransparentStatusBar
  static bool getTransparentStatusBar() {
    return getBool(PreferKey.transparentStatusBar, defaultValue: true);
  }

  static Future<bool> setTransparentStatusBar(bool value) {
    return setBool(PreferKey.transparentStatusBar, value);
  }

  /// 沉浸式导航栏
  /// 参考项目：AppConfig.immNavigationBar
  static bool getImmNavigationBar() {
    return getBool(PreferKey.immNavigationBar, defaultValue: true);
  }

  static Future<bool> setImmNavigationBar(bool value) {
    return setBool(PreferKey.immNavigationBar, value);
  }

  /// 屏幕方向
  /// 参考项目：AppConfig.screenOrientation
  static String? getScreenOrientation() {
    return getString(PreferKey.screenOrientation, defaultValue: '');
  }

  static Future<bool> setScreenOrientation(String? orientation) {
    if (orientation == null || orientation.isEmpty) {
      return remove(PreferKey.screenOrientation);
    }
    return setString(PreferKey.screenOrientation, orientation);
  }

  /// 书籍分组样式
  /// 参考项目：AppConfig.bookGroupStyle
  static int getBookGroupStyle() {
    return getInt(PreferKey.bookGroupStyle, defaultValue: 0);
  }

  static Future<bool> setBookGroupStyle(int style) {
    return setInt(PreferKey.bookGroupStyle, style);
  }

  /// 保存标签页位置
  /// 参考项目：AppConfig.saveTabPosition
  static int getSaveTabPosition() {
    return getInt(PreferKey.saveTabPosition, defaultValue: 0);
  }

  static Future<bool> setSaveTabPosition(int position) {
    return setInt(PreferKey.saveTabPosition, position);
  }

  /// 栏高度
  /// 参考项目：AppConfig.elevation
  /// 注意：电子墨水模式下返回 0
  static int getElevation() {
    if (isEInkMode()) {
      return 0;
    }
    return getInt(PreferKey.barElevation, defaultValue: 4);
  }

  static Future<bool> setElevation(int elevation) {
    return setInt(PreferKey.barElevation, elevation);
  }

  /// 阅读 URL 在浏览器中打开
  /// 参考项目：AppConfig.readUrlInBrowser
  static bool getReadUrlInBrowser() {
    return getBool(PreferKey.readUrlOpenInBrowser, defaultValue: false);
  }

  static Future<bool> setReadUrlInBrowser(bool value) {
    return setBool(PreferKey.readUrlOpenInBrowser, value);
  }

  /// 目录 UI 使用替换
  /// 参考项目：AppConfig.tocUiUseReplace
  static bool getTocUiUseReplace() {
    return getBool(PreferKey.tocUiUseReplace, defaultValue: false);
  }

  static Future<bool> setTocUiUseReplace(bool value) {
    return setBool(PreferKey.tocUiUseReplace, value);
  }

  // ========== 导出相关配置 ==========
  /// 导出到 WebDAV
  /// 参考项目：AppConfig.exportToWebDav
  static bool getExportToWebDav() {
    return getBool(PreferKey.exportToWebDav, defaultValue: false);
  }

  static Future<bool> setExportToWebDav(bool value) {
    return setBool(PreferKey.exportToWebDav, value);
  }

  /// 导出无章节名
  /// 参考项目：AppConfig.exportNoChapterName
  static bool getExportNoChapterName() {
    return getBool(PreferKey.exportNoChapterName, defaultValue: false);
  }

  static Future<bool> setExportNoChapterName(bool value) {
    return setBool(PreferKey.exportNoChapterName, value);
  }

  /// 启用自定义导出
  /// 参考项目：AppConfig.enableCustomExport
  static bool getEnableCustomExport() {
    return getBool(PreferKey.enableCustomExport, defaultValue: false);
  }

  static Future<bool> setEnableCustomExport(bool value) {
    return setBool(PreferKey.enableCustomExport, value);
  }

  /// 导出类型
  /// 参考项目：AppConfig.exportType
  static int getExportType() {
    return getInt(PreferKey.exportType, defaultValue: 0);
  }

  static Future<bool> setExportType(int type) {
    return setInt(PreferKey.exportType, type);
  }

  /// 导出图片文件
  /// 参考项目：AppConfig.exportPictureFile
  static bool getExportPictureFile() {
    return getBool(PreferKey.exportPictureFile, defaultValue: false);
  }

  static Future<bool> setExportPictureFile(bool value) {
    return setBool(PreferKey.exportPictureFile, value);
  }

  /// 并行导出书籍
  /// 参考项目：AppConfig.parallelExportBook
  static bool getParallelExportBook() {
    return getBool(PreferKey.parallelExportBook, defaultValue: false);
  }

  static Future<bool> setParallelExportBook(bool value) {
    return setBool(PreferKey.parallelExportBook, value);
  }

  // ========== TTS 相关配置 ==========
  /// TTS 引擎
  /// 参考项目：AppConfig.ttsEngine
  static String? getTtsEngine() {
    return getString(PreferKey.ttsEngine, defaultValue: '');
  }

  static Future<bool> setTtsEngine(String? engine) {
    if (engine == null || engine.isEmpty) {
      return remove(PreferKey.ttsEngine);
    }
    return setString(PreferKey.ttsEngine, engine);
  }

  /// TTS 跟随系统
  /// 参考项目：AppConfig.ttsFlowSys
  static bool getTtsFollowSys() {
    return getBool(PreferKey.ttsFollowSys, defaultValue: true);
  }

  static Future<bool> setTtsFollowSys(bool value) {
    return setBool(PreferKey.ttsFollowSys, value);
  }

  /// TTS 语速
  /// 参考项目：AppConfig.ttsSpeechRate
  /// 默认值：5
  static int getTtsSpeechRate() {
    return getInt(PreferKey.ttsSpeechRate, defaultValue: 5);
  }

  static Future<bool> setTtsSpeechRate(int rate) {
    return setInt(PreferKey.ttsSpeechRate, rate);
  }

  /// TTS 定时器
  /// 参考项目：AppConfig.ttsTimer
  static int getTtsTimer() {
    return getInt(PreferKey.ttsTimer, defaultValue: 0);
  }

  static Future<bool> setTtsTimer(int timer) {
    return setInt(PreferKey.ttsTimer, timer);
  }

  /// 系统字体
  /// 参考项目：AppConfig.systemTypefaces
  static int getSystemTypefaces() {
    return getInt(PreferKey.systemTypefaces, defaultValue: 0);
  }

  static Future<bool> setSystemTypefaces(int typefaces) {
    return setInt(PreferKey.systemTypefaces, typefaces);
  }

  // ========== 文件路径相关配置 ==========
  /// 备份路径
  /// 参考项目：AppConfig.backupPath
  static String? getBackupPath() {
    final path = getString(PreferKey.backupPath, defaultValue: '');
    return path.isEmpty ? null : path;
  }

  static Future<bool> setBackupPath(String? path) {
    if (path == null || path.isEmpty) {
      return remove(PreferKey.backupPath);
    }
    return setString(PreferKey.backupPath, path);
  }

  /// 默认书籍树 URI
  /// 参考项目：AppConfig.defaultBookTreeUri
  static String? getDefaultBookTreeUri() {
    final uri = getString(PreferKey.defaultBookTreeUri, defaultValue: '');
    return uri.isEmpty ? null : uri;
  }

  static Future<bool> setDefaultBookTreeUri(String? uri) {
    if (uri == null || uri.isEmpty) {
      return remove(PreferKey.defaultBookTreeUri);
    }
    return setString(PreferKey.defaultBookTreeUri, uri);
  }

  /// 导入书籍路径
  /// 参考项目：AppConfig.importBookPath
  static String? getImportBookPath() {
    final path = getString('importBookPath', defaultValue: '');
    return path.isEmpty ? null : path;
  }

  static Future<bool> setImportBookPath(String? path) {
    if (path == null || path.isEmpty) {
      return remove('importBookPath');
    }
    return setString('importBookPath', path);
  }

  /// 书籍导入文件名
  /// 参考项目：AppConfig.bookImportFileName
  static String? getBookImportFileName() {
    final fileName = getString(PreferKey.bookImportFileName, defaultValue: '');
    return fileName.isEmpty ? null : fileName;
  }

  static Future<bool> setBookImportFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      return remove(PreferKey.bookImportFileName);
    }
    return setString(PreferKey.bookImportFileName, fileName);
  }

  // ========== 阅读相关配置 ==========
  /// 双页横向
  /// 参考项目：AppConfig.doublePageHorizontal
  static String? getDoublePageHorizontal() {
    final value = getString(PreferKey.doublePageHorizontal, defaultValue: '');
    return value.isEmpty ? null : value;
  }

  static Future<bool> setDoublePageHorizontal(String? value) {
    if (value == null || value.isEmpty) {
      return remove(PreferKey.doublePageHorizontal);
    }
    return setString(PreferKey.doublePageHorizontal, value);
  }

  /// 进度条行为
  /// 参考项目：AppConfig.progressBarBehavior
  static String getProgressBarBehavior() {
    return getString(PreferKey.progressBarBehavior, defaultValue: 'page');
  }

  static Future<bool> setProgressBarBehavior(String behavior) {
    return setString(PreferKey.progressBarBehavior, behavior);
  }

  /// 按键长按翻页
  /// 参考项目：AppConfig.keyPageOnLongPress
  static bool getKeyPageOnLongPress() {
    return getBool(PreferKey.keyPageOnLongPress, defaultValue: false);
  }

  static Future<bool> setKeyPageOnLongPress(bool value) {
    return setBool(PreferKey.keyPageOnLongPress, value);
  }

  /// 播放时音量键翻页
  /// 参考项目：AppConfig.volumeKeyPageOnPlay
  static bool getVolumeKeyPageOnPlay() {
    return getBool(PreferKey.volumeKeyPageOnPlay, defaultValue: true);
  }

  static Future<bool> setVolumeKeyPageOnPlay(bool value) {
    return setBool(PreferKey.volumeKeyPageOnPlay, value);
  }

  /// 鼠标滚轮翻页
  /// 参考项目：AppConfig.mouseWheelPage
  static bool getMouseWheelPage() {
    return getBool(PreferKey.mouseWheelPage, defaultValue: true);
  }

  static Future<bool> setMouseWheelPage(bool value) {
    return setBool(PreferKey.mouseWheelPage, value);
  }

  /// 填充显示缺口
  /// 参考项目：AppConfig.paddingDisplayCutouts
  static bool getPaddingDisplayCutouts() {
    return getBool(PreferKey.paddingDisplayCutouts, defaultValue: false);
  }

  static Future<bool> setPaddingDisplayCutouts(bool value) {
    return setBool(PreferKey.paddingDisplayCutouts, value);
  }

  /// 页面触摸滑动
  /// 参考项目：AppConfig.pageTouchSlop
  static int getPageTouchSlop() {
    return getInt(PreferKey.pageTouchSlop, defaultValue: 0);
  }

  static Future<bool> setPageTouchSlop(int slop) {
    return setInt(PreferKey.pageTouchSlop, slop);
  }

  /// 显示阅读标题栏附加信息
  /// 参考项目：AppConfig.showReadTitleBarAddition
  static bool getShowReadTitleBarAddition() {
    return getBool(PreferKey.showReadTitleAddition, defaultValue: true);
  }

  static Future<bool> setShowReadTitleBarAddition(bool value) {
    return setBool(PreferKey.showReadTitleAddition, value);
  }

  /// 阅读栏样式跟随页面
  /// 参考项目：AppConfig.readBarStyleFollowPage
  static bool getReadBarStyleFollowPage() {
    return getBool(PreferKey.readBarStyleFollowPage, defaultValue: false);
  }

  static Future<bool> setReadBarStyleFollowPage(bool value) {
    return setBool(PreferKey.readBarStyleFollowPage, value);
  }

  /// 禁用点击滚动
  /// 参考项目：AppConfig.disableClickScroll
  static bool getDisableClickScroll() {
    return getBool(PreferKey.disableClickScroll, defaultValue: false);
  }

  static Future<bool> setDisableClickScroll(bool value) {
    return setBool(PreferKey.disableClickScroll, value);
  }

  /// 禁用横向页面快照
  /// 参考项目：AppConfig.disableHorizontalPageSnap
  static bool getDisableHorizontalPageSnap() {
    return getBool(PreferKey.disableHorizontalPageSnap, defaultValue: false);
  }

  static Future<bool> setDisableHorizontalPageSnap(bool value) {
    return setBool(PreferKey.disableHorizontalPageSnap, value);
  }

  /// 亮度视图位置
  /// 参考项目：AppConfig.brightnessVwPos
  static bool getBrightnessVwPos() {
    return getBool(PreferKey.brightnessVwPos, defaultValue: false);
  }

  static Future<bool> setBrightnessVwPos(bool value) {
    return setBool(PreferKey.brightnessVwPos, value);
  }

  // ========== 搜索相关配置 ==========
  /// 搜索范围
  /// 参考项目：AppConfig.searchScope
  static String getSearchScope() {
    return getString('searchScope', defaultValue: '');
  }

  static Future<bool> setSearchScope(String scope) {
    return setString('searchScope', scope);
  }

  /// 搜索分组
  /// 参考项目：AppConfig.searchGroup
  static String getSearchGroup() {
    return getString('searchGroup', defaultValue: '');
  }

  static Future<bool> setSearchGroup(String group) {
    return setString('searchGroup', group);
  }

  /// 搜索历史排序方式（0=时间，1=使用次数）
  static int getSearchHistorySortMode() {
    return getInt(PreferKey.searchHistorySortMode, defaultValue: 0);
  }

  static Future<bool> setSearchHistorySortMode(int mode) {
    return setInt(PreferKey.searchHistorySortMode, mode);
  }

  // ========== 缓存和图片相关配置 ==========
  /// 位图缓存大小
  /// 参考项目：AppConfig.bitmapCacheSize
  static int getBitmapCacheSize() {
    return getInt(PreferKey.bitmapCacheSize, defaultValue: 50);
  }

  static Future<bool> setBitmapCacheSize(int size) {
    return setInt(PreferKey.bitmapCacheSize, size);
  }

  /// 图片保留数量
  /// 参考项目：AppConfig.imageRetainNum
  static int getImageRetainNum() {
    return getInt(PreferKey.imageRetainNum, defaultValue: 0);
  }

  static Future<bool> setImageRetainNum(int num) {
    return setInt(PreferKey.imageRetainNum, num);
  }

  // ========== 源编辑相关配置 ==========
  /// 源编辑最大行数
  /// 参考项目：AppConfig.sourceEditMaxLine
  static int getSourceEditMaxLine() {
    final maxLine = getInt(PreferKey.sourceEditMaxLine,
        defaultValue: 2147483647); // Int.MAX_VALUE
    if (maxLine < 10) {
      return 2147483647;
    }
    return maxLine;
  }

  static Future<bool> setSourceEditMaxLine(int maxLine) {
    return setInt(PreferKey.sourceEditMaxLine, maxLine);
  }

  // ========== 音频播放相关配置 ==========
  /// 音频播放使用 WakeLock
  /// 参考项目：AppConfig.audioPlayUseWakeLock
  static bool getAudioPlayUseWakeLock() {
    return getBool(PreferKey.audioPlayWakeLock, defaultValue: false);
  }

  static Future<bool> setAudioPlayUseWakeLock(bool value) {
    return setBool(PreferKey.audioPlayWakeLock, value);
  }

  // ========== 漫画相关配置 ==========
  /// 显示漫画 UI
  /// 参考项目：AppConfig.showMangaUi
  static bool getShowMangaUi() {
    return getBool(PreferKey.showMangaUi, defaultValue: true);
  }

  static Future<bool> setShowMangaUi(bool value) {
    return setBool(PreferKey.showMangaUi, value);
  }

  /// 禁用漫画缩放
  /// 参考项目：AppConfig.disableMangaScale
  static bool getDisableMangaScale() {
    return getBool(PreferKey.disableMangaScale, defaultValue: true);
  }

  static Future<bool> setDisableMangaScale(bool value) {
    return setBool(PreferKey.disableMangaScale, value);
  }

  /// 漫画预下载数量
  /// 参考项目：AppConfig.mangaPreDownloadNum
  static int getMangaPreDownloadNum() {
    return getInt(PreferKey.mangaPreDownloadNum, defaultValue: 10);
  }

  static Future<bool> setMangaPreDownloadNum(int num) {
    return setInt(PreferKey.mangaPreDownloadNum, num);
  }

  /// 漫画自动翻页速度
  /// 参考项目：AppConfig.mangaAutoPageSpeed
  static int getMangaAutoPageSpeed() {
    return getInt(PreferKey.mangaAutoPageSpeed, defaultValue: 3);
  }

  static Future<bool> setMangaAutoPageSpeed(int speed) {
    return setInt(PreferKey.mangaAutoPageSpeed, speed);
  }

  /// 文本阅读自动翻页速度
  /// 参考项目：ReadBookConfig.autoReadSpeed
  static int getAutoReadSpeed() {
    return getInt(PreferKey.autoReadSpeed, defaultValue: 3);
  }

  static Future<bool> setAutoReadSpeed(int speed) {
    return setInt(PreferKey.autoReadSpeed, speed);
  }

  /// 漫画页脚配置
  /// 参考项目：AppConfig.mangaFooterConfig
  static String getMangaFooterConfig() {
    return getString(PreferKey.mangaFooterConfig, defaultValue: '');
  }

  static Future<bool> setMangaFooterConfig(String config) {
    return setString(PreferKey.mangaFooterConfig, config);
  }

  /// 启用漫画横向滚动
  /// 参考项目：AppConfig.enableMangaHorizontalScroll
  static bool getEnableMangaHorizontalScroll() {
    return getBool(PreferKey.enableMangaHorizontalScroll, defaultValue: false);
  }

  static Future<bool> setEnableMangaHorizontalScroll(bool value) {
    return setBool(PreferKey.enableMangaHorizontalScroll, value);
  }

  /// 漫画颜色滤镜
  /// 参考项目：AppConfig.mangaColorFilter
  static String getMangaColorFilter() {
    return getString(PreferKey.mangaColorFilter, defaultValue: '');
  }

  static Future<bool> setMangaColorFilter(String filter) {
    return setString(PreferKey.mangaColorFilter, filter);
  }

  /// 隐藏漫画标题
  /// 参考项目：AppConfig.hideMangaTitle
  static bool getHideMangaTitle() {
    return getBool(PreferKey.hideMangaTitle, defaultValue: false);
  }

  static Future<bool> setHideMangaTitle(bool value) {
    return setBool(PreferKey.hideMangaTitle, value);
  }

  /// 启用漫画电子墨水模式
  /// 参考项目：AppConfig.enableMangaEInk
  static bool getEnableMangaEInk() {
    return getBool(PreferKey.enableMangaEInk, defaultValue: false);
  }

  static Future<bool> setEnableMangaEInk(bool value) {
    return setBool(PreferKey.enableMangaEInk, value);
  }

  /// 漫画电子墨水阈值
  /// 参考项目：AppConfig.mangaEInkThreshold
  static int getMangaEInkThreshold() {
    return getInt(PreferKey.mangaEInkThreshold, defaultValue: 150);
  }

  static Future<bool> setMangaEInkThreshold(int threshold) {
    return setInt(PreferKey.mangaEInkThreshold, threshold);
  }

  /// 启用漫画灰度
  /// 参考项目：AppConfig.enableMangaGray
  static bool getEnableMangaGray() {
    return getBool(PreferKey.enableMangaGray, defaultValue: false);
  }

  static Future<bool> setEnableMangaGray(bool value) {
    return setBool(PreferKey.enableMangaGray, value);
  }

  // ========== 欢迎页相关配置 ==========
  /// 欢迎图片
  /// 参考项目：AppConfig.welcomeImage
  static String? getWelcomeImage() {
    final image = getString(PreferKey.welcomeImage, defaultValue: '');
    return image.isEmpty ? null : image;
  }

  static Future<bool> setWelcomeImage(String? image) {
    if (image == null || image.isEmpty) {
      return remove(PreferKey.welcomeImage);
    }
    return setString(PreferKey.welcomeImage, image);
  }

  /// 欢迎显示文本
  /// 参考项目：AppConfig.welcomeShowText
  static bool getWelcomeShowText() {
    return getBool(PreferKey.welcomeShowText, defaultValue: true);
  }

  static Future<bool> setWelcomeShowText(bool value) {
    return setBool(PreferKey.welcomeShowText, value);
  }

  /// 欢迎显示图标
  /// 参考项目：AppConfig.welcomeShowIcon
  static bool getWelcomeShowIcon() {
    return getBool(PreferKey.welcomeShowIcon, defaultValue: true);
  }

  static Future<bool> setWelcomeShowIcon(bool value) {
    return setBool(PreferKey.welcomeShowIcon, value);
  }

  /// 欢迎图片（暗色模式）
  /// 参考项目：AppConfig.welcomeImageDark
  static String? getWelcomeImageDark() {
    final image = getString(PreferKey.welcomeImageDark, defaultValue: '');
    return image.isEmpty ? null : image;
  }

  static Future<bool> setWelcomeImageDark(String? image) {
    if (image == null || image.isEmpty) {
      return remove(PreferKey.welcomeImageDark);
    }
    return setString(PreferKey.welcomeImageDark, image);
  }

  /// 欢迎显示文本（暗色模式）
  /// 参考项目：AppConfig.welcomeShowTextDark
  static bool getWelcomeShowTextDark() {
    return getBool(PreferKey.welcomeShowTextDark, defaultValue: true);
  }

  static Future<bool> setWelcomeShowTextDark(bool value) {
    return setBool(PreferKey.welcomeShowTextDark, value);
  }

  /// 欢迎显示图标（暗色模式）
  /// 参考项目：AppConfig.welcomeShowIconDark
  static bool getWelcomeShowIconDark() {
    return getBool(PreferKey.welcomeShowIconDark, defaultValue: true);
  }

  static Future<bool> setWelcomeShowIconDark(bool value) {
    return setBool(PreferKey.welcomeShowIconDark, value);
  }

  // ========== 远程服务器相关配置 ==========
  /// 远程服务器 ID
  /// 参考项目：AppConfig.remoteServerId
  static int getRemoteServerId() {
    return getInt(PreferKey.remoteServerId, defaultValue: 0);
  }

  static Future<bool> setRemoteServerId(int id) {
    return setInt(PreferKey.remoteServerId, id);
  }

  // ========== 导入相关配置 ==========
  /// 导入保持名称
  /// 参考项目：AppConfig.importKeepName
  static bool getImportKeepName() {
    return getBool(PreferKey.importKeepName, defaultValue: false);
  }

  static Future<bool> setImportKeepName(bool value) {
    return setBool(PreferKey.importKeepName, value);
  }

  /// 导入保持分组
  /// 参考项目：AppConfig.importKeepGroup
  static bool getImportKeepGroup() {
    return getBool(PreferKey.importKeepGroup, defaultValue: false);
  }

  static Future<bool> setImportKeepGroup(bool value) {
    return setBool(PreferKey.importKeepGroup, value);
  }

  /// 导入保持启用
  /// 参考项目：AppConfig.importKeepEnable
  static bool getImportKeepEnable() {
    return getBool(PreferKey.importKeepEnable, defaultValue: false);
  }

  static Future<bool> setImportKeepEnable(bool value) {
    return setBool(PreferKey.importKeepEnable, value);
  }

  // ========== 同步相关配置 ==========
  /// 同步书籍进度
  /// 参考项目：AppConfig.syncBookProgress
  static bool getSyncBookProgress() {
    return getBool(PreferKey.syncBookProgress, defaultValue: true);
  }

  static Future<bool> setSyncBookProgress(bool value) {
    return setBool(PreferKey.syncBookProgress, value);
  }

  /// 同步书籍进度增强
  /// 参考项目：AppConfig.syncBookProgressPlus
  static bool getSyncBookProgressPlus() {
    return getBool(PreferKey.syncBookProgressPlus, defaultValue: false);
  }

  static Future<bool> setSyncBookProgressPlus(bool value) {
    return setBool(PreferKey.syncBookProgressPlus, value);
  }

  // ========== 媒体按钮相关配置 ==========
  /// 媒体按钮退出
  /// 参考项目：AppConfig.mediaButtonOnExit
  static bool getMediaButtonOnExit() {
    return getBool('mediaButtonOnExit', defaultValue: true);
  }

  static Future<bool> setMediaButtonOnExit(bool value) {
    return setBool('mediaButtonOnExit', value);
  }

  /// 媒体按钮朗读
  /// 参考项目：AppConfig.readAloudByMediaButton
  static bool getReadAloudByMediaButton() {
    return getBool(PreferKey.readAloudByMediaButton, defaultValue: false);
  }

  static Future<bool> setReadAloudByMediaButton(bool value) {
    return setBool(PreferKey.readAloudByMediaButton, value);
  }

  // ========== 替换规则相关配置 ==========
  /// 替换规则启用默认
  /// 参考项目：AppConfig.replaceEnableDefault
  static bool getReplaceEnableDefault() {
    return getBool(PreferKey.replaceEnableDefault, defaultValue: true);
  }

  static Future<bool> setReplaceEnableDefault(bool value) {
    return setBool(PreferKey.replaceEnableDefault, value);
  }

  // ========== WebDAV 相关配置 ==========
  /// WebDAV 目录
  /// 参考项目：AppConfig.webDavDir
  static String getWebDavDir() {
    return getString(PreferKey.webDavDir, defaultValue: 'legado');
  }

  static Future<bool> setWebDavDir(String dir) {
    return setString(PreferKey.webDavDir, dir);
  }

  /// WebDAV 设备名
  /// 参考项目：AppConfig.webDavDeviceName
  static String getWebDavDeviceName() {
    // 注意：参考项目中使用 Build.MODEL 作为默认值，Flutter 中需要从平台获取
    return getString(PreferKey.webDavDeviceName, defaultValue: '');
  }

  static Future<bool> setWebDavDeviceName(String deviceName) {
    return setString(PreferKey.webDavDeviceName, deviceName);
  }

  // ========== 调试和日志相关配置 ==========
  /// 启用评论（仅调试模式）
  /// 参考项目：AppConfig.enableReview
  static bool getEnableReview() {
    // 注意：参考项目中仅在 DEBUG 模式下启用
    return getBool(PreferKey.enableReview, defaultValue: false);
  }

  static Future<bool> setEnableReview(bool value) {
    return setBool(PreferKey.enableReview, value);
  }

  /// 记录堆转储
  /// 参考项目：AppConfig.recordHeapDump
  static bool getRecordHeapDump() {
    return getBool(PreferKey.recordHeapDump, defaultValue: false);
  }

  static Future<bool> setRecordHeapDump(bool value) {
    return setBool(PreferKey.recordHeapDump, value);
  }

  // ========== UI 提示相关配置 ==========
  /// 显示添加到书架提示
  /// 参考项目：AppConfig.showAddToShelfAlert
  static bool getShowAddToShelfAlert() {
    return getBool(PreferKey.showAddToShelfAlert, defaultValue: true);
  }

  static Future<bool> setShowAddToShelfAlert(bool value) {
    return setBool(PreferKey.showAddToShelfAlert, value);
  }

  /// 点击标题打开书籍信息
  /// 参考项目：AppConfig.openBookInfoByClickTitle
  static bool getOpenBookInfoByClickTitle() {
    return getBool(PreferKey.openBookInfoByClickTitle, defaultValue: true);
  }

  static Future<bool> setOpenBookInfoByClickTitle(bool value) {
    return setBool(PreferKey.openBookInfoByClickTitle, value);
  }

  /// 显示书架快速滚动条
  /// 参考项目：AppConfig.showBookshelfFastScroller
  static bool getShowBookshelfFastScroller() {
    return getBool(PreferKey.showBookshelfFastScroller, defaultValue: false);
  }

  static Future<bool> setShowBookshelfFastScroller(bool value) {
    return setBool(PreferKey.showBookshelfFastScroller, value);
  }

  /// 预览图片点击
  /// 参考项目：AppConfig.previewImageByClick
  static bool getPreviewImageByClick() {
    return getBool(PreferKey.previewImageByClick, defaultValue: false);
  }

  static Future<bool> setPreviewImageByClick(bool value) {
    return setBool(PreferKey.previewImageByClick, value);
  }

  // ========== 音频焦点相关配置 ==========
  /// 忽略音频焦点
  /// 参考项目：AppConfig.ignoreAudioFocus
  static bool getIgnoreAudioFocus() {
    return getBool(PreferKey.ignoreAudioFocus, defaultValue: false);
  }

  static Future<bool> setIgnoreAudioFocus(bool value) {
    return setBool(PreferKey.ignoreAudioFocus, value);
  }

  /// 通话时暂停朗读
  /// 参考项目：AppConfig.pauseReadAloudWhilePhoneCalls
  static bool getPauseReadAloudWhilePhoneCalls() {
    return getBool(PreferKey.pauseReadAloudWhilePhoneCalls,
        defaultValue: false);
  }

  static Future<bool> setPauseReadAloudWhilePhoneCalls(bool value) {
    return setBool(PreferKey.pauseReadAloudWhilePhoneCalls, value);
  }

  /// 流式朗读音频
  /// 参考项目：AppConfig.streamReadAloudAudio
  static bool getStreamReadAloudAudio() {
    return getBool(PreferKey.streamReadAloudAudio, defaultValue: false);
  }

  static Future<bool> setStreamReadAloudAudio(bool value) {
    return setBool(PreferKey.streamReadAloudAudio, value);
  }

  /// 内容选择朗读模式
  /// 参考项目：AppConfig.contentSelectSpeakMod
  static int getContentSelectSpeakMod() {
    return getInt(PreferKey.contentSelectSpeakMod, defaultValue: 0);
  }

  static Future<bool> setContentSelectSpeakMod(int mod) {
    return setInt(PreferKey.contentSelectSpeakMod, mod);
  }

  // ========== 备份相关配置 ==========
  /// 仅最新备份
  /// 参考项目：AppConfig.onlyLatestBackup
  static bool getOnlyLatestBackup() {
    return getBool(PreferKey.onlyLatestBackup, defaultValue: true);
  }

  static Future<bool> setOnlyLatestBackup(bool value) {
    return setBool(PreferKey.onlyLatestBackup, value);
  }

  /// 自动检查新备份
  /// 参考项目：AppConfig.autoCheckNewBackup
  static bool getAutoCheckNewBackup() {
    return getBool(PreferKey.autoCheckNewBackup, defaultValue: true);
  }

  static Future<bool> setAutoCheckNewBackup(bool value) {
    return setBool(PreferKey.autoCheckNewBackup, value);
  }

  // ========== 应用设置相关配置 ==========
  /// 默认首页
  /// 参考项目：AppConfig.defaultHomePage
  static String getDefaultHomePage() {
    return getString(PreferKey.defaultHomePage, defaultValue: 'bookshelf');
  }

  static Future<bool> setDefaultHomePage(String page) {
    return setString(PreferKey.defaultHomePage, page);
  }

  /// 更新到变体
  /// 参考项目：AppConfig.updateToVariant
  static String getUpdateToVariant() {
    return getString(PreferKey.updateToVariant,
        defaultValue: 'default_version');
  }

  static Future<bool> setUpdateToVariant(String variant) {
    return setString(PreferKey.updateToVariant, variant);
  }

  // ========== 换源相关配置（补充）==========
  /// 换源加载信息
  /// 参考项目：AppConfig.changeSourceLoadInfo
  static bool getChangeSourceLoadInfo() {
    return getBool(PreferKey.changeSourceLoadInfo, defaultValue: false);
  }

  static Future<bool> setChangeSourceLoadInfo(bool value) {
    return setBool(PreferKey.changeSourceLoadInfo, value);
  }

  /// 换源加载字数
  /// 参考项目：AppConfig.changeSourceLoadWordCount
  static bool getChangeSourceLoadWordCount() {
    return getBool(PreferKey.changeSourceLoadWordCount, defaultValue: false);
  }

  static Future<bool> setChangeSourceLoadWordCount(bool value) {
    return setBool(PreferKey.changeSourceLoadWordCount, value);
  }

  /// 批量换源延迟
  /// 参考项目：AppConfig.batchChangeSourceDelay
  static int getBatchChangeSourceDelay() {
    return getInt(PreferKey.batchChangeSourceDelay, defaultValue: 0);
  }

  static Future<bool> setBatchChangeSourceDelay(int delay) {
    return setInt(PreferKey.batchChangeSourceDelay, delay);
  }

  // ========== TTS 相关配置（补充）==========
  /// 无动画滚动页面
  /// 参考项目：AppConfig.noAnimScrollPage
  static bool getNoAnimScrollPage() {
    return getBool(PreferKey.noAnimScrollPage, defaultValue: false);
  }

  /// 播放语速
  /// 参考项目：AppConfig.speechRatePlay
  /// 如果 TTS 跟随系统，返回默认值 5，否则返回设置的语速
  static int getSpeechRatePlay() {
    if (getTtsFollowSys()) {
      return 5; // defaultSpeechRate
    }
    return getTtsSpeechRate();
  }

  // ========== 用户代理相关配置（完善）==========
  /// 获取用户代理（带默认值）
  /// 参考项目：AppConfig.getPrefUserAgent()
  /// 如果未设置，返回默认的 Chrome User-Agent
  static String getUserAgentWithDefault() {
    final ua = getUserAgent();
    if (ua.isEmpty) {
      // 默认 User-Agent，参考项目（legado Android）使用 Android 移动端 User-Agent
      return 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }
    return ua;
  }

  // ========== 点击区域检测 ==========
  /// 检测点击区域
  /// 参考项目：AppConfig.detectClickArea()
  /// 如果所有9个区域都配置了非0值，自动恢复中间区域为菜单（0）
  static Future<bool> detectClickArea() async {
    final tl = getClickActionTL();
    final tc = getClickActionTC();
    final tr = getClickActionTR();
    final ml = getClickActionML();
    final mc = getClickActionMC();
    final mr = getClickActionMR();
    final bl = getClickActionBL();
    final bc = getClickActionBC();
    final br = getClickActionBR();

    // 如果所有区域都不为0，恢复中间区域为菜单
    if (tl * tc * tr * ml * mc * mr * bl * bc * br != 0) {
      await setClickActionMC(0);
      // 注意：参考项目中有 toast 提示，Flutter 中需要调用相应的提示方法
      return true;
    }
    return false;
  }

  // ========== 书籍排序相关配置 ==========
  /// 根据分组ID获取书籍排序
  /// 参考项目：AppConfig.getBookSortByGroupId(groupId: Long)
  /// 注意：此方法需要访问数据库，需要 BookGroupService
  static Future<int> getBookSortByGroupId(int groupId) async {
    // 注意：需要导入 BookGroupService
    // 暂时返回默认排序，实际实现需要访问数据库
    // TODO: 实现数据库查询逻辑
    // final group = await BookGroupService.instance.getGroupById(groupId);
    // return group?.getRealBookSort() ?? getBookshelfSort();
    return getBookshelfSort();
  }
}
