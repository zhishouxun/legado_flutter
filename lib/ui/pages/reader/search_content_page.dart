import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/book.dart';
import '../../../services/book/book_service.dart';
import '../../../services/book/local_book_service.dart';
import '../../../services/source/book_source_service.dart';
import '../../../services/reader/content_processor.dart';

/// 内容搜索结果
class ContentSearchResult {
  final int chapterIndex;
  final String chapterTitle;
  final int position; // 在章节中的位置
  final String preview; // 预览文本

  ContentSearchResult({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.position,
    required this.preview,
  });
}

/// 内容搜索页面
class SearchContentPage extends StatefulWidget {
  final Book book;
  final Function(int chapterIndex, int position, String keyword)?
      onResultSelected;

  const SearchContentPage({
    super.key,
    required this.book,
    this.onResultSelected,
  });

  @override
  State<SearchContentPage> createState() => _SearchContentPageState();
}

class _SearchContentPageState extends State<SearchContentPage> {
  final TextEditingController _searchController = TextEditingController();
  List<ContentSearchResult> _results = [];
  bool _isSearching = false;
  int _currentResultIndex = -1;
  bool _replaceEnabled = true; // 替换规则开关
  Timer? _searchDebounceTimer; // 搜索防抖定时器
  int _searchStartChapter = 0; // 搜索起始章节（用于限制搜索范围）
  int _searchEndChapter = -1; // 搜索结束章节（-1表示搜索所有章节）

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _currentResultIndex = -1;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _results = [];
      _currentResultIndex = -1;
    });

    try {
      // 获取章节列表
      final chapters = await BookService.instance.getChapterList(widget.book);
      final results = <ContentSearchResult>[];

      // 确定搜索范围
      final startIndex = _searchStartChapter.clamp(0, chapters.length);
      final endIndex = _searchEndChapter < 0
          ? chapters.length
          : _searchEndChapter.clamp(0, chapters.length);

      // 搜索每个章节（在指定范围内）
      for (int i = startIndex; i < endIndex; i++) {
        final chapter = chapters[i];

        try {
          // 获取章节内容
          String? rawContent;
          if (widget.book.isLocal) {
            // 本地书籍使用 LocalBookService
            rawContent = await LocalBookService.instance.getChapterContent(
              chapter,
              widget.book,
            );
          } else {
            final source = await BookSourceService.instance
                .getBookSourceByUrl(widget.book.origin);
            if (source != null) {
              rawContent = await BookService.instance.getChapterContent(
                chapter,
                source,
                bookName: widget.book.name,
                bookOrigin: widget.book.origin,
                book: widget.book, // 传入 book 参数，启用缓存优化
              );
            }
          }

          if (rawContent == null || rawContent.isEmpty) continue;

          // 使用ContentProcessor处理内容（根据_replaceEnabled决定是否应用替换规则）
          final processor = ContentProcessor.get(widget.book);
          final processed = await processor.getContent(
            widget.book,
            chapter,
            rawContent,
            useReplace: _replaceEnabled,
            includeTitle: false,
          );
          final content = processed.contents.join('\n');

          // 搜索关键词
          final keywordLower = keyword.toLowerCase();
          final contentLower = content.toLowerCase();
          int startIndex = 0;

          while (true) {
            final index = contentLower.indexOf(keywordLower, startIndex);
            if (index == -1) break;

            // 获取预览文本（前后各50个字符）
            final previewStart = (index - 50).clamp(0, content.length);
            final previewEnd =
                (index + keyword.length + 50).clamp(0, content.length);
            final preview = content.substring(previewStart, previewEnd);

            results.add(ContentSearchResult(
              chapterIndex: i,
              chapterTitle: chapter.title,
              position: index,
              preview: preview,
            ));

            startIndex = index + 1;
          }
        } catch (e) {
          // 忽略单个章节的错误，继续搜索其他章节
        }
      }

      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  void _jumpToResult(ContentSearchResult result) {
    if (widget.onResultSelected != null) {
      widget.onResultSelected!(
        result.chapterIndex,
        result.position,
        _searchController.text,
      );
      Navigator.of(context).pop();
    }
  }

  void _jumpToNext() {
    if (_results.isEmpty) return;

    setState(() {
      _currentResultIndex = (_currentResultIndex + 1) % _results.length;
    });

    _jumpToResult(_results[_currentResultIndex]);
  }

  void _jumpToPrevious() {
    if (_results.isEmpty) return;

    setState(() {
      _currentResultIndex = _currentResultIndex <= 0
          ? _results.length - 1
          : _currentResultIndex - 1;
    });

    _jumpToResult(_results[_currentResultIndex]);
  }

  /// 显示搜索范围设置对话框
  Future<void> _showSearchRangeDialog() async {
    // 获取章节总数
    final chapters = await BookService.instance.getChapterList(widget.book);
    final totalChapters = chapters.length;

    if (totalChapters == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无章节')),
      );
      return;
    }

    final startController = TextEditingController(
      text: (_searchStartChapter + 1).toString(),
    );
    final endController = TextEditingController(
      text: _searchEndChapter < 0
          ? totalChapters.toString()
          : (_searchEndChapter + 1).toString(),
    );

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置搜索范围'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '共 $totalChapters 章',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startController,
                    decoration: const InputDecoration(
                      labelText: '起始章节',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('至'),
                ),
                Expanded(
                  child: TextField(
                    controller: endController,
                    decoration: const InputDecoration(
                      labelText: '结束章节',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                startController.text = '1';
                endController.text = totalChapters.toString();
              },
              child: const Text('重置为全部章节'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final start = int.tryParse(startController.text);
              final end = int.tryParse(endController.text);

              if (start == null || end == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入有效的章节号')),
                );
                return;
              }

              if (start < 1 ||
                  start > totalChapters ||
                  end < 1 ||
                  end > totalChapters ||
                  start > end) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('章节号必须在 1-$totalChapters 之间，且起始章节不能大于结束章节')),
                );
                return;
              }

              Navigator.of(context).pop({
                'start': start - 1, // 转换为索引（从0开始）
                'end': end, // 结束章节（包含）
              });
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _searchStartChapter = result['start']!;
        _searchEndChapter = result['end']!;
      });

      // 如果有搜索关键词，重新搜索
      if (_searchController.text.trim().isNotEmpty) {
        _search(_searchController.text.trim());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容搜索'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '输入搜索关键词',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _search('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: _search,
                    onChanged: (value) {
                      setState(() {});
                      // 搜索防抖：延迟500ms后自动搜索（内容搜索需要更多时间）
                      _searchDebounceTimer?.cancel();
                      if (value.isEmpty) {
                        _search('');
                      } else {
                        _searchDebounceTimer =
                            Timer(const Duration(milliseconds: 500), () {
                          if (mounted &&
                              _searchController.text.trim() == value.trim()) {
                            _search(value.trim());
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_searchController.text),
                  tooltip: '搜索',
                ),
              ],
            ),
          ),
        ),
        actions: [
          // 替换规则开关和搜索范围设置
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_replace',
                child: Row(
                  children: [
                    Icon(
                      _replaceEnabled
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('启用替换规则'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'search_range',
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 20),
                    const SizedBox(width: 8),
                    Text(_searchEndChapter < 0
                        ? '搜索范围：全部章节'
                        : '搜索范围：第${_searchStartChapter + 1}-$_searchEndChapter章'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'toggle_replace') {
                setState(() {
                  _replaceEnabled = !_replaceEnabled;
                });
                // 重新搜索以应用新的替换规则设置
                if (_searchController.text.trim().isNotEmpty) {
                  _search(_searchController.text.trim());
                }
              } else if (value == 'search_range') {
                _showSearchRangeDialog();
              }
            },
          ),
          if (_results.isNotEmpty)
            Row(
              children: [
                Text('${_currentResultIndex + 1}/${_results.length}'),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: _jumpToPrevious,
                  tooltip: '上一个',
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: _jumpToNext,
                  tooltip: '下一个',
                ),
              ],
            ),
        ],
      ),
      body: _isSearching
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在搜索...'),
                ],
              ),
            )
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty ? '请输入搜索关键词' : '未找到相关内容',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    final isSelected = index == _currentResultIndex;
                    final keyword = _searchController.text;

                    return ListTile(
                      selected: isSelected,
                      title: Text(
                        result.chapterTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : null,
                        ),
                      ),
                      subtitle: _buildPreviewText(result.preview, keyword),
                      onTap: () {
                        setState(() {
                          _currentResultIndex = index;
                        });
                        _jumpToResult(result);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildPreviewText(String preview, String keyword) {
    if (keyword.isEmpty) {
      return Text(preview);
    }

    final keywordLower = keyword.toLowerCase();
    final previewLower = preview.toLowerCase();
    final index = previewLower.indexOf(keywordLower);

    if (index == -1) {
      return Text(preview);
    }

    // 高亮显示关键词
    final before = preview.substring(0, index);
    final match = preview.substring(index, index + keyword.length);
    final after = preview.substring(index + keyword.length);

    return RichText(
      text: TextSpan(
        style: TextStyle(color: Colors.grey[700]),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              backgroundColor: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
