import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../data/models/theme_config.dart';
import '../../../services/theme_service.dart';
import '../../widgets/common/custom_switch_list_tile.dart';

/// 主题编辑页面
class ThemeEditPage extends StatefulWidget {
  final ThemeConfig? config;

  const ThemeEditPage({super.key, this.config});

  @override
  State<ThemeEditPage> createState() => _ThemeEditPageState();
}

class _ThemeEditPageState extends State<ThemeEditPage> {
  late TextEditingController _nameController;
  late bool _isNightTheme;
  late Color _primaryColor;
  late Color _accentColor;
  late Color _backgroundColor;
  late Color _bottomBackgroundColor;

  @override
  void initState() {
    super.initState();
    if (widget.config != null) {
      _nameController = TextEditingController(text: widget.config!.themeName);
      _isNightTheme = widget.config!.isNightTheme;
      _primaryColor = _parseColor(widget.config!.primaryColor);
      _accentColor = _parseColor(widget.config!.accentColor);
      _backgroundColor = _parseColor(widget.config!.backgroundColor);
      _bottomBackgroundColor = _parseColor(widget.config!.bottomBackground);
    } else {
      _nameController = TextEditingController();
      _isNightTheme = false;
      _primaryColor = const Color(0xFF795548);
      _accentColor = const Color(0xFFD32F2F);
      _backgroundColor = const Color(0xFFF5F5F5);
      _bottomBackgroundColor = const Color(0xFFEEEEEE);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _parseColor(String colorString) {
    try {
      String hex = colorString.replaceFirst('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  String _colorToString(Color color) {
    final hex = color.value.toRadixString(16).toUpperCase();
    if (hex.length == 8) {
      return '#${hex.substring(2)}';
    }
    return '#$hex';
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入主题名称')),
      );
      return;
    }

    try {
      final config = ThemeConfig(
        themeName: _nameController.text.trim(),
        isNightTheme: _isNightTheme,
        primaryColor: _colorToString(_primaryColor),
        accentColor: _colorToString(_accentColor),
        backgroundColor: _colorToString(_backgroundColor),
        bottomBackground: _colorToString(_bottomBackgroundColor),
      );

      await ThemeService.instance.addConfig(config);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  void _showColorPicker(String title, Color currentColor, Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: onColorChanged,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hslWithSaturation,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config == null ? '新建主题' : '编辑主题'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: '保存',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题名称
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '主题名称',
              hintText: '请输入主题名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 主题类型
          CustomSwitchListTile(
            title: const Text('深色主题'),
            subtitle: const Text('开启后为深色主题，关闭为浅色主题'),
            value: _isNightTheme,
            onChanged: (value) {
              setState(() {
                _isNightTheme = value;
                // 切换主题类型时，使用默认颜色
                if (value) {
                  _primaryColor = const Color(0xFF546E7A);
                  _accentColor = const Color(0xFFBF360C);
                  _backgroundColor = const Color(0xFF212121);
                  _bottomBackgroundColor = const Color(0xFF303030);
                } else {
                  _primaryColor = const Color(0xFF795548);
                  _accentColor = const Color(0xFFD32F2F);
                  _backgroundColor = const Color(0xFFF5F5F5);
                  _bottomBackgroundColor = const Color(0xFFEEEEEE);
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // 主色
          _ColorPickerTile(
            title: '主色',
            color: _primaryColor,
            onTap: () {
              _showColorPicker('选择主色', _primaryColor, (color) {
                setState(() {
                  _primaryColor = color;
                });
              });
            },
          ),
          const SizedBox(height: 8),

          // 强调色
          _ColorPickerTile(
            title: '强调色',
            color: _accentColor,
            onTap: () {
              _showColorPicker('选择强调色', _accentColor, (color) {
                setState(() {
                  _accentColor = color;
                });
              });
            },
          ),
          const SizedBox(height: 8),

          // 背景色
          _ColorPickerTile(
            title: '背景色',
            color: _backgroundColor,
            onTap: () {
              _showColorPicker('选择背景色', _backgroundColor, (color) {
                setState(() {
                  _backgroundColor = color;
                });
              });
            },
          ),
          const SizedBox(height: 8),

          // 底部背景色
          _ColorPickerTile(
            title: '底部背景色',
            color: _bottomBackgroundColor,
            onTap: () {
              _showColorPicker('选择底部背景色', _bottomBackgroundColor, (color) {
                setState(() {
                  _bottomBackgroundColor = color;
                });
              });
            },
          ),
          const SizedBox(height: 24),

          // 预览
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '预览',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '主色示例',
                            style: TextStyle(
                              color: _isNightTheme ? Colors.white : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '强调色示例',
                            style: TextStyle(
                              color: _isNightTheme ? Colors.white : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bottomBackgroundColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '底部背景色示例',
                            style: TextStyle(
                              color: _isNightTheme ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 颜色选择器Tile
class _ColorPickerTile extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ColorPickerTile({
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

