import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/read_record.dart';
import '../../../services/read_record_service.dart';
import '../../../services/book/book_service.dart';
import '../reader/reader_page.dart';

/// 阅读记录页面
class ReadRecordPage extends ConsumerStatefulWidget {
  const ReadRecordPage({super.key});

  @override
  ConsumerState<ReadRecordPage> createState() => _ReadRecordPageState();
}

class _ReadRecordPageState extends ConsumerState<ReadRecordPage> {
  List<ReadRecordShow> _records = [];
  bool _isLoading = true;
  int _sortMode = 0; // 0: 按书名, 1: 按阅读时长, 2: 按最后阅读时间
  int _allTime = 0; // 总阅读时长（毫秒）
  String _searchKey = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllTime();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTime() async {
    try {
      final allTime = await ReadRecordService.instance.getAllTime();
      if (mounted) {
        setState(() {
          _allTime = allTime;
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }

  Future<void> _loadRecords({String? searchKey}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 从ReadRecordService获取阅读记录
      final records = searchKey != null && searchKey.isNotEmpty
          ? await ReadRecordService.instance.search(searchKey)
          : await ReadRecordService.instance.getAllShow();

      // 排序
      records.sort((a, b) {
        switch (_sortMode) {
          case 1: // 按阅读时长
            return b.readTime.compareTo(a.readTime);
          case 2: // 按最后阅读时间
            return b.lastRead.compareTo(a.lastRead);
          default: // 按书名
            return a.bookName.compareTo(b.bookName);
        }
      });

      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载阅读记录失败: $e')),
        );
      }
    }
  }

  Future<void> _clearAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除所有阅读记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ReadRecordService.instance.clear();
        if (mounted) {
          _loadAllTime();
          _loadRecords();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已清除所有阅读记录')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _records.isEmpty ? null : _clearAllRecords,
            tooltip: '清除所有记录',
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortMode = value;
              });
              _loadRecords(searchKey: _searchKey.isEmpty ? null : _searchKey);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    Icon(_sortMode == 0 ? Icons.check : null),
                    const SizedBox(width: 8),
                    const Text('按书名'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    Icon(_sortMode == 1 ? Icons.check : null),
                    const SizedBox(width: 8),
                    const Text('按阅读时长'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(_sortMode == 2 ? Icons.check : null),
                    const SizedBox(width: 8),
                    const Text('按最后阅读时间'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // 总阅读时长
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('总阅读时长: '),
                    Text(
                      _formatDuration(_allTime),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 搜索框
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索书名',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchKey.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchKey = '';
                              });
                              _loadRecords();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchKey = value;
                    });
                    _loadRecords(searchKey: value.isEmpty ? null : value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('暂无阅读记录', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecords,
                  child: ListView.builder(
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return ListTile(
                        leading: const Icon(Icons.book, color: Colors.blue),
                        title: Text(record.bookName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('阅读时长: ${_formatDuration(record.readTime)}'),
                            Text('最后阅读: ${_formatTime(record.lastRead)}'),
                          ],
                        ),
                        onTap: () async {
                          // 跳转到书籍
                          try {
                            final books = await BookService.instance.getBookshelfBooks();
                            final book = books.firstWhere(
                              (b) => b.name == record.bookName,
                              orElse: () => books.first,
                            );
                            
                            if (mounted) {
                              // 导航到阅读页面
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ReaderPage(
                                    book: book,
                                    initialChapterIndex: book.durChapterIndex,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('未找到书籍: ${record.bookName}')),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;

    if (hours > 0) {
      return '$hours小时${minutes % 60}分钟';
    } else if (minutes > 0) {
      return '$minutes分钟';
    } else {
      return '$seconds秒';
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
