import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../config/app_config.dart';
import '../../../core/constants/prefer_key.dart';
import '../../../utils/app_log.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 字体选择对话框
class FontSelectDialog extends BaseBottomSheetStateful {
  final String? currentFontFamily;
  final Function(String? fontFamily) onFontSelected;

  const FontSelectDialog({
    super.key,
    this.currentFontFamily,
    required this.onFontSelected,
  }) : super(
          title: '选择字体',
          heightFactor: 0.8,
        );

  @override
  State<FontSelectDialog> createState() => _FontSelectDialogState();
}

class _FontSelectDialogState extends BaseBottomSheetState<FontSelectDialog> {
  List<String> _systemFonts = [];
  List<String> _customFonts = [];
  bool _isLoading = false;
  String? _selectedFont;
  String? _fontFolderPath;

  @override
  void initState() {
    super.initState();
    _selectedFont = widget.currentFontFamily;
    _loadFontFolder();
    _loadFonts();
  }

  /// 加载字体文件夹路径
  void _loadFontFolder() {
    _fontFolderPath = AppConfig.getString(PreferKey.fontFolder);
  }

  Future<void> _loadFonts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 加载系统字体列表
      _systemFonts = _getSystemFonts();

      // 加载自定义字体（从应用目录）
      _customFonts = await _loadCustomFonts();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _getSystemFonts() {
    // Flutter 系统字体列表
    return [
      '系统默认',
      'Roboto',
      'Arial',
      'Helvetica',
      'Times New Roman',
      'Courier New',
      'Verdana',
      'Georgia',
      'Palatino',
      'Garamond',
      'Bookman',
      'Comic Sans MS',
      'Trebuchet MS',
      'Impact',
      'Lucida Console',
      'Tahoma',
      'Monaco',
      'Menlo',
      'Consolas',
      'Courier',
    ];
  }

  /// 加载自定义字体文件
  Future<List<String>> _loadCustomFonts() async {
    final fonts = <String>[];

    try {
      // 1. 从应用目录的fonts文件夹加载
      final appDir = await getApplicationDocumentsDirectory();
      final fontsDir = Directory('${appDir.path}/fonts');
      if (await fontsDir.exists()) {
        final fontFiles = await _scanFontFiles(fontsDir);
        fonts.addAll(fontFiles);
      }

      // 2. 从配置的字体文件夹加载
      if (_fontFolderPath != null && _fontFolderPath!.isNotEmpty) {
        final folderDir = Directory(_fontFolderPath!);
        if (await folderDir.exists()) {
          final folderFonts = await _scanFontFiles(folderDir);
          fonts.addAll(folderFonts);
        }
      }
    } catch (e) {
      AppLog.instance.put('加载自定义字体失败', error: e);
    }

    // 去重并返回
    return fonts.toSet().toList();
  }

  /// 扫描目录中的字体文件
  Future<List<String>> _scanFontFiles(Directory directory) async {
    final fonts = <String>[];
    final fontExtensions = ['.ttf', '.otf', '.woff', '.woff2'];

    try {
      await for (final entity in directory.list(recursive: false)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (fontExtensions.contains(extension)) {
            fonts.add(entity.path);
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('扫描字体文件失败: ${directory.path}', error: e);
    }

    return fonts;
  }

  /// 导入字体文件
  Future<void> _importFont() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf', 'woff', 'woff2'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        final fileName = result.files.single.name;

        // 复制字体文件到应用目录
        final savedPath = await _saveFontToAppDir(sourcePath, fileName);
        if (savedPath != null) {
          // 重新加载字体列表
          await _loadFonts();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('字体已导入: $fileName')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('保存字体文件失败')),
            );
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('导入字体失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入字体失败: $e')),
        );
      }
    }
  }

  /// 保存字体文件到应用目录
  Future<String?> _saveFontToAppDir(String sourcePath, String fileName) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      // 获取应用目录下的fonts文件夹
      final appDir = await getApplicationDocumentsDirectory();
      final fontsDir = Directory('${appDir.path}/fonts');
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }

      // 复制文件
      final targetFile = File('${fontsDir.path}/$fileName');
      await sourceFile.copy(targetFile.path);

      return targetFile.path;
    } catch (e) {
      AppLog.instance.put('保存字体文件失败: $sourcePath', error: e);
      return null;
    }
  }

  /// 选择字体文件夹
  Future<void> _selectFontFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null && mounted) {
        // 保存字体文件夹路径
        await AppConfig.setString(PreferKey.fontFolder, result);
        _fontFolderPath = result;

        // 重新加载字体列表
        await _loadFonts();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('字体文件夹已设置')),
        );
      }
    } catch (e) {
      AppLog.instance.put('选择字体文件夹失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件夹失败: $e')),
        );
      }
    }
  }

  /// 清除字体文件夹设置
  Future<void> _clearFontFolder() async {
    await AppConfig.remove(PreferKey.fontFolder);
    _fontFolderPath = null;
    await _loadFonts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('字体文件夹已清除')),
      );
    }
  }

  void _selectFont(String? fontFamily) {
    setState(() {
      _selectedFont = fontFamily;
    });
    widget.onFontSelected(fontFamily);
    Navigator.of(context).pop();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 选择字体文件夹按钮
              IconButton(
                icon: const Icon(Icons.folder),
                onPressed: _selectFontFolder,
                tooltip: '选择字体文件夹',
              ),
              // 清除字体文件夹按钮（如果有设置）
              if (_fontFolderPath != null && _fontFolderPath!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.folder_delete),
                  onPressed: _clearFontFolder,
                  tooltip: '清除字体文件夹',
                ),
              // 导入字体按钮
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _importFont,
                tooltip: '导入字体文件',
              ),
            ],
          ),
        ),
        // 内容区域
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    // 系统字体
                    if (_systemFonts.isNotEmpty) ...[
                      _buildSectionHeader('系统字体'),
                      ..._systemFonts.map((font) => _buildFontItem(
                            font,
                            font == '系统默认' ? null : font,
                            font == '系统默认' ? '系统默认字体' : font,
                          )),
                    ],
                    // 自定义字体
                    if (_customFonts.isNotEmpty) ...[
                      _buildSectionHeader('自定义字体'),
                      ..._customFonts.map((font) => _buildFontItem(
                            path.basenameWithoutExtension(font),
                            font,
                            '字体预览：AaBbCc 123 字体效果展示',
                          )),
                    ],
                    // 导入字体提示
                    if (_customFonts.isEmpty) ...[
                      _buildSectionHeader('自定义字体'),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.font_download_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '暂无自定义字体',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '点击右上角 + 按钮导入字体文件',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFontItem(
      String displayName, String? fontFamily, String previewText) {
    final isSelected = _selectedFont == fontFamily;
    final theme = Theme.of(context);

    // 如果是文件路径，提取文件名作为显示名称
    final display = fontFamily != null && fontFamily.contains('/')
        ? path.basenameWithoutExtension(fontFamily)
        : displayName;

    return InkWell(
      onTap: () => _selectFont(fontFamily),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
          border: Border(
            left: BorderSide(
              color:
                  isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // 选中图标
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              )
            else
              const Icon(
                Icons.circle_outlined,
                color: Colors.grey,
                size: 20,
              ),
            const SizedBox(width: 12),
            // 字体预览
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 字体预览文本
                  Text(
                    previewText,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 如果是文件路径，显示路径信息
                  if (fontFamily != null && fontFamily.contains('/'))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        path.dirname(fontFamily),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
