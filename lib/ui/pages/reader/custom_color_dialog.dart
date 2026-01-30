import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import '../../../data/models/book.dart';
import '../../../services/book/book_service.dart';
import '../../../services/read_config_service.dart';
import '../../../utils/app_log.dart';
import '../../widgets/common/custom_switch.dart';

/// 自定义颜色和背景设置对话框
class CustomColorDialog extends ConsumerStatefulWidget {
  final Book book;
  final ValueChanged<ReadConfig>? onConfigChanged;
  final int? configIndex; // 配置在ReadConfigService中的索引，用于删除

  const CustomColorDialog({
    super.key,
    required this.book,
    this.onConfigChanged,
    this.configIndex,
  });

  @override
  ConsumerState<CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends ConsumerState<CustomColorDialog> {
  late ReadConfig _config;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _config = widget.book.readConfig ?? ReadConfig();
    _nameController = TextEditingController(
      text: _config.styleName ?? '文字',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        // 渐变背景，与reader_settings_page.dart一致
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a1a),
            Color(0xFF2a2a2a),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(),
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 开关选项
                  _buildToggleOptions(),
                  const SizedBox(height: 16),
                  // 颜色选择
                  _buildColorOptions(),
                  const SizedBox(height: 16),
                  // 背景透明度
                  _buildBackgroundTransparency(),
                  const SizedBox(height: 16),
                  // 背景图片
                  _buildBackgroundImages(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        children: [
          // 拖动指示器
          Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 样式名称
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        '样式名称: ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _nameController.text,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.white70, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _showEditNameDialog,
                      ),
                    ],
                  ),
                ),
                // 恢复按钮
                TextButton(
                  onPressed: _restoreDefault,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                  ),
                  child: const Text(
                    '恢复',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 4),
                // 删除按钮
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFFF6B6B),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _showDeleteConfirmDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 显示编辑名称对话框
  void _showEditNameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          '样式名称',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '请输入样式名称',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.orange),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _config = _config.copyWith(styleName: _nameController.text);
              });
              _saveConfig();
              Navigator.pop(context);
            },
            child: const Text('确定', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  /// 构建开关选项
  Widget _buildToggleOptions() {
    return Column(
      children: [
        // 深色状态栏图标
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '深色状态栏图标',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            CustomSwitch(
              value: _config.darkStatusIcon,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(darkStatusIcon: value);
                });
                _saveConfig();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 文字下划线
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '文字下划线',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            CustomSwitch(
              value: _config.underline,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(underline: value);
                });
                _saveConfig();
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 构建颜色选择选项
  Widget _buildColorOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // 文字颜色按钮
            Expanded(
              child: _buildColorButton(
                label: '文字颜色',
                color: Color(_config.textColor),
                onTap: () => _showColorPicker(true),
              ),
            ),
            const SizedBox(width: 12),
            // 背景颜色按钮
            Expanded(
              child: _buildColorButton(
                label: '背景颜色',
                color: Color(_config.backgroundColor),
                onTap: () => _showColorPicker(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建颜色按钮
  Widget _buildColorButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示颜色选择器
  void _showColorPicker(bool isTextColor) {
    final currentColor =
        isTextColor ? _config.textColor : _config.backgroundColor;
    final presetColors = [
      0xFF000000, // 黑色
      0xFFFFFFFF, // 白色
      0xFF333333, // 深灰
      0xFF666666, // 中灰
      0xFF999999, // 浅灰
      0xFF0000FF, // 蓝色
      0xFF008000, // 绿色
      0xFFFF0000, // 红色
      0xFFFFA500, // 橙色
      0xFF800080, // 紫色
      0xFFFFC0CB, // 粉色
      0xFF4B0082, // 靛蓝
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          isTextColor ? '选择文字颜色' : '选择背景颜色',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '预设颜色',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presetColors.map((color) {
                  final isSelected = currentColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isTextColor) {
                          _config = _config.copyWith(textColor: color);
                        } else {
                          _config = _config.copyWith(backgroundColor: color);
                        }
                      });
                      _saveConfig();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF6B6B)
                              : Colors.white.withOpacity(0.3),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 自定义颜色输入（简化版）
              const Text(
                '自定义颜色（十六进制，如 #FF0000）',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      '#${currentColor.toRadixString(16).substring(2).toUpperCase()}',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.startsWith('#') && value.length == 7) {
                    try {
                      final color =
                          int.parse(value.substring(1), radix: 16) | 0xFF000000;
                      setState(() {
                        if (isTextColor) {
                          _config = _config.copyWith(textColor: color);
                        } else {
                          _config = _config.copyWith(backgroundColor: color);
                        }
                      });
                      _saveConfig();
                      Navigator.pop(context);
                    } catch (e) {
                      // 忽略错误
                    }
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  /// 构建背景透明度滑块
  Widget _buildBackgroundTransparency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '背景透明度',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  activeTrackColor: const Color(0xFFFF6B6B),
                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6.0,
                  ),
                  thumbColor: const Color(0xFFFF6B6B),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12.0,
                  ),
                  overlayColor: const Color(0xFFFF6B6B).withOpacity(0.2),
                ),
                child: Slider(
                  value: _config.bgAlpha.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  activeColor: const Color(0xFFFF6B6B),
                  onChanged: (value) {
                    setState(() {
                      _config = _config.copyWith(bgAlpha: value.toInt());
                    });
                  },
                  onChangeEnd: (value) {
                    _saveConfig();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 50,
              child: Text(
                '${_config.bgAlpha}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建背景图片选择
  Widget _buildBackgroundImages() {
    final bgImages = [
      '选择图片',
      '午后沙滩',
      '宁静夜色',
      '山水墨影',
      '山水画',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '背景图片',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: bgImages.map((name) {
              final isSelected = _config.bgImage == name;
              final isFirst = name == '选择图片';

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    if (isFirst) {
                      _pickBackgroundImage();
                    } else {
                      setState(() {
                        _config = _config.copyWith(bgImage: name);
                      });
                      _saveConfig();
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isFirst
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFF4A4A4A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF6B6B)
                            : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: isFirst
                        ? const Icon(
                            Icons.add_photo_alternate,
                            color: Colors.white70,
                            size: 32,
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              // 背景图片预览
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/bg/$name.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // 如果图片加载失败，显示文字
                                    return Center(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // 选中状态遮罩
                              if (isSelected)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange,
                                      width: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 选择背景图片
  Future<void> _pickBackgroundImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // 保存图片到应用目录
        final savedPath = await _saveImageToAppDir(image.path);
        if (savedPath != null) {
          setState(() {
            _config = _config.copyWith(bgImage: savedPath);
          });
          _saveConfig();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('背景图片已设置')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('保存图片失败')),
            );
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('选择背景图片失败: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
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
      final fileName = 'bg_${digest.toString()}$extension';

      // 保存到应用目录的 background_images 文件夹
      final appDir = await getApplicationDocumentsDirectory();
      final bgImagesDir = Directory('${appDir.path}/background_images');
      if (!await bgImagesDir.exists()) {
        await bgImagesDir.create(recursive: true);
      }

      final savedFile = File('${bgImagesDir.path}/$fileName');
      await savedFile.writeAsBytes(imageBytes);

      AppLog.instance.put('背景图片已保存到: ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      AppLog.instance.put('保存背景图片失败: $e', error: e);
      return null;
    }
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '删除配置',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '确定要删除当前配置"${_nameController.text}"吗？\n\n删除后无法恢复。',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCurrentConfig();
            },
            child: const Text(
              '确定',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
  }

  /// 删除当前配置
  void _deleteCurrentConfig() async {
    try {
      // 检查是否有配置索引
      if (widget.configIndex == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('当前为书籍配置，无法删除。'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // 调用ReadConfigService删除配置
      final success =
          await ReadConfigService.instance.deleteConfig(widget.configIndex!);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除成功'),
              duration: Duration(seconds: 1),
            ),
          );
          // 关闭对话框
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('配置数量已是最少，不能删除'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      AppLog.instance.put('删除配置失败: $e', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  /// 恢复默认设置
  void _restoreDefault() {
    setState(() {
      _config = ReadConfig();
      _nameController.text = _config.styleName ?? '文字';
    });
    _saveConfig();
  }

  /// 保存配置
  void _saveConfig() {
    final updatedBook = widget.book.copyWith(readConfig: _config);
    BookService.instance.saveBook(updatedBook).catchError((error) {});

    if (widget.onConfigChanged != null) {
      widget.onConfigChanged!(_config);
    }
  }
}
