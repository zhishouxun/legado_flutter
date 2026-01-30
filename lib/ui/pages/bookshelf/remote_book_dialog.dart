import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/remote_book.dart';
import '../../../services/book/remote_book_service.dart';
import '../../../services/book/local_book_service.dart';
import '../../../providers/book_provider.dart';
import '../../../utils/app_log.dart';
import '../../widgets/base/base_bottom_sheet_consumer.dart';

/// 远程书籍对话框
class RemoteBookDialog extends BaseBottomSheetConsumer {
  const RemoteBookDialog({super.key}) : super(
          title: '远程书籍',
          heightFactor: 0.8,
        );

  @override
  ConsumerState<RemoteBookDialog> createState() => _RemoteBookDialogState();
}

class _RemoteBookDialogState extends BaseBottomSheetConsumerState<RemoteBookDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final List<RemoteBook> _currentPath = []; // 当前路径栈
  List<RemoteBook> _remoteBooks = [];
  bool _isLoading = false;
  bool _isConfigured = false;
  final Set<RemoteBook> _selectedBooks = {};

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 检查配置
  void _checkConfiguration() {
    setState(() {
      _isConfigured = RemoteBookService.instance.isConfigured;
    });
  }

  /// 配置WebDAV
  void _showConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置WebDAV'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'WebDAV地址',
                  hintText: 'https://example.com/webdav',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final url = _urlController.text.trim();
              if (url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入WebDAV地址')),
                );
                return;
              }

              try {
                RemoteBookService.instance.configure(
                  baseUrl: url,
                  username: _usernameController.text.trim().isEmpty
                      ? null
                      : _usernameController.text.trim(),
                  password: _passwordController.text.trim().isEmpty
                      ? null
                      : _passwordController.text.trim(),
                );

                Navigator.pop(context);
                setState(() {
                  _isConfigured = true;
                });
                await _loadRemoteBooks();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('配置失败: $e')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 加载远程书籍列表
  Future<void> _loadRemoteBooks([String? path]) async {
    if (!_isConfigured) {
      _showConfigDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final books =
          await RemoteBookService.instance.getRemoteBookList(path ?? '/');
      setState(() {
        _remoteBooks = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  /// 进入目录
  void _enterDirectory(RemoteBook dir) {
    setState(() {
      _currentPath.add(dir);
    });
    _loadRemoteBooks(dir.path);
  }

  /// 返回上一级
  void _goBack() {
    if (_currentPath.isEmpty) return;

    setState(() {
      _currentPath.removeLast();
    });

    final path = _currentPath.isEmpty ? '/' : _currentPath.last.path;
    _loadRemoteBooks(path);
  }

  /// 添加到书架
  Future<void> _addToBookshelf(List<RemoteBook> books) async {
    if (books.isEmpty) return;

    // 显示进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在下载并添加到书架...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      int successCount = 0;
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      for (final remoteBook in books) {
        try {
          // 下载文件
          final fileData =
              await RemoteBookService.instance.downloadRemoteBook(remoteBook);

          // 保存到本地
          final localFile = File('${booksDir.path}/${remoteBook.filename}');
          await localFile.writeAsBytes(fileData);

          // 导入到书架
          final book =
              await LocalBookService.instance.importBook(localFile.path);
          if (book == null) {
            throw Exception('导入书籍失败');
          }

          successCount++;
        } catch (e) {
          AppLog.instance.put('添加书籍失败: ${remoteBook.filename}', error: e);
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // 关闭进度对话框

      // 刷新书架 - 需要同时刷新所有分组的书籍列表
      ref.invalidate(refreshBookshelfProvider);
      // 刷新所有分组的书籍列表
      final groupsAsync = ref.read(bookGroupsProvider);
      final groups = groupsAsync.value ?? [];
      for (final group in groups) {
        ref.invalidate(booksByGroupProvider(group.groupId));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功添加 $successCount / ${books.length} 本书籍')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    // 应用搜索筛选
    final filteredBooks = _searchController.text.isEmpty
        ? _remoteBooks
        : _remoteBooks.where((book) {
            final keyword = _searchController.text.toLowerCase();
            return book.filename.toLowerCase().contains(keyword);
          }).toList();

    return Column(
      children: [
        // 搜索框和操作按钮
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: _currentPath.isEmpty
                        ? '远程书籍'
                        : _currentPath.map((d) => d.filename).join(' / '),
                    prefixIcon: _currentPath.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _goBack,
                            tooltip: '返回',
                          )
                        : const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (!_isConfigured)
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showConfigDialog,
                  tooltip: '配置',
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadRemoteBooks(
                    _currentPath.isEmpty ? '/' : _currentPath.last.path),
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        // 批量操作栏
        if (_selectedBooks.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '已选择 ${_selectedBooks.length} 项',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addToBookshelf(_selectedBooks.toList()),
                  tooltip: '添加到书架',
                ),
              ],
            ),
          ),
        // 书籍列表
        Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredBooks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.folder_open,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                _isConfigured ? '暂无书籍' : '请先配置WebDAV',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              if (!_isConfigured) ...[
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _showConfigDialog,
                                  child: const Text('配置WebDAV'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredBooks.length,
                          itemBuilder: (context, index) {
                            final book = filteredBooks[index];
                            final isSelected = _selectedBooks.contains(book);

                            return ListTile(
                              leading: Icon(
                                book.isDir ? Icons.folder : Icons.book,
                                color: book.isDir ? Colors.blue : Colors.orange,
                              ),
                              title: Text(book.filename),
                              subtitle: book.isDir
                                  ? const Text('文件夹')
                                  : Text(
                                      '${_formatSize(book.size)} • ${_formatDate(book.lastModify)}'),
                              trailing: book.isDir
                                  ? const Icon(Icons.chevron_right)
                                  : (book.isOnBookShelf
                                      ? const Icon(Icons.check,
                                          color: Colors.green)
                                      : null),
                              onTap: () {
                                if (book.isDir) {
                                  _enterDirectory(book);
                                } else {
                                  // 单个书籍添加到书架
                                  _addToBookshelf([book]);
                                }
                              },
                              onLongPress: () {
                                if (!book.isDir) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedBooks.remove(book);
                                    } else {
                                      _selectedBooks.add(book);
                                    }
                                  });
                                }
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }

  /// 格式化文件大小
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 格式化日期
  String _formatDate(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
