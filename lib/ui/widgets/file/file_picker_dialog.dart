import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';
import '../../../services/file_manage_service.dart';
import '../../../utils/app_log.dart';

/// 文件选择模式
enum FilePickerMode {
  /// 选择文件
  file,

  /// 选择文件夹
  folder,

  /// 保存文件
  save,
}

/// 文件选择对话框
/// 参考项目：FilePickerDialog.kt
class FilePickerDialog extends BaseBottomSheetStateful {
  /// 选择模式
  final FilePickerMode mode;

  /// 对话框标题
  @override
  final String? title;

  /// 初始路径
  final String? initPath;

  /// 是否显示隐藏文件/文件夹
  final bool showHidden;

  /// 允许的文件扩展名（仅在选择文件模式下有效）
  final List<String>? allowedExtensions;

  /// 文件选择回调
  final Function(String path) onFileSelected;

  /// 取消回调
  final VoidCallback? onCancel;

  FilePickerDialog({
    super.key,
    required this.mode,
    this.title,
    this.initPath,
    this.showHidden = false,
    this.allowedExtensions,
    required this.onFileSelected,
    this.onCancel,
  }) : super(
          title: title ?? _getDefaultTitle(mode),
          heightFactor: 0.8,
        );

  static String _getDefaultTitle(FilePickerMode mode) {
    switch (mode) {
      case FilePickerMode.file:
        return '选择文件';
      case FilePickerMode.folder:
        return '选择文件夹';
      case FilePickerMode.save:
        return '保存文件';
    }
  }

  @override
  State<FilePickerDialog> createState() => _FilePickerDialogState();
}

class _FilePickerDialogState extends BaseBottomSheetState<FilePickerDialog> {
  final FileManageService _fileService = FileManageService.instance;
  final TextEditingController _searchController = TextEditingController();

  Directory? _currentDirectory;
  List<FileInfo> _files = [];
  List<Directory> _pathStack = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadInitialDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  /// 加载初始目录
  Future<void> _loadInitialDirectory() async {
    setState(() {
      _isLoading = true;
      _pathStack.clear();
    });

    try {
      Directory? initDir;

      if (widget.initPath != null && widget.initPath!.isNotEmpty) {
        initDir = Directory(widget.initPath!);
        if (!await initDir.exists()) {
          initDir = null;
        }
      }

      initDir ??= await _fileService.getAppDocumentsDirectory();

      await _loadDirectory(initDir);
    } catch (e) {
      AppLog.instance.put('加载初始目录失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载目录失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 加载目录
  Future<void> _loadDirectory(Directory directory) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _fileService.getFilesInDirectory(directory);
      setState(() {
        _currentDirectory = directory;
        _files = files.where((file) {
          // 过滤隐藏文件
          if (!widget.showHidden && file.name.startsWith('.')) {
            return false;
          }
          // 如果是选择文件模式，过滤文件扩展名
          if (widget.mode == FilePickerMode.file && !file.isDirectory) {
            if (widget.allowedExtensions != null &&
                widget.allowedExtensions!.isNotEmpty) {
              final extension = file.name.split('.').last.toLowerCase();
              return widget.allowedExtensions!.contains(extension);
            }
          }
          return true;
        }).toList();
      });
    } catch (e) {
      AppLog.instance.put('加载目录失败: ${directory.path}', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载目录失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 进入目录
  void _enterDirectory(FileInfo fileInfo) {
    if (fileInfo.name == '..') {
      // 返回上一级
      if (_pathStack.isNotEmpty) {
        final parentDir = _pathStack.removeLast();
        _loadDirectory(parentDir);
      } else {
        _loadInitialDirectory();
      }
    } else if (fileInfo.isDirectory && fileInfo.name != '.') {
      // 进入目录
      final dir = Directory(fileInfo.path);
      _pathStack.add(_currentDirectory!);
      _loadDirectory(dir);
    } else if (!fileInfo.isDirectory) {
      // 选择文件
      if (widget.mode == FilePickerMode.file) {
        widget.onFileSelected(fileInfo.path);
        Navigator.of(context).pop();
      }
    }
  }

  /// 选择当前文件夹
  void _selectCurrentFolder() {
    if (widget.mode == FilePickerMode.folder && _currentDirectory != null) {
      widget.onFileSelected(_currentDirectory!.path);
      Navigator.of(context).pop();
    }
  }

  /// 获取过滤后的文件列表
  List<FileInfo> get _filteredFiles {
    if (_searchQuery.isEmpty) {
      return _files;
    }
    return _files.where((file) {
      if (file.name == '..' || file.name == '.') return true;
      return file.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索文件...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        // 路径导航
        if (_pathStack.isNotEmpty || _currentDirectory != null)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // 根目录
                _PathChip(
                  label: '根目录',
                  onTap: () {
                    _pathStack.clear();
                    _loadInitialDirectory();
                  },
                ),
                // 路径面包屑
                ..._pathStack.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dir = entry.value;
                  return _PathChip(
                    label: dir.path.split(Platform.pathSeparator).last,
                    onTap: () {
                      _pathStack = _pathStack.sublist(0, index);
                      _loadDirectory(dir);
                    },
                  );
                }),
                // 当前目录
                if (_currentDirectory != null)
                  _PathChip(
                    label: _currentDirectory!.path
                        .split(Platform.pathSeparator)
                        .last,
                    isCurrent: true,
                  ),
              ],
            ),
          ),
        // 文件列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? '未找到匹配的文件' : '目录为空',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredFiles.length,
                      itemBuilder: (context, index) {
                        final fileInfo = _filteredFiles[index];
                        return _FileItemWidget(
                          fileInfo: fileInfo,
                          mode: widget.mode,
                          onTap: () => _enterDirectory(fileInfo),
                        );
                      },
                    ),
        ),
        // 底部操作按钮
        if (widget.mode == FilePickerMode.folder && _currentDirectory != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCancel?.call();
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectCurrentFolder,
                  child: const Text('选择此文件夹'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 路径导航Chip
class _PathChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isCurrent;

  const _PathChip({
    required this.label,
    this.onTap,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (onTap != null && !isCurrent) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.grey[600],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 文件项组件
class _FileItemWidget extends StatelessWidget {
  final FileInfo fileInfo;
  final FilePickerMode mode;
  final VoidCallback onTap;

  const _FileItemWidget({
    required this.fileInfo,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        fileInfo.isDirectory ? Icons.folder : Icons.insert_drive_file,
        color: fileInfo.isDirectory ? Colors.blue : Colors.grey,
      ),
      title: Text(fileInfo.name),
      subtitle: fileInfo.isDirectory
          ? null
          : Text(
              _formatFileSize(fileInfo.size),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
      trailing: mode == FilePickerMode.folder && fileInfo.isDirectory
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: onTap,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
