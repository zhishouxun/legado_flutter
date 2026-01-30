import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../data/models/bookmark.dart';
import '../../../services/bookmark_service.dart';
import '../../../services/book/book_service.dart';
import 'bookmark_dialog.dart';
import '../reader/reader_page.dart';

/// 所有书签页面
class AllBookmarkPage extends ConsumerStatefulWidget {
  const AllBookmarkPage({super.key});

  @override
  ConsumerState<AllBookmarkPage> createState() => _AllBookmarkPageState();
}

class _AllBookmarkPageState extends ConsumerState<AllBookmarkPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Bookmark> _bookmarks = [];
  List<Bookmark> _filteredBookmarks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Timer? _searchDebounceTimer; // 搜索防抖定时器
  
  // 按书籍分组的书签
  Map<String, List<Bookmark>> _groupedBookmarks = {};

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // 搜索防抖：延迟200ms后执行过滤
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _searchQuery = query;
          _filterBookmarks();
        });
      }
    });
  }

  void _filterBookmarks() {
    if (_searchQuery.isEmpty) {
      _filteredBookmarks = _bookmarks;
    } else {
      final queryLower = _searchQuery.toLowerCase();
      _filteredBookmarks = _bookmarks.where((bookmark) {
        return bookmark.bookName.toLowerCase().contains(queryLower) ||
            bookmark.bookAuthor.toLowerCase().contains(queryLower) ||
            bookmark.chapterName.toLowerCase().contains(queryLower) ||
            bookmark.bookText.toLowerCase().contains(queryLower) ||
            bookmark.content.toLowerCase().contains(queryLower);
      }).toList();
    }
    _updateGroupedBookmarks();
  }

  void _updateGroupedBookmarks() {
    final grouped = <String, List<Bookmark>>{};
    for (final bookmark in _filteredBookmarks) {
      final key = '${bookmark.bookName}|${bookmark.bookAuthor}';
      grouped.putIfAbsent(key, () => []).add(bookmark);
    }
    setState(() {
      _groupedBookmarks = grouped;
    });
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bookmarks = await BookmarkService.instance.getAllBookmarks();
      
      // 按书籍分组
      final grouped = <String, List<Bookmark>>{};
      for (final bookmark in bookmarks) {
        final key = '${bookmark.bookName}|${bookmark.bookAuthor}';
        grouped.putIfAbsent(key, () => []).add(bookmark);
      }
      
      if (mounted) {
        setState(() {
          _bookmarks = bookmarks;
          _filteredBookmarks = bookmarks;
          _isLoading = false;
        });
        _filterBookmarks();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载书签失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书签'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索书签...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ),
        actions: [
          if (_bookmarks.isNotEmpty) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export_json',
                  child: Row(
                    children: [
                      Icon(Icons.file_download, size: 20),
                      SizedBox(width: 8),
                      Text('导出JSON'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_md',
                  child: Row(
                    children: [
                      Icon(Icons.description, size: 20),
                      SizedBox(width: 8),
                      Text('导出Markdown'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 8),
                      Text('清空书签'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'export_json':
                    _exportBookmarksJson();
                    break;
                  case 'export_md':
                    _exportBookmarksMd();
                    break;
                  case 'clear':
                    _showClearDialog();
                    break;
                }
              },
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredBookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_off
                            : Icons.bookmark_border,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? '未找到匹配的书签'
                            : '暂无书签',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookmarks,
                  child: _buildGroupedBookmarksList(),
                ),
    );
  }

  /// 构建分组书签列表
  Widget _buildGroupedBookmarksList() {
    final items = <Widget>[];
    
    _groupedBookmarks.forEach((key, bookmarks) {
      // 添加分组标题
      final parts = key.split('|');
      final bookName = parts[0];
      final bookAuthor = parts.length > 1 ? parts[1] : '';
      
      items.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$bookName${bookAuthor.isNotEmpty ? ' ($bookAuthor)' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${bookmarks.length} 个书签',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
      
      // 添加该书籍的书签
      for (final bookmark in bookmarks) {
        items.add(
          ListTile(
            leading: const Icon(Icons.bookmark, color: Colors.orange),
            title: Text(bookmark.chapterName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bookmark.bookText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    bookmark.bookText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatTime(bookmark.time),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            onTap: () {
              // 显示编辑对话框
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => BookmarkDialog(
                  bookmark: bookmark,
                  isEdit: true,
                ),
              ).then((_) {
                _loadBookmarks();
              });
            },
            onLongPress: () async {
              // 跳转到书签位置
              await _jumpToBookmark(bookmark);
            },
          ),
        );
      }
    });
    
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  /// 跳转到书签位置
  Future<void> _jumpToBookmark(Bookmark bookmark) async {
    try {
      // 查找对应的书籍
      final books = await BookService.instance.getBookshelfBooks();
      final book = books.firstWhere(
        (b) => b.name == bookmark.bookName && b.author == bookmark.bookAuthor,
        orElse: () => books.first,
      );
      
      if (!mounted) return;
      
      // 跳转到阅读界面
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReaderPage(
            book: book,
            initialChapterIndex: bookmark.chapterIndex,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('跳转失败: $e')),
        );
      }
    }
  }

  /// 显示清空对话框
  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空书签'),
        content: const Text('确定要清空所有书签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await BookmarkService.instance.clearAllBookmarks();
              _loadBookmarks();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 导出书签为JSON
  Future<void> _exportBookmarksJson() async {
    try {
      final jsonString = jsonEncode(_bookmarks.map((b) => b.toMap()).toList());
      
      // 使用FilePicker保存文件
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出书签',
        fileName: 'bookmark-${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonString);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导出成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 导出书签为Markdown
  Future<void> _exportBookmarksMd() async {
    try {
      final buffer = StringBuffer();
      String? currentBookName;
      String? currentAuthor;
      
      for (final bookmark in _bookmarks) {
        // 如果书籍改变，添加新的标题
        if (bookmark.bookName != currentBookName || bookmark.bookAuthor != currentAuthor) {
          currentBookName = bookmark.bookName;
          currentAuthor = bookmark.bookAuthor;
          buffer.writeln('## $currentBookName $currentAuthor\n');
        }
        
        // 添加章节标题
        buffer.writeln('#### ${bookmark.chapterName}\n');
        
        // 添加原文
        if (bookmark.bookText.isNotEmpty) {
          buffer.writeln('###### 原文\n${bookmark.bookText}\n');
        }
        
        // 添加摘要
        if (bookmark.content.isNotEmpty) {
          buffer.writeln('###### 摘要\n${bookmark.content}\n');
        }
      }
      
      final mdString = buffer.toString();
      
      // 使用FilePicker保存文件
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出书签',
        fileName: 'bookmark-${DateTime.now().millisecondsSinceEpoch}.md',
        type: FileType.custom,
        allowedExtensions: ['md'],
      );
      
      if (result != null) {
        final file = File(result);
        await file.writeAsString(mdString);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导出成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

