import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book_source.dart';
import '../../../data/models/book.dart';
import '../../../services/explore_service.dart';
import '../../../services/network/network_service.dart';
import '../../widgets/book/book_card.dart';
import '../bookshelf/book_info/book_info_page.dart';

/// 发现分类书籍列表页面
class ExploreShowPage extends ConsumerStatefulWidget {
  final BookSource bookSource;
  final String exploreName;
  final String exploreUrl;

  const ExploreShowPage({
    super.key,
    required this.bookSource,
    required this.exploreName,
    required this.exploreUrl,
  });

  @override
  ConsumerState<ExploreShowPage> createState() => _ExploreShowPageState();
}

class _ExploreShowPageState extends ConsumerState<ExploreShowPage> {
  List<Map<String, String?>> _books = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  bool _isLoadingMore = false; // 用于防止重复加载

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks({bool loadMore = false}) async {
    if (_isLoading) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (!loadMore) {
        _page = 1;
        _books = [];
      }
    });

    try {
      final books = await ExploreService.instance.exploreBooks(
        widget.bookSource,
        widget.exploreUrl,
        page: _page,
      );

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _books.addAll(books);
        } else {
          _books = books;
        }
        _hasMore = books.isNotEmpty;
        _page++;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    _isLoadingMore = true;
    await _loadBooks(loadMore: true);
    _isLoadingMore = false;
  }

  Future<void> _showBookInfo(Map<String, String?> bookData) async {
    final nameRaw = bookData['name'] ?? '';
    final authorRaw = bookData['author'] ?? '';
    var bookUrl = bookData['bookUrl'] ?? '';
    final coverUrlRaw = bookData['coverUrl'];
    final introRaw = bookData['intro'] ?? '';
    
    // 处理数据，确保与itemBuilder中的处理一致
    final name = nameRaw.trim().isNotEmpty ? nameRaw.trim() : '未知书籍';
    var author = authorRaw.trim();
    if (author.startsWith('作者：') || author.startsWith('作者:')) {
      author = author.replaceFirst(RegExp(r'^作者[：:]'), '').trim();
    }
    final finalAuthor = author.isNotEmpty ? author : '未知作者';
    
    // 处理封面URL（参考项目：使用baseUrl拼接相对路径）
    String? coverUrl;
    if (coverUrlRaw != null && coverUrlRaw.isNotEmpty) {
      coverUrl = NetworkService.joinUrl(
        widget.bookSource.bookSourceUrl,
        coverUrlRaw,
      );
    }
    
    // 处理简介
    final intro = introRaw.trim().replaceAll(RegExp(r'\s+'), ' ');

    // 参考项目逻辑：处理bookUrl
    // 1. 如果bookUrl为空，尝试从其他字段构建
    // 2. 如果bookUrl是相对路径，使用baseUrl拼接成绝对URL
    // 3. 如果bookUrl看起来是分类列表页（包含/sort/），可能需要特殊处理
    
    if (bookUrl.isEmpty) {
      // 如果bookUrl为空，尝试从封面URL或其他信息推断
      // 注意：这是兜底逻辑，大多数情况下bookUrl应该由规则解析得到
      if (coverUrl != null && coverUrl.isNotEmpty) {
        // 尝试从封面URL中提取书籍ID（仅作为最后手段）
        // 这个逻辑应该根据具体书源的URL结构来调整
        final coverUrlPattern = RegExp(r'/files/article/image/(\d+)/(\d+)/');
        final match = coverUrlPattern.firstMatch(coverUrl);
        if (match != null) {
          final bookId = '${match.group(1)}_${match.group(2)}';
          try {
            final sourceUri = Uri.parse(widget.bookSource.bookSourceUrl);
            String host = sourceUri.host;
            // 某些网站可能需要使用移动版域名
            if (host.startsWith('www.')) {
              host = 'm.${host.substring(4)}';
            }
            bookUrl = '${sourceUri.scheme}://$host/$bookId/';
          } catch (e) {
            // 如果解析失败，bookUrl仍然为空
          }
        }
        }
      } else {
      // 参考项目：如果bookUrl是相对路径，使用baseUrl拼接
      // baseUrl应该是发现页面的URL或书源的基础URL
      // 注意：如果bookUrl已经是绝对URL，joinUrl会直接返回
      bookUrl = NetworkService.joinUrl(
        widget.bookSource.bookSourceUrl,
        bookUrl,
      );
    }

    // 如果bookUrl仍然为空，无法打开书籍详情
    if (bookUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书籍URL为空，无法打开详情')),
        );
      }
      return;
    }

    if (mounted) {
      // 跳转到书籍详情页面
      // 参考项目：直接传递bookUrl、bookName、author等信息
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BookInfoPage(
            key: ValueKey('book_info_$bookUrl'),
            bookUrl: bookUrl,
            bookName: name.isNotEmpty ? name : null,
            author: finalAuthor.isNotEmpty ? finalAuthor : null,
            sourceUrl: widget.bookSource.bookSourceUrl,
            coverUrl: coverUrl,
            intro: intro.isNotEmpty ? intro : null,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exploreName),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadBooks(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : _books.isEmpty && !_isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无书籍',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadBooks(),
                  child: ListView.builder(
                    itemCount: _books.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _books.length) {
                        // 加载更多
                        if (_hasMore) {
                          // 使用 Future.microtask 延迟执行，避免在 build 期间调用 setState
                          Future.microtask(() {
                            if (mounted) {
                              _loadMore();
                            }
                          });
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }

                      final bookData = _books[index];
                      // 处理空格问题：trim() 并检查是否为空
                      final nameRaw = bookData['name'] ?? '';
                      final authorRaw = bookData['author'] ?? '';
                      final name = nameRaw.trim().isNotEmpty ? nameRaw.trim() : '未知书籍';
                      // 处理作者重复问题：如果 author 已经包含"作者："，则移除
                      var author = authorRaw.trim();
                      if (author.startsWith('作者：') || author.startsWith('作者:')) {
                        author = author.replaceFirst(RegExp(r'^作者[：:]'), '').trim();
                      }
                      author = author.isNotEmpty ? author : '未知作者';
                      final coverUrl = bookData['coverUrl'];
                      // 处理简介空格问题
                      final introRaw = bookData['intro'] ?? '';
                      final intro = introRaw.trim().replaceAll(RegExp(r'\s+'), ' ');
                      final kind = bookData['kind'] ?? '';
                      final wordCount = bookData['wordCount'] ?? '';
                      final lastChapter = bookData['lastChapter'] ?? '';
                      final bookUrl = bookData['bookUrl'] ?? '';

                      // 构建完整的封面URL
                      String? fullCoverUrl;
                      if (coverUrl != null && coverUrl.isNotEmpty) {
                        fullCoverUrl = NetworkService.joinUrl(
                          widget.bookSource.bookSourceUrl,
                          coverUrl,
                        );
                      }

                      // 创建临时 Book 对象用于显示
                      final book = Book(
                        bookUrl: bookUrl,
                        name: name,
                        author: author,
                        origin: widget.bookSource.bookSourceUrl,
                        originName: widget.bookSource.bookSourceName,
                        coverUrl: fullCoverUrl ?? '',
                        intro: intro,
                        kind: kind,
                        wordCount: wordCount,
                        latestChapterTitle: lastChapter,
                        canUpdate: true,
                      );

                      return BookCard(
                        book: book,
                        isSearchResult: true,
                        onTap: () => _showBookInfo(bookData),
                      );
                    },
                  ),
                ),
    );
  }
}

