import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/book.dart';
import '../../data/models/book_source.dart';
import '../../services/book/book_service.dart';
import '../../services/source/book_source_service.dart';
import '../../utils/app_log.dart';
import '../../utils/network_utils.dart';
import '../pages/bookshelf/book_info/book_info_page.dart';

/// 添加到书架对话框
/// 参考项目：io.legado.app.ui.association.AddToBookshelfDialog
class AddToBookshelfDialog extends ConsumerStatefulWidget {
  final String bookUrl;
  final bool finishOnDismiss;

  const AddToBookshelfDialog({
    super.key,
    required this.bookUrl,
    this.finishOnDismiss = false,
  });

  @override
  ConsumerState<AddToBookshelfDialog> createState() =>
      _AddToBookshelfDialogState();
}

class _AddToBookshelfDialogState extends ConsumerState<AddToBookshelfDialog> {
  bool _isLoading = false;
  String? _errorMessage;
  Book? _book;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  /// 加载书籍信息
  /// 参考项目：AddToBookshelfDialog.ViewModel.load()
  Future<void> _loadBook() async {
    if (widget.bookUrl.isEmpty) {
      setState(() {
        _errorMessage = 'URL不能为空';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 检查书籍是否已在书架
      final existingBook =
          await BookService.instance.getBookByUrl(widget.bookUrl);
      if (existingBook != null) {
        setState(() {
          _errorMessage = '${existingBook.name} 已在书架';
          _isLoading = false;
        });
        return;
      }

      // 获取baseUrl
      final baseUrl = NetworkUtils.getBaseUrl(widget.bookUrl);
      if (baseUrl == null || baseUrl.isEmpty) {
        setState(() {
          _errorMessage = '书籍地址格式不对';
          _isLoading = false;
        });
        return;
      }

      // 尝试匹配书源
      BookSource? source;

      // 1. 尝试从URL参数中获取书源（UrlOption）
      // 格式：${origin}/${path}?{origin: bookSourceUrl}
      // 注意：Flutter中URL参数解析方式不同，这里简化处理
      final uri = Uri.tryParse(widget.bookUrl);
      if (uri != null && uri.hasQuery) {
        final origin = uri.queryParameters['origin'];
        if (origin != null && origin.isNotEmpty) {
          source = await BookSourceService.instance.getBookSourceByUrl(origin);
        }
      }

      // 2. 在所有启用的书源中匹配origin
      source ??= await BookSourceService.instance.getBookSourceByUrl(baseUrl);

      // 3. 在所有启用的书源中使用bookUrlPattern匹配
      if (source == null) {
        final allSources = await BookSourceService.instance
            .getAllBookSources(enabledOnly: true);
        for (final s in allSources) {
          if (s.bookUrlPattern != null && s.bookUrlPattern!.isNotEmpty) {
            try {
              final pattern = RegExp(s.bookUrlPattern!);
              if (pattern.hasMatch(widget.bookUrl)) {
                source = s;
                break;
              }
            } catch (e) {
              // 正则表达式错误，跳过
              continue;
            }
          }
        }
      }

      if (source == null) {
        setState(() {
          _errorMessage = '未找到匹配书源';
          _isLoading = false;
        });
        return;
      }

      // 创建书籍对象
      final book = Book(
        bookUrl: widget.bookUrl,
        origin: source.bookSourceUrl,
        originName: source.bookSourceName,
        canUpdate: true,
      );

      // 获取书籍信息
      final bookInfo = await BookService.instance.getBookInfo(book);
      if (bookInfo == null) {
        setState(() {
          _errorMessage = '获取书籍信息失败';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _book = bookInfo;
        _isLoading = false;
      });

      // 保存到搜索书籍表（参考项目：saveSearchBook）
      // 注意：Flutter项目中可能没有searchBook表，这里直接导航到书籍详情页
      // 用户可以在详情页选择添加到书架
      _navigateToBookInfo(bookInfo);
    } catch (e) {
      AppLog.instance.put('添加书籍 ${widget.bookUrl} 出错', error: e);
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 导航到书籍详情页
  void _navigateToBookInfo(Book book) {
    Navigator.of(context).pop(); // 关闭对话框

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookInfoPage(
          bookUrl: book.bookUrl,
          bookName: book.name,
          author: book.author,
          sourceUrl: book.origin,
          coverUrl: book.coverUrl,
          intro: book.intro,
        ),
      ),
    );

    if (widget.finishOnDismiss && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '添加到书架',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在加载书籍信息...'),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              )
            else if (_book != null)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '书名：${_book!.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_book!.author.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('作者：${_book!.author}'),
                    ),
                  if (_book!.originName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('来源：${_book!.originName}'),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (widget.finishOnDismiss &&
                        Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
