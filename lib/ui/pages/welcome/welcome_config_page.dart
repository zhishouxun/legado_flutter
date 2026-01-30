import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../../../config/app_config.dart';
import 'welcome_image_picker.dart';
import '../../widgets/common/custom_switch_list_tile.dart';

/// 欢迎页配置页面
class WelcomeConfigPage extends StatefulWidget {
  const WelcomeConfigPage({super.key});

  @override
  State<WelcomeConfigPage> createState() => _WelcomeConfigPageState();
}

class _WelcomeConfigPageState extends State<WelcomeConfigPage> {
  String? _welcomeImagePath;
  String? _welcomeImageDarkPath;
  bool _showText = true;
  bool _showIcon = true;
  bool _showTextDark = true;
  bool _showIconDark = true;
  bool _customWelcome = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    setState(() {
      _customWelcome = AppConfig.getBool('customWelcome', defaultValue: false);
      _welcomeImagePath = AppConfig.getString('welcomeImagePath');
      _welcomeImageDarkPath = AppConfig.getString('welcomeImagePathDark');
      _showText = AppConfig.getBool('welcomeShowText', defaultValue: true);
      _showIcon = AppConfig.getBool('welcomeShowIcon', defaultValue: true);
      _showTextDark = AppConfig.getBool('welcomeShowTextDark', defaultValue: true);
      _showIconDark = AppConfig.getBool('welcomeShowIconDark', defaultValue: true);
    });
  }

  Future<void> _selectWelcomeImage(bool isDark) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => WelcomeImagePicker(
        currentImagePath: isDark ? _welcomeImageDarkPath : _welcomeImagePath,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (isDark) {
          _welcomeImageDarkPath = result.isEmpty ? null : result;
        } else {
          _welcomeImagePath = result.isEmpty ? null : result;
        }
      });

      // 保存配置
      if (isDark) {
        if (result.isEmpty) {
          await AppConfig.remove('welcomeImagePathDark');
        } else {
          await AppConfig.setString('welcomeImagePathDark', result);
        }
      } else {
        if (result.isEmpty) {
          await AppConfig.remove('welcomeImagePath');
        } else {
          await AppConfig.setString('welcomeImagePath', result);
        }
      }

      // 如果删除了图片，恢复默认设置
      if (result.isEmpty) {
        if (isDark) {
          await AppConfig.setBool('welcomeShowTextDark', true);
          await AppConfig.setBool('welcomeShowIconDark', true);
          setState(() {
            _showTextDark = true;
            _showIconDark = true;
          });
        } else {
          await AppConfig.setBool('welcomeShowText', true);
          await AppConfig.setBool('welcomeShowIcon', true);
          setState(() {
            _showText = true;
            _showIcon = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('欢迎页配置'),
      ),
      body: ListView(
        children: [
          // 自定义欢迎页开关
          CustomSwitchListTile(
            title: const Text('自定义欢迎页'),
            subtitle: const Text('启用自定义启动页设置'),
            value: _customWelcome,
            onChanged: (value) async {
              await AppConfig.setBool('customWelcome', value);
              setState(() {
                _customWelcome = value;
              });
            },
          ),
          const Divider(),
          // 日间主题配置
          ExpansionTile(
            title: const Text('日间主题'),
            initiallyExpanded: true,
            children: [
              ListTile(
                title: const Text('背景图片'),
                subtitle: Text(
                  _welcomeImagePath != null && _welcomeImagePath!.isNotEmpty
                      ? path.basename(_welcomeImagePath!)
                      : '未设置',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectWelcomeImage(false),
              ),
              if (_welcomeImagePath != null && _welcomeImagePath!.isNotEmpty) ...[
                CustomSwitchListTile(
                  title: const Text('显示文字'),
                  subtitle: const Text('在启动页显示应用名称'),
                  value: _showText,
                  onChanged: (value) async {
                    await AppConfig.setBool('welcomeShowText', value);
                    setState(() {
                      _showText = value;
                    });
                  },
                ),
                CustomSwitchListTile(
                  title: const Text('显示图标'),
                  subtitle: const Text('在启动页显示应用图标'),
                  value: _showIcon,
                  onChanged: (value) async {
                    await AppConfig.setBool('welcomeShowIcon', value);
                    setState(() {
                      _showIcon = value;
                    });
                  },
                ),
              ],
            ],
          ),
          const Divider(),
          // 夜间主题配置
          ExpansionTile(
            title: const Text('夜间主题'),
            initiallyExpanded: true,
            children: [
              ListTile(
                title: const Text('背景图片'),
                subtitle: Text(
                  _welcomeImageDarkPath != null && _welcomeImageDarkPath!.isNotEmpty
                      ? path.basename(_welcomeImageDarkPath!)
                      : '未设置',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectWelcomeImage(true),
              ),
              if (_welcomeImageDarkPath != null && _welcomeImageDarkPath!.isNotEmpty) ...[
                CustomSwitchListTile(
                  title: const Text('显示文字'),
                  subtitle: const Text('在启动页显示应用名称'),
                  value: _showTextDark,
                  onChanged: (value) async {
                    await AppConfig.setBool('welcomeShowTextDark', value);
                    setState(() {
                      _showTextDark = value;
                    });
                  },
                ),
                CustomSwitchListTile(
                  title: const Text('显示图标'),
                  subtitle: const Text('在启动页显示应用图标'),
                  value: _showIconDark,
                  onChanged: (value) async {
                    await AppConfig.setBool('welcomeShowIconDark', value);
                    setState(() {
                      _showIconDark = value;
                    });
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

