import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../../../config/app_config.dart';
import '../../../core/constants/prefer_key.dart';
import '../../../utils/app_log.dart';
import '../../widgets/common/custom_switch_list_tile.dart';

/// 封面配置页面
/// 参考项目：io.legado.app.ui.config.CoverConfigFragment
class CoverConfigPage extends StatefulWidget {
  const CoverConfigPage({super.key});

  @override
  State<CoverConfigPage> createState() => _CoverConfigPageState();
}

class _CoverConfigPageState extends State<CoverConfigPage> {
  String? _defaultCoverPath;
  String? _defaultCoverDarkPath;
  bool _useDefaultCover = true;
  bool _loadCoverOnlyWifi = false;
  bool _coverShowName = true;
  bool _coverShowAuthor = false;
  bool _coverShowNameN = true;
  bool _coverShowAuthorN = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  /// 加载配置
  void _loadConfig() {
    setState(() {
      _defaultCoverPath = AppConfig.getString(PreferKey.defaultCover);
      _defaultCoverDarkPath = AppConfig.getString(PreferKey.defaultCoverDark);
      _useDefaultCover = AppConfig.getBool(PreferKey.useDefaultCover, defaultValue: true);
      _loadCoverOnlyWifi = AppConfig.getBool(PreferKey.loadCoverOnlyWifi, defaultValue: false);
      _coverShowName = AppConfig.getBool(PreferKey.coverShowName, defaultValue: true);
      _coverShowAuthor = AppConfig.getBool(PreferKey.coverShowAuthor, defaultValue: false);
      _coverShowNameN = AppConfig.getBool(PreferKey.coverShowNameN, defaultValue: true);
      _coverShowAuthorN = AppConfig.getBool(PreferKey.coverShowAuthorN, defaultValue: false);
    });
  }

  /// 保存图片到应用目录
  Future<String?> _saveImageToAppDir(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        AppLog.instance.put('图片文件不存在: $imagePath');
        return null;
      }

      // 读取文件内容
      final imageBytes = await imageFile.readAsBytes();
      
      // 计算MD5作为文件名
      final digest = md5.convert(imageBytes);
      final extension = path.extension(imagePath);
      final fileName = 'cover_${digest.toString()}$extension';
      
      // 保存到应用目录的 covers 文件夹
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }
      
      final savedFile = File('${coversDir.path}/$fileName');
      await savedFile.writeAsBytes(imageBytes);
      
      AppLog.instance.put('封面图片已保存到: ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      AppLog.instance.put('保存封面图片失败: $e', error: e);
      return null;
    }
  }

  /// 选择封面图片
  Future<void> _selectCoverImage(bool isDark) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // 保存图片到应用目录
        final savedPath = await _saveImageToAppDir(image.path);
        if (savedPath == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('保存图片失败')),
            );
          }
          return;
        }

        setState(() {
          if (isDark) {
            _defaultCoverDarkPath = savedPath;
          } else {
            _defaultCoverPath = savedPath;
          }
        });

        // 保存配置
        if (isDark) {
          await AppConfig.setString(PreferKey.defaultCoverDark, savedPath);
        } else {
          await AppConfig.setString(PreferKey.defaultCover, savedPath);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('封面已设置')),
          );
        }
      }
    } catch (e) {
      AppLog.instance.put('选择封面图片失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  /// 清除封面图片
  Future<void> _clearCoverImage(bool isDark) async {
    try {
      // 获取当前封面路径
      final currentPath = isDark ? _defaultCoverDarkPath : _defaultCoverPath;
      
      // 删除文件（如果存在）
      if (currentPath != null && currentPath.isNotEmpty) {
        try {
          final file = File(currentPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          AppLog.instance.put('删除封面文件失败: $currentPath', error: e);
          // 继续执行，即使删除文件失败也清除配置
        }
      }

      setState(() {
        if (isDark) {
          _defaultCoverDarkPath = null;
        } else {
          _defaultCoverPath = null;
        }
      });

      // 清除配置
      if (isDark) {
        await AppConfig.remove(PreferKey.defaultCoverDark);
      } else {
        await AppConfig.remove(PreferKey.defaultCover);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('封面已清除')),
        );
      }
    } catch (e) {
      AppLog.instance.put('清除封面失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除封面失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('封面配置'),
      ),
      body: ListView(
        children: [
          // 使用默认封面
          CustomSwitchListTile(
            title: const Text('使用默认封面'),
            subtitle: const Text('为没有封面的书籍使用默认封面'),
            value: _useDefaultCover,
            onChanged: (value) async {
              await AppConfig.setBool(PreferKey.useDefaultCover, value);
              setState(() {
                _useDefaultCover = value;
              });
            },
          ),
          const Divider(),

          // 仅在WiFi下加载封面
          CustomSwitchListTile(
            title: const Text('仅在WiFi下加载封面'),
            subtitle: const Text('移动网络下不加载封面图片'),
            value: _loadCoverOnlyWifi,
            onChanged: (value) async {
              await AppConfig.setBool(PreferKey.loadCoverOnlyWifi, value);
              setState(() {
                _loadCoverOnlyWifi = value;
              });
            },
          ),
          const Divider(),

          // 日间主题封面
          ExpansionTile(
            title: const Text('日间主题封面'),
            initiallyExpanded: true,
            children: [
              ListTile(
                title: const Text('默认封面'),
                subtitle: Text(
                  _defaultCoverPath != null && _defaultCoverPath!.isNotEmpty
                      ? path.basename(_defaultCoverPath!)
                      : '未设置',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_defaultCoverPath != null && _defaultCoverPath!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _clearCoverImage(false),
                        tooltip: '清除封面',
                      ),
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: () => _selectCoverImage(false),
                      tooltip: '选择封面',
                    ),
                  ],
                ),
              ),
              if (_defaultCoverPath != null && _defaultCoverPath!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_defaultCoverPath!),
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('图片加载失败', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              CustomSwitchListTile(
                title: const Text('显示名称'),
                subtitle: const Text('在封面上显示书籍名称'),
                value: _coverShowName,
                onChanged: (value) async {
                  await AppConfig.setBool(PreferKey.coverShowName, value);
                  if (!value) {
                    await AppConfig.setBool(PreferKey.coverShowAuthor, false);
                  }
                  setState(() {
                    _coverShowName = value;
                    if (!value) {
                      _coverShowAuthor = false;
                    }
                  });
                },
              ),
              CustomSwitchListTile(
                title: const Text('显示作者'),
                subtitle: const Text('在封面上显示作者名称'),
                value: _coverShowAuthor,
                onChanged: _coverShowName
                    ? (value) async {
                        await AppConfig.setBool(PreferKey.coverShowAuthor, value);
                        setState(() {
                          _coverShowAuthor = value;
                        });
                      }
                    : null,
              ),
            ],
          ),
          const Divider(),

          // 夜间主题封面
          ExpansionTile(
            title: const Text('夜间主题封面'),
            initiallyExpanded: true,
            children: [
              ListTile(
                title: const Text('默认封面'),
                subtitle: Text(
                  _defaultCoverDarkPath != null && _defaultCoverDarkPath!.isNotEmpty
                      ? path.basename(_defaultCoverDarkPath!)
                      : '未设置',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_defaultCoverDarkPath != null && _defaultCoverDarkPath!.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _clearCoverImage(true),
                        tooltip: '清除封面',
                      ),
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: () => _selectCoverImage(true),
                      tooltip: '选择封面',
                    ),
                  ],
                ),
              ),
              if (_defaultCoverDarkPath != null && _defaultCoverDarkPath!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_defaultCoverDarkPath!),
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('图片加载失败', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              CustomSwitchListTile(
                title: const Text('显示名称'),
                subtitle: const Text('在封面上显示书籍名称'),
                value: _coverShowNameN,
                onChanged: (value) async {
                  await AppConfig.setBool(PreferKey.coverShowNameN, value);
                  if (!value) {
                    await AppConfig.setBool(PreferKey.coverShowAuthorN, false);
                  }
                  setState(() {
                    _coverShowNameN = value;
                    if (!value) {
                      _coverShowAuthorN = false;
                    }
                  });
                },
              ),
              CustomSwitchListTile(
                title: const Text('显示作者'),
                subtitle: const Text('在封面上显示作者名称'),
                value: _coverShowAuthorN,
                onChanged: _coverShowNameN
                    ? (value) async {
                        await AppConfig.setBool(PreferKey.coverShowAuthorN, value);
                        setState(() {
                          _coverShowAuthorN = value;
                        });
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

