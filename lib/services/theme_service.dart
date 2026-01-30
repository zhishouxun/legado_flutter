import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../core/base/base_service.dart';
import '../data/models/theme_config.dart';
import '../config/app_config.dart';
import '../core/constants/prefer_key.dart';
import '../utils/app_log.dart';
import '../utils/default_data.dart';

/// 主题服务
class ThemeService extends BaseService {
  static final ThemeService instance = ThemeService._init();
  ThemeService._init();

  static const String configFileName = 'themeConfig.json';
  List<ThemeConfig> _configList = [];

  /// 获取配置文件路径
  Future<String> _getConfigFilePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$configFileName';
  }

  /// 加载配置列表
  Future<List<ThemeConfig>> loadConfigs() async {
    return await execute(
      action: () async {
        final configPath = await _getConfigFilePath();
        final configFile = File(configPath);

        if (await configFile.exists()) {
          final jsonString = await configFile.readAsString();
          final jsonList = jsonDecode(jsonString) as List;
          _configList = jsonList
              .map((json) => ThemeConfig.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          // 如果没有配置文件，从 assets/defaultData/themeConfig.json 加载默认配置
          _configList = await DefaultData.instance.themeConfigs;
          await saveConfigs();
        }

        return _configList;
      },
      operationName: '加载主题配置',
      logError: true,
      defaultValue: <ThemeConfig>[],
    );
  }

  /// 获取配置列表
  List<ThemeConfig> getConfigs() {
    return List.unmodifiable(_configList);
  }

  /// 获取当前主题
  /// 参考项目：ThemeConfig.getTheme()
  /// 
  /// 根据 AppConfig 的主题模式返回对应的主题类型
  /// 0: 跟随系统, 1: 日间, 2: 夜间, 3: 电子墨水
  String getTheme() {
    final themeMode = AppConfig.getThemeMode();
    if (themeMode == 3) {
      return 'EInk';
    } else if (themeMode == 2) {
      return 'Dark';
    } else {
      return 'Light';
    }
  }

  /// 是否为深色主题
  /// 参考项目：ThemeConfig.isDarkTheme()
  bool isDarkTheme() {
    return getTheme() == 'Dark';
  }

  /// 应用日夜间模式
  /// 参考项目：ThemeConfig.applyDayNight()
  /// 
  /// 注意：Flutter 中主题切换需要通过 MaterialApp 的 theme 和 darkTheme 属性
  /// 这个方法主要用于标记主题已更改，实际应用需要在 MaterialApp 中处理
  Future<void> applyDayNight() async {
    try {
      await applyTheme();
      await initNightMode();
      AppLog.instance.put('主题已切换: ${getTheme()}');
    } catch (e) {
      AppLog.instance.put('应用主题失败', error: e);
    }
  }

  /// 初始化日夜间模式
  /// 参考项目：ThemeConfig.applyDayNightInit()
  /// 
  /// 在应用启动时初始化主题
  Future<void> applyDayNightInit() async {
    try {
      await applyTheme();
      await initNightMode();
    } catch (e) {
      AppLog.instance.put('初始化主题失败', error: e);
    }
  }

  /// 初始化夜间模式
  /// 参考项目：ThemeConfig.initNightMode()
  /// 
  /// 注意：Flutter 中夜间模式通过 ThemeMode 控制，不需要像 Android 那样设置 AppCompatDelegate
  /// 这个方法主要用于确保主题配置正确
  Future<void> initNightMode() async {
    try {
      // Flutter 中夜间模式通过 MaterialApp 的 themeMode 属性控制
      // 这里只需要确保配置正确即可
      final themeMode = AppConfig.getThemeMode();
      AppLog.instance.put('初始化夜间模式: $themeMode');
    } catch (e) {
      AppLog.instance.put('初始化夜间模式失败', error: e);
    }
  }

  /// 应用主题
  /// 参考项目：ThemeConfig.applyTheme()
  /// 
  /// 根据当前主题模式应用对应的主题配置
  Future<void> applyTheme() async {
    try {
      final theme = getTheme();
      
      if (theme == 'EInk') {
        // 电子墨水模式：黑白主题
        await AppConfig.setInt(PreferKey.cPrimary, 0xFFFFFFFF);
        await AppConfig.setInt(PreferKey.cAccent, 0xFF000000);
        await AppConfig.setInt(PreferKey.cBackground, 0xFFFFFFFF);
        await AppConfig.setInt(PreferKey.cBBackground, 0xFFFFFFFF);
      } else if (theme == 'Dark') {
        // 夜间模式：使用夜间主题颜色
        // 如果背景色太亮，自动调整为深色
        var background = AppConfig.getInt(PreferKey.cNBackground, defaultValue: 0xFF212121);
        if (_isColorLight(background)) {
          background = 0xFF212121;
          await AppConfig.setInt(PreferKey.cNBackground, background);
        }
      } else {
        // 日间模式：使用日间主题颜色
        // 如果背景色太暗，自动调整为浅色
        var background = AppConfig.getInt(PreferKey.cBackground, defaultValue: 0xFFF5F5F5);
        if (!_isColorLight(background)) {
          background = 0xFFF5F5F5;
          await AppConfig.setInt(PreferKey.cBackground, background);
        }
      }
    } catch (e) {
      AppLog.instance.put('应用主题失败', error: e);
    }
  }

  /// 检查颜色是否为浅色
  bool _isColorLight(int color) {
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    // 计算亮度（使用相对亮度公式）
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.5;
  }

  /// 获取背景图片
  /// 参考项目：ThemeConfig.getBgImage()
  /// 
  /// [context] BuildContext（用于获取屏幕尺寸）
  /// 返回背景图片的 ImageProvider，如果不存在则返回 null
  /// 注意：Flutter 中背景图片的模糊处理在 UI 层使用 ImageFilter.blur 实现
  Future<ImageProvider?> getBgImage(BuildContext context) async {
    try {
      final theme = getTheme();
      String? bgImagePath;

      if (theme == 'Dark') {
        bgImagePath = AppConfig.getString(PreferKey.bgImageN, defaultValue: '');
        // 注意：模糊处理在 UI 层使用 ImageFilter.blur 实现
        // final blurRadius = AppConfig.getInt(PreferKey.bgImageNBlurring, defaultValue: 0);
      } else if (theme == 'Light') {
        bgImagePath = AppConfig.getString(PreferKey.bgImage, defaultValue: '');
        // 注意：模糊处理在 UI 层使用 ImageFilter.blur 实现
        // final blurRadius = AppConfig.getInt(PreferKey.bgImageBlurring, defaultValue: 0);
      }

      if (bgImagePath == null || bgImagePath.isEmpty) {
        return null;
      }

      // 检查是否是预设背景图片（assets/bg/ 中的图片）
      final presetBgImages = [
        '午后沙滩',
        '宁静夜色',
        '山水画',
        '山水墨影',
        '护眼漫绿',
        '新羊皮纸',
        '明媚倾城',
        '深宫魅影',
        '清新时光',
        '羊皮纸1',
        '羊皮纸2',
        '羊皮纸3',
        '羊皮纸4',
        '边彩画布',
      ];

      if (presetBgImages.contains(bgImagePath)) {
        // 预设背景图片，从 assets 加载
        return AssetImage('assets/bg/$bgImagePath.jpg');
      }

      // 用户自定义图片，从文件路径加载
      final file = File(bgImagePath);
      if (await file.exists()) {
        return FileImage(file);
      }

      return null;
    } catch (e) {
      AppLog.instance.put('获取背景图片失败', error: e);
      return null;
    }
  }

  /// 清理背景图片
  /// 参考项目：ThemeConfig.clearBg()
  /// 
  /// 删除未使用的背景图片文件
  Future<void> clearBg() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final bgImagesDir = Directory('${appDir.path}/background_images');
      
      if (!await bgImagesDir.exists()) {
        return;
      }

      // 获取当前使用的背景图片路径
      final bgImagePath = AppConfig.getString(PreferKey.bgImage, defaultValue: '');
      final bgImageNPath = AppConfig.getString(PreferKey.bgImageN, defaultValue: '');

      // 删除未使用的背景图片
      await for (final entity in bgImagesDir.list()) {
        if (entity is File) {
          final filePath = entity.path;
          if (filePath != bgImagePath && filePath != bgImageNPath) {
            try {
              await entity.delete();
              AppLog.instance.put('已删除未使用的背景图片: $filePath');
            } catch (e) {
              AppLog.instance.put('删除背景图片失败: $filePath', error: e);
            }
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('清理背景图片失败', error: e);
    }
  }

  /// 保存配置列表
  Future<void> saveConfigs() async {
    try {
      final configPath = await _getConfigFilePath();
      final configFile = File(configPath);
      final jsonString = jsonEncode(_configList.map((c) => c.toJson()).toList());
      await configFile.writeAsString(jsonString);
    } catch (e) {
      AppLog.instance.put('保存主题配置失败', error: e);
      rethrow;
    }
  }

  /// 添加配置
  Future<bool> addConfig(ThemeConfig config) async {
    if (!_validateConfig(config)) {
      return false;
    }

    // 检查是否已存在同名配置
    final existingIndex = _configList.indexWhere((c) => c.themeName == config.themeName);
    if (existingIndex >= 0) {
      _configList[existingIndex] = config;
    } else {
      _configList.add(config);
    }

    await saveConfigs();
    return true;
  }

  /// 从JSON字符串添加配置
  Future<bool> addConfigFromJson(String jsonString) async {
    try {
      final json = jsonDecode(jsonString.trim()) as Map<String, dynamic>;
      final config = ThemeConfig.fromJson(json);
      return await addConfig(config);
    } catch (e) {
      AppLog.instance.put('从JSON添加主题配置失败', error: e);
      return false;
    }
  }

  /// 删除配置
  Future<void> deleteConfig(int index) async {
    if (index >= 0 && index < _configList.length) {
      _configList.removeAt(index);
      await saveConfigs();
    }
  }

  /// 应用主题配置
  Future<void> applyConfig(ThemeConfig config) async {
    try {
      if (config.isNightTheme) {
        await AppConfig.setInt('c_n_primary', _colorStringToInt(config.primaryColor));
        await AppConfig.setInt('c_n_accent', _colorStringToInt(config.accentColor));
        await AppConfig.setInt('c_n_background', _colorStringToInt(config.backgroundColor));
        await AppConfig.setInt('c_n_b_background', _colorStringToInt(config.bottomBackground));
        await AppConfig.setString('theme_mode', 'dark');
      } else {
        await AppConfig.setInt('c_primary', _colorStringToInt(config.primaryColor));
        await AppConfig.setInt('c_accent', _colorStringToInt(config.accentColor));
        await AppConfig.setInt('c_background', _colorStringToInt(config.backgroundColor));
        await AppConfig.setInt('c_b_background', _colorStringToInt(config.bottomBackground));
        await AppConfig.setString('theme_mode', 'light');
      }
    } catch (e) {
      AppLog.instance.put('应用主题配置失败', error: e);
      rethrow;
    }
  }

  /// 保存当前主题为配置
  Future<void> saveCurrentTheme(String themeName, bool isNightTheme) async {
    try {
      int primary, accent, background, bBackground;

      if (isNightTheme) {
        primary = AppConfig.getInt('c_n_primary', defaultValue: 0xFF546E7A);
        accent = AppConfig.getInt('c_n_accent', defaultValue: 0xFFBF360C);
        background = AppConfig.getInt('c_n_background', defaultValue: 0xFF212121);
        bBackground = AppConfig.getInt('c_n_b_background', defaultValue: 0xFF303030);
      } else {
        primary = AppConfig.getInt('c_primary', defaultValue: 0xFF795548);
        accent = AppConfig.getInt('c_accent', defaultValue: 0xFFD32F2F);
        background = AppConfig.getInt('c_background', defaultValue: 0xFFF5F5F5);
        bBackground = AppConfig.getInt('c_b_background', defaultValue: 0xFFEEEEEE);
      }

      final config = ThemeConfig(
        themeName: themeName,
        isNightTheme: isNightTheme,
        primaryColor: _colorIntToString(primary),
        accentColor: _colorIntToString(accent),
        backgroundColor: _colorIntToString(background),
        bottomBackground: _colorIntToString(bBackground),
      );

      await addConfig(config);
    } catch (e) {
      AppLog.instance.put('保存当前主题失败', error: e);
      rethrow;
    }
  }

  /// 验证配置
  bool _validateConfig(ThemeConfig config) {
    try {
      _colorStringToInt(config.primaryColor);
      _colorStringToInt(config.accentColor);
      _colorStringToInt(config.backgroundColor);
      _colorStringToInt(config.bottomBackground);
      return config.themeName.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 颜色字符串转整数
  int _colorStringToInt(String colorString) {
    String hex = colorString.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // 添加alpha通道
    }
    return int.parse(hex, radix: 16);
  }

  /// 颜色整数转字符串
  String _colorIntToString(int color) {
    final hex = color.toRadixString(16).toUpperCase();
    if (hex.length == 8) {
      return '#${hex.substring(2)}'; // 移除alpha通道
    }
    return '#$hex';
  }

  /// 获取默认配置
}

