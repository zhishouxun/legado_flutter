import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/base/base_service.dart';
import '../data/models/book.dart';
import '../utils/default_data.dart';
import '../utils/app_log.dart';
import '../config/app_config.dart';

/// 阅读配置服务
/// 管理阅读配置预设
/// 参考项目：io.legado.app.help.config.ReadBookConfig
class ReadConfigService extends BaseService {
  static final ReadConfigService instance = ReadConfigService._init();
  ReadConfigService._init();

  static const String configFileName = 'readConfig.json';
  static const String shareConfigFileName = 'shareReadConfig.json';

  List<ReadConfig> _configList = [];
  ReadConfig? _shareConfig;

  /// 获取配置文件路径
  Future<String> _getConfigFilePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$configFileName';
  }

  /// 获取共享配置文件路径
  Future<String> _getShareConfigFilePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$shareConfigFileName';
  }

  /// 获取所有预设配置
  Future<List<Map<String, dynamic>>> getPresetConfigs() async {
    try {
      return await DefaultData.instance.readConfigs;
    } catch (e) {
      AppLog.instance.put('获取预设阅读配置失败', error: e);
      return [];
    }
  }

  /// 根据名称获取预设配置
  Future<ReadConfig?> getPresetConfigByName(String name) async {
    try {
      final presets = await getPresetConfigs();
      for (final preset in presets) {
        if (preset['name'] == name) {
          return ReadConfig.fromJson(preset);
        }
      }
      return null;
    } catch (e) {
      AppLog.instance.put('获取预设阅读配置失败: $name', error: e);
      return null;
    }
  }

  /// 导入默认预设配置（首次启动时）
  /// 如果用户还没有设置过阅读配置，则使用第一个预设配置
  Future<void> importDefaultPresets() async {
    try {
      // 检查是否已经导入过
      final imported = AppConfig.getBool('read_config_presets_imported',
          defaultValue: false);
      if (imported) {
        return;
      }

      final presets = await getPresetConfigs();
      if (presets.isNotEmpty) {
        // 标记已导入，预设配置会在用户选择时使用
        await AppConfig.setBool('read_config_presets_imported', true);
        AppLog.instance.put('已导入默认阅读配置预设: ${presets.length} 个');
      }
    } catch (e) {
      AppLog.instance.put('导入默认阅读配置预设失败', error: e);
    }
  }

  /// 初始化配置列表
  /// 参考项目：ReadBookConfig.initConfigs()
  Future<void> initConfigs() async {
    return await execute(
      action: () async {
        try {
          final configPath = await _getConfigFilePath();
          final configFile = File(configPath);

          List<ReadConfig> configs;
          if (await configFile.exists()) {
            try {
              final jsonString = await configFile.readAsString();
              final jsonList = jsonDecode(jsonString) as List;
              configs = jsonList
                  .map((json) =>
                      ReadConfig.fromJson(json as Map<String, dynamic>))
                  .toList();
            } catch (e) {
              AppLog.instance.put('读取阅读配置文件出错', error: e);
              // 如果读取失败，使用默认配置
              final presets = await getPresetConfigs();
              configs =
                  presets.map((preset) => ReadConfig.fromJson(preset)).toList();
            }
          } else {
            // 如果文件不存在，使用默认配置
            final presets = await getPresetConfigs();
            configs =
                presets.map((preset) => ReadConfig.fromJson(preset)).toList();
          }

          _configList.clear();
          _configList.addAll(configs);

          // 如果配置列表少于5个，重置为默认配置
          if (_configList.length < 5) {
            await resetAll();
          }
        } catch (e) {
          AppLog.instance.put('初始化阅读配置失败', error: e);
          rethrow;
        }
      },
      operationName: '初始化阅读配置',
      logError: true,
    );
  }

  /// 初始化共享配置
  /// 参考项目：ReadBookConfig.initShareConfig()
  Future<void> initShareConfig() async {
    return await execute(
      action: () async {
        try {
          final shareConfigPath = await _getShareConfigFilePath();
          final shareConfigFile = File(shareConfigPath);

          if (await shareConfigFile.exists()) {
            try {
              final jsonString = await shareConfigFile.readAsString();
              final json = jsonDecode(jsonString) as Map<String, dynamic>;
              _shareConfig = ReadConfig.fromJson(json);
            } catch (e) {
              AppLog.instance.put('读取共享阅读配置出错', error: e);
              // 如果读取失败，使用默认配置
              if (_configList.isNotEmpty) {
                _shareConfig = _configList[0];
              } else {
                final presets = await getPresetConfigs();
                if (presets.isNotEmpty) {
                  _shareConfig = ReadConfig.fromJson(presets[0]);
                }
              }
            }
          } else {
            // 如果文件不存在，使用默认配置
            if (_configList.isNotEmpty) {
              _shareConfig = _configList[0];
            } else {
              final presets = await getPresetConfigs();
              if (presets.isNotEmpty) {
                _shareConfig = ReadConfig.fromJson(presets[0]);
              }
            }
          }
        } catch (e) {
          AppLog.instance.put('初始化共享阅读配置失败', error: e);
          rethrow;
        }
      },
      operationName: '初始化共享阅读配置',
      logError: true,
    );
  }

  /// 重置所有配置
  /// 参考项目：ReadBookConfig.resetAll()
  /// 将所有配置重置为默认预设配置
  Future<void> resetAll() async {
    return await execute(
      action: () async {
        try {
          // 获取默认预设配置
          final presets = await getPresetConfigs();
          if (presets.isEmpty) {
            AppLog.instance.put('没有可用的预设配置');
            return;
          }

          // 重置配置列表为默认预设配置
          _configList.clear();
          _configList.addAll(
            presets.map((preset) => ReadConfig.fromJson(preset)).toList(),
          );

          // 保存到文件
          await saveConfigs(_configList);

          AppLog.instance.put('已重置所有阅读配置: ${_configList.length} 个');
        } catch (e) {
          AppLog.instance.put('重置阅读配置失败', error: e);
          rethrow;
        }
      },
      operationName: '重置所有阅读配置',
      logError: true,
    );
  }

  /// 保存配置列表
  /// 参考项目：ReadBookConfig.save()
  /// 将配置列表保存到文件
  Future<void> saveConfigs(List<ReadConfig> configs) async {
    return await execute(
      action: () async {
        try {
          // 更新内部配置列表
          _configList = List.from(configs);

          // 保存配置列表到 readConfig.json
          final configPath = await _getConfigFilePath();
          final configFile = File(configPath);

          // 删除旧文件（如果存在）
          if (await configFile.exists()) {
            await configFile.delete();
          }

          // 写入新配置
          final jsonString = jsonEncode(
            configs.map((config) => config.toJson()).toList(),
          );
          await configFile.writeAsString(jsonString);

          // 保存共享配置到 shareReadConfig.json
          if (_shareConfig != null) {
            final shareConfigPath = await _getShareConfigFilePath();
            final shareConfigFile = File(shareConfigPath);

            // 删除旧文件（如果存在）
            if (await shareConfigFile.exists()) {
              await shareConfigFile.delete();
            }

            // 写入共享配置
            final shareJsonString = jsonEncode(_shareConfig!.toJson());
            await shareConfigFile.writeAsString(shareJsonString);
          }

          AppLog.instance.put('已保存阅读配置列表: ${configs.length} 个');
        } catch (e) {
          AppLog.instance.put('保存阅读配置列表失败', error: e);
          rethrow;
        }
      },
      operationName: '保存阅读配置列表',
      logError: true,
    );
  }

  /// 清理背景图片和缓存
  /// 参考项目：ReadBookConfig.clearBgAndCache()
  /// 删除未使用的背景图片文件和缓存
  Future<void> clearBgAndCache() async {
    return await execute(
      action: () async {
        try {
          // 收集所有配置中使用的背景图片路径
          final usedBgPaths = <String>{};

          for (final config in _configList) {
            // 检查背景图片路径（如果 bgImage 是文件路径）
            if (config.bgImage != null && config.bgImage!.isNotEmpty) {
              // 检查是否是文件路径（不是预设名称）
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

              if (!presetBgImages.contains(config.bgImage)) {
                // 是文件路径，添加到使用列表
                final file = File(config.bgImage!);
                if (await file.exists()) {
                  usedBgPaths.add(file.path);
                }
              }
            }
          }

          // 删除未使用的背景图片
          final appDir = await getApplicationDocumentsDirectory();
          final bgImagesDir = Directory('${appDir.path}/background_images');

          if (await bgImagesDir.exists()) {
            await for (final entity in bgImagesDir.list()) {
              if (entity is File) {
                final filePath = entity.path;
                if (!usedBgPaths.contains(filePath)) {
                  try {
                    await entity.delete();
                    AppLog.instance.put('已删除未使用的背景图片: $filePath');
                  } catch (e) {
                    AppLog.instance.put('删除背景图片失败: $filePath', error: e);
                  }
                }
              }
            }
          }

          // 清理缓存目录（如果需要）
          // 注意：Flutter 中缓存管理由系统自动处理，这里只清理背景图片

          AppLog.instance.put('已清理背景图片和缓存');
        } catch (e) {
          AppLog.instance.put('清理背景图片和缓存失败', error: e);
          rethrow;
        }
      },
      operationName: '清理背景图片和缓存',
      logError: true,
    );
  }

  /// 获取配置列表
  List<ReadConfig> getConfigList() {
    return List.unmodifiable(_configList);
  }

  /// 获取共享配置
  ReadConfig? getShareConfig() {
    return _shareConfig;
  }

  /// 设置共享配置
  Future<void> setShareConfig(ReadConfig config) async {
    _shareConfig = config;
    // 保存共享配置到文件
    try {
      final shareConfigPath = await _getShareConfigFilePath();
      final shareConfigFile = File(shareConfigPath);

      if (await shareConfigFile.exists()) {
        await shareConfigFile.delete();
      }

      final shareJsonString = jsonEncode(config.toJson());
      await shareConfigFile.writeAsString(shareJsonString);
    } catch (e) {
      AppLog.instance.put('保存共享配置失败', error: e);
    }
  }

  /// 根据索引获取配置
  /// 参考项目：ReadBookConfig.getConfig(index)
  ReadConfig getConfig(int index) {
    if (_configList.length < 5) {
      // 如果配置列表少于5个，重置为默认配置
      resetAll();
    }
    if (index >= 0 && index < _configList.length) {
      return _configList[index];
    }
    return _configList.isNotEmpty ? _configList[0] : ReadConfig();
  }

  /// 删除指定配置
  /// 参考项目：ReadBookConfig.deleteDur()
  /// 返回true表示删除成功，false表示配置数量不足无法删除
  Future<bool> deleteConfig(int index) async {
    return await execute(
          action: () async {
            // 最少保留5个配置
            if (_configList.length <= 5) {
              AppLog.instance.put('配置数量已是最少，不能删除');
              return false;
            }

            if (index < 0 || index >= _configList.length) {
              AppLog.instance.put('删除配置失败：索引超出范围');
              return false;
            }

            // 从列表中移除配置
            _configList.removeAt(index);

            // 保存更新后的配置列表
            await saveConfigs(_configList);

            AppLog.instance.put('已删除配置，当前配置数量: ${_configList.length}');
            return true;
          },
          operationName: '删除阅读配置',
          logError: true,
        ) ??
        false;
  }
}
