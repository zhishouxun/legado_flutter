import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../../services/file_manage_service.dart';
import '../../../services/book/local_book_service.dart';
import '../../../utils/app_log.dart';
import 'file_detail_dialog.dart';

/// 文件管理页面
class FileManagePage extends StatefulWidget {
  const FileManagePage({super.key});

  @override
  State<FileManagePage> createState() => _FileManagePageState();
}

class _FileManagePageState extends State<FileManagePage> {
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
    _loadRootDirectory();
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

  /// 加载根目录
  Future<void> _loadRootDirectory() async {
    setState(() {
      _isLoading = true;
      _pathStack.clear();
    });

    try {
      final rootDir = await _fileService.getAppDocumentsDirectory();
      await _loadDirectory(rootDir);
    } catch (e) {
      AppLog.instance.put('加载根目录失败', error: e);
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
        _files = files;
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
        _loadRootDirectory();
      }
    } else if (fileInfo.isDirectory && fileInfo.name != '.') {
      // 进入目录
      final dir = Directory(fileInfo.path);
      _pathStack.add(_currentDirectory!);
      _loadDirectory(dir);
    } else if (!fileInfo.isDirectory) {
      // 打开文件
      _openFile(fileInfo);
    }
  }

  /// 打开文件
  Future<void> _openFile(FileInfo fileInfo) async {
    try {
      // 如果是书籍文件，尝试导入
      if (_fileService.isBookFile(fileInfo.name)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('导入书籍'),
            content: Text('是否将 "${fileInfo.name}" 导入为书籍？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('导入'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await _importBook(fileInfo.path);
        }
      } else {
        // 使用系统应用打开文件
        final result = await OpenFilex.open(fileInfo.path);
        if (result.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('无法打开文件: ${result.message}')),
            );
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('打开文件失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件失败: $e')),
        );
      }
    }
  }

  /// 导入书籍
  Future<void> _importBook(String filePath) async {
    try {
      final book = await LocalBookService.instance.importBook(filePath);
      if (book != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入成功: ${book.name}')),
        );
      }
    } catch (e) {
      AppLog.instance.put('导入书籍失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  /// 删除文件
  Future<void> _deleteFile(FileInfo fileInfo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${fileInfo.name}" 吗？${fileInfo.isDirectory ? '\n（将删除目录及其所有内容）' : ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _fileService.deleteFile(fileInfo.path);
      if (success) {
        await _loadDirectory(_currentDirectory!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败')),
          );
        }
      }
    } catch (e) {
      AppLog.instance.put('删除文件失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  /// 显示文件菜单
  void _showFileMenu(FileInfo fileInfo) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('文件信息'),
              onTap: () {
                Navigator.pop(context);
                _showFileDetail(fileInfo);
              },
            ),
            if (!fileInfo.isDirectory)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('打开'),
                onTap: () {
                  Navigator.pop(context);
                  _openFile(fileInfo);
                },
              ),
            if (_fileService.isBookFile(fileInfo.name))
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('导入为书籍'),
                onTap: () {
                  Navigator.pop(context);
                  _importBook(fileInfo.path);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteFile(fileInfo);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示文件详情
  void _showFileDetail(FileInfo fileInfo) {
    showDialog(
      context: context,
      builder: (context) => FileDetailDialog(fileInfo: fileInfo),
    );
  }

  /// 导航到路径
  void _navigateToPath(int index) {
    if (index == -1) {
      // 返回根目录
      _loadRootDirectory();
    } else if (index < _pathStack.length) {
      // 导航到指定路径
      final targetDir = _pathStack[index];
      _pathStack = _pathStack.sublist(0, index);
      _loadDirectory(targetDir);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: _loadRootDirectory,
            tooltip: '返回根目录',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索文件',
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
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _PathChip(
                    label: 'root',
                    onTap: () => _navigateToPath(-1),
                  ),
                  ...List.generate(_pathStack.length, (index) {
                    final dir = _pathStack[index];
                    final name = dir.path.split('/').last;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chevron_right, size: 16),
                        _PathChip(
                          label: name.isEmpty ? 'root' : name,
                          onTap: () => _navigateToPath(index),
                        ),
                      ],
                    );
                  }),
                  if (_currentDirectory != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chevron_right, size: 16),
                        _PathChip(
                          label: _currentDirectory!.path.split('/').last.isEmpty
                              ? 'root'
                              : _currentDirectory!.path.split('/').last,
                          isCurrent: true,
                        ),
                      ],
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
                            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? '未找到匹配的文件'
                                  : '目录为空',
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
                            onTap: () => _enterDirectory(fileInfo),
                            onLongPress: () => _showFileMenu(fileInfo),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// 路径导航Chip
class _PathChip extends StatelessWidget {
  final String label;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _PathChip({
    required this.label,
    this.isCurrent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isCurrent
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isCurrent
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 文件项Widget
class _FileItemWidget extends StatelessWidget {
  final FileInfo fileInfo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FileItemWidget({
    required this.fileInfo,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fileService = FileManageService.instance;
    final icon = fileService.getFileIcon(fileInfo.name, fileInfo.isDirectory);

    return ListTile(
      leading: Icon(
        icon,
        color: fileInfo.isDirectory
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(fileInfo.name),
      subtitle: fileInfo.isDirectory
          ? Text(
              '目录',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          : Text(
              '${fileService.formatFileSize(fileInfo.size)} • ${_formatDate(fileInfo.lastModified)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
      trailing: fileInfo.isDirectory
          ? const Icon(Icons.chevron_right)
          : fileService.isBookFile(fileInfo.name)
              ? Icon(Icons.book, color: Theme.of(context).colorScheme.primary)
              : null,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}

