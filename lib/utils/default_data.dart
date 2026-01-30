import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/models/http_tts.dart';
import '../data/models/dict_rule.dart';
import '../data/models/txt_toc_rule.dart';
import '../data/models/rss_source.dart';
import '../data/models/keyboard_assist.dart';
import '../data/models/theme_config.dart';
import '../data/models/book_source.dart';
import '../config/app_config.dart';
import '../utils/app_log.dart';
import '../services/keyboard_assist_service.dart';
import '../services/read_config_service.dart';
import '../services/source/book_source_service.dart';
import '../services/source/book_source_parser.dart';

/// 默认数据工具类
/// 参考项目：io.legado.app.help.DefaultData
class DefaultData {
  static final DefaultData instance = DefaultData._init();
  DefaultData._init();

  /// HTTP TTS 默认配置列表
  List<HttpTTS>? _httpTTS;
  Future<List<HttpTTS>> get httpTTS async {
    if (_httpTTS != null) return _httpTTS!;
    try {
      final json = await rootBundle.loadString('assets/defaultData/httpTTS.json');
      final jsonList = jsonDecode(json) as List;
      _httpTTS = jsonList
          .map((item) => HttpTTS.fromJson(item as Map<String, dynamic>))
          .toList();
      return _httpTTS!;
    } catch (e) {
      AppLog.instance.put('加载默认HTTP TTS配置失败', error: e);
      return [];
    }
  }

  /// 阅读配置默认列表
  List<Map<String, dynamic>>? _readConfigs;
  Future<List<Map<String, dynamic>>> get readConfigs async {
    if (_readConfigs != null) return _readConfigs!;
    try {
      final json = await rootBundle.loadString('assets/defaultData/readConfig.json');
      final jsonList = jsonDecode(json) as List;
      _readConfigs = jsonList
          .map((item) => item as Map<String, dynamic>)
          .toList();
      return _readConfigs!;
    } catch (e) {
      AppLog.instance.put('加载默认阅读配置失败', error: e);
      return [];
    }
  }

  /// TXT 目录规则默认列表
  List<TxtTocRule>? _txtTocRules;
  Future<List<TxtTocRule>> get txtTocRules async {
    if (_txtTocRules != null) return _txtTocRules!;
    try {
      final json = await rootBundle.loadString('assets/defaultData/txtTocRule.json');
      final jsonList = jsonDecode(json) as List;
      _txtTocRules = jsonList
          .map((item) => TxtTocRule.fromJson(item as Map<String, dynamic>))
          .toList();
      return _txtTocRules!;
    } catch (e) {
      AppLog.instance.put('加载默认TXT目录规则失败', error: e);
      return [];
    }
  }

  /// 主题配置默认列表
  List<ThemeConfig>? _themeConfigs;
  Future<List<ThemeConfig>> get themeConfigs async {
    if (_themeConfigs != null) return _themeConfigs!;
    try {
      final json = await rootBundle.loadString('assets/defaultData/themeConfig.json');
      final jsonList = jsonDecode(json) as List;
      _themeConfigs = jsonList
          .map((item) => ThemeConfig.fromJson(item as Map<String, dynamic>))
          .toList();
      return _themeConfigs!;
    } catch (e) {
      AppLog.instance.put('加载默认主题配置失败', error: e);
      return [];
    }
  }

  /// RSS 源默认列表
  List<RssSource>? _rssSources;
  Future<List<RssSource>> get rssSources async {
    if (_rssSources != null) return _rssSources!;
    try {
      final json = await rootBundle.loadString('assets/defaultData/rssSources.json');
      final jsonList = jsonDecode(json) as List;
      _rssSources = jsonList
          .map((item) => RssSource.fromJson(item as Map<String, dynamic>))
          .toList();
      return _rssSources!;
    } catch (e) {
      AppLog.instance.put('加载默认RSS源失败', error: e);
      return [];
    }
  }

  /// 封面规则默认配置
  Map<String, dynamic>? _coverRule;
  Future<Map<String, dynamic>> get coverRule async {
    if (_coverRule != null) return _coverRule!;
    try {
      final json = await rootBundle.loadString('assets/defaultData/coverRule.json');
      _coverRule = jsonDecode(json) as Map<String, dynamic>;
      return _coverRule!;
    } catch (e) {
      AppLog.instance.put('加载默认封面规则失败', error: e);
      return {};
    }
  }

  /// 字典规则默认列表
  List<DictRule>? _dictRules;
  Future<List<DictRule>> get dictRules async {
    if (_dictRules != null) return _dictRules!;
    try {
      final json = await rootBundle.loadString('assets/defaultData/dictRules.json');
      final jsonList = jsonDecode(json) as List;
      _dictRules = jsonList
          .map((item) => DictRule.fromJson(item as Map<String, dynamic>))
          .toList();
      return _dictRules!;
    } catch (e) {
      AppLog.instance.put('加载默认字典规则失败', error: e);
      return [];
    }
  }

  /// 键盘辅助默认列表
  List<KeyboardAssist>? _keyboardAssists;
  Future<List<KeyboardAssist>> get keyboardAssists async {
    if (_keyboardAssists != null) return _keyboardAssists!;
    try {
      final json = await rootBundle.loadString('assets/defaultData/keyboardAssists.json');
      final jsonList = jsonDecode(json) as List;
      _keyboardAssists = jsonList
          .map((item) => KeyboardAssist.fromJson(item as Map<String, dynamic>))
          .toList();
      return _keyboardAssists!;
    } catch (e) {
      AppLog.instance.put('加载默认键盘辅助失败', error: e);
      return [];
    }
  }

  /// 直链上传规则默认列表
  List<Map<String, dynamic>>? _directLinkUploadRules;
  Future<List<Map<String, dynamic>>> get directLinkUploadRules async {
    if (_directLinkUploadRules != null) return _directLinkUploadRules!;
    try {
      final json = await rootBundle.loadString('assets/defaultData/directLinkUpload.json');
      final jsonList = jsonDecode(json) as List;
      _directLinkUploadRules = jsonList
          .map((item) => item as Map<String, dynamic>)
          .toList();
      return _directLinkUploadRules!;
    } catch (e) {
      AppLog.instance.put('加载默认直链上传规则失败', error: e);
      return [];
    }
  }

  /// 默认书源列表
  /// 
  /// ✅ 符合项目规范: 使用Isolate解析JSON,避免UI线程阻塞
  List<BookSource>? _bookSources;
  Future<List<BookSource>> get bookSources async {
    if (_bookSources != null) return _bookSources!;
    try {
      // 第一步: 在UI线程读取Assets文件内容(这是快速操作)
      final jsonString = await rootBundle.loadString('assets/defaultData/bookSources.json');
      
      // 第二步: 在Isolate中解析JSON(耗时操作,不阻塞UI线程)
      _bookSources = await BookSourceParser.parseInBackground(jsonString);
      
      AppLog.instance.put('成功加载 ${_bookSources!.length} 个默认书源(Isolate解析)');
      return _bookSources!;
    } catch (e) {
      AppLog.instance.put('加载默认书源失败', error: e);
      return [];
    }
  }

  /// 导入默认书源（首次启动时）
  Future<void> importDefaultBookSources() async {
    try {
      // 检查是否已经导入过
      final imported = AppConfig.getBool('default_book_sources_imported', defaultValue: false);
      if (imported) {
        return;
      }

      // 检查是否已有书源
      final existingSources = await BookSourceService.instance.getAllBookSources();
      if (existingSources.isNotEmpty) {
        // 如果已有书源，标记为已导入，不再自动导入
        await AppConfig.setBool('default_book_sources_imported', true);
        return;
      }

      // 导入默认书源
      final defaultSources = await bookSources;
      if (defaultSources.isNotEmpty) {
        final result = await BookSourceService.instance.importBookSources(defaultSources);
        AppLog.instance.put('导入默认书源: ${result['imported']} 个成功, ${result['blocked']} 个被过滤');
        await AppConfig.setBool('default_book_sources_imported', true);
      }
    } catch (e) {
      AppLog.instance.put('导入默认书源失败', error: e);
    }
  }

  /// 版本升级时导入默认数据
  /// 参考项目：DefaultData.upVersion()
  Future<void> upVersion() async {
    try {
      // 获取当前版本号
      final currentVersion = AppConfig.getInt('version_code', defaultValue: 0);
      // 从 package_info_plus 获取实际版本号
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = int.tryParse(packageInfo.buildNumber) ?? 1;

      if (currentVersion < appVersion) {
        // 版本升级，导入默认数据
        // 注意：这里可以根据需要选择性导入
        // 参考项目中有 LocalConfig.needUpHttpTTS 等标志位控制
        
        AppLog.instance.put('检测到版本升级，准备导入默认数据');
        
        // 导入默认键盘辅助（如果表为空）
        try {
          await KeyboardAssistService.instance.importDefaultKeyboardAssists();
        } catch (e) {
          AppLog.instance.put('导入默认键盘辅助失败', error: e);
        }

        // 导入默认阅读配置预设
        try {
          await ReadConfigService.instance.importDefaultPresets();
        } catch (e) {
          AppLog.instance.put('导入默认阅读配置预设失败', error: e);
        }
        
        // 更新版本号
        await AppConfig.setInt('version_code', appVersion);
      }

      // 首次启动时导入默认书源（延迟到后台执行，避免阻塞启动）
      // 注意：这个操作可能涉及大量数据库操作，不应该阻塞应用启动
      Future.microtask(() async {
        try {
          await importDefaultBookSources();
        } catch (e) {
          AppLog.instance.put('导入默认书源失败', error: e);
        }
      });
    } catch (e) {
      AppLog.instance.put('版本升级检查失败', error: e);
    }
  }
}

