import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../../reader/reader_page.dart';
import '../../reader/manga_reader_page.dart';
import '../../reader/chapter_list_page.dart';
import '../../../../data/models/book.dart';
import '../../../../data/models/book_chapter.dart';
import '../../../../data/models/book_source.dart';
import '../../../../services/book/book_service.dart';
import '../../../../services/source/book_source_service.dart';
import '../../../../services/book_group_service.dart';
import '../../../../data/models/book_group.dart';
import '../../../../providers/book_provider.dart';
import '../../../../utils/app_log.dart';
import 'book_info_header.dart';
import 'book_info_actions.dart';
import 'book_info_menu.dart';
import 'book_info_intro.dart';
import 'change_source_dialog.dart';
import 'change_cover_dialog.dart';
import 'book_info_edit_page.dart';
import '../../audio/audio_play_page.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

/// 书籍详情页面
class BookInfoPage extends ConsumerStatefulWidget {
  final String bookUrl;
  final String? bookName;
  final String? author;
  final String? sourceUrl;
  final String? coverUrl;
  final String? intro;

  const BookInfoPage({
    super.key,
    required this.bookUrl,
    this.bookName,
    this.author,
    this.sourceUrl,
    this.coverUrl,
    this.intro,
  });

  @override
  ConsumerState<BookInfoPage> createState() => _BookInfoPageState();
}

class _BookInfoPageState extends ConsumerState<BookInfoPage> {
  Book? _book;
  bool _isLoading = true;
  bool _isInBookshelf = false;
  String? _error; // 书籍信息加载错误
  String? _chapterError; // 章节列表加载错误（分离处理）
  List<BookChapter>? _chapters; // 保存章节列表用于显示
  bool _isLoadingChapters = false; // 章节加载状态

  @override
  void initState() {
    super.initState();
    // 重置状态，确保每次打开页面都是全新的状态
    _book = null;
    _isInBookshelf = false;
    _error = null;
    _isLoading = true;
    _loadBook();
  }

  @override
  void didUpdateWidget(BookInfoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果参数发生变化，重新加载书籍数据
    if (oldWidget.bookUrl != widget.bookUrl ||
        oldWidget.bookName != widget.bookName ||
        oldWidget.author != widget.author ||
        oldWidget.sourceUrl != widget.sourceUrl ||
        oldWidget.coverUrl != widget.coverUrl ||
        oldWidget.intro != widget.intro) {
      // 重置状态
      _book = null;
      _isInBookshelf = false;
      _error = null;
      _isLoading = true;
      // 重新加载
      _loadBook();
    }
  }

  Future<void> _loadBook() async {
    // 输出调试信息

    // 先重置状态，确保不会显示旧数据
    setState(() {
      _book = null;
      _isLoading = true;
      _error = null;
      _isInBookshelf = false;
    });

    try {
      Book? book;
      bool isInShelf = false;

      // 参考项目逻辑：如果提供了 bookName 和 author，优先通过这两个字段查找
      // 因为 bookUrl 可能是分类页面 URL，不是唯一的书籍标识符
      if (widget.bookName != null && widget.author != null) {
        book = await BookService.instance.getBookByNameAndAuthor(
          widget.bookName!,
          widget.author!,
        );
        if (book != null) {
          // 验证 bookUrl 是否匹配（如果 bookUrl 是有效的书籍详情页 URL）
          // 如果 bookUrl 看起来像分类页面 URL（包含 /sort/），则不验证
          bool urlMatches = widget.bookUrl.isEmpty ||
              widget.bookUrl.contains('/sort/') ||
              book.bookUrl == widget.bookUrl;

          if (urlMatches) {
            isInShelf = true;
          } else {
            book = null; // 重置，继续查找
          }
        }
      }

      // 如果通过名称和作者没找到，尝试通过 bookUrl 查找
      // 但需要验证名称和作者是否匹配
      if (book == null) {
        book = await BookService.instance.getBookByUrl(widget.bookUrl);
        if (book != null) {
          // 验证书籍名称和作者是否匹配（防止 bookUrl 是分类页面 URL 的情况）
          bool nameMatches =
              widget.bookName == null || book.name == widget.bookName;
          bool authorMatches = widget.author == null ||
              book.author == widget.author ||
              book.author.replaceAll('作者：', '').replaceAll('作者:', '').trim() ==
                  widget.author;

          if (nameMatches && authorMatches) {
            isInShelf = true;
          } else {
            book = null; // 重置，继续查找或创建临时对象
          }
        }
      }

      // 如果通过 bookUrl 没找到，且提供了 bookName 和 sourceUrl，直接创建临时 Book 对象
      // 注意：不通过名称和作者查找，因为可能找到同名但不同 bookUrl 的书籍
      if (book == null && widget.bookName != null && widget.sourceUrl != null) {
        // 获取书源信息
        final source = await BookSourceService.instance
            .getBookSourceByUrl(widget.sourceUrl!);
        if (source != null) {
          // 创建临时 Book 对象，用于显示书籍详情
          // 确保使用最新的 widget 参数
          book = Book(
            bookUrl: widget.bookUrl,
            name: widget.bookName!,
            author: widget.author ?? '',
            origin: widget.sourceUrl!,
            originName: source.bookSourceName,
            coverUrl: widget.coverUrl,
            intro: widget.intro,
            canUpdate: true,
          );

          // 如果书籍不在书架，需要加载书籍详情和章节列表
          if (!isInShelf) {
            try {
              // 确保使用最新的 book 对象（包含正确的 bookUrl）
              final bookInfo = await BookService.instance.getBookInfo(book);
              if (bookInfo != null) {
                book = bookInfo;
                // 尝试加载章节列表（但不保存到数据库）
                try {
                  setState(() {
                    _isLoadingChapters = true;
                  });
                  final chapters = await BookService.instance
                      .getChapterListWithoutSave(book);

                  // 如果有章节，更新书籍的章节信息用于显示
                  if (chapters.isNotEmpty) {
                    book = book.copyWith(
                      totalChapterNum: chapters.length,
                      durChapterTitle: chapters[0].title,
                    );
                  } else {
                    // 记录警告：章节列表为空
                    AppLog.instance.put(
                        'BookInfoPage: 章节列表为空 - bookUrl=${book.bookUrl}, tocUrl=${book.tocUrl}, origin=${book.origin}');
                  }

                  if (mounted) {
                    setState(() {
                      _chapters = chapters;
                      _isLoadingChapters = false;
                      _book = book; // 更新书籍对象，确保章节信息被保存
                      // 如果章节列表为空，设置章节错误信息（不影响详情页显示）
                      if (chapters.isEmpty) {
                        _chapterError = '解析目录失败：未找到章节列表';
                      }
                    });
                  }
                } catch (e, stackTrace) {
                  // 章节列表加载失败，记录错误但不影响详情页显示
                  AppLog.instance.put('BookInfoPage: 章节列表加载失败', error: e);
                  AppLog.instance.put('错误堆栈: $stackTrace');
                  if (mounted) {
                    setState(() {
                      _chapters = [];
                      _isLoadingChapters = false;
                      // 使用章节错误字段，不影响整个页面
                      _chapterError = '解析目录失败: ${e.toString()}';
                    });
                  }
                }
              } else {
                AppLog.instance.put(
                    'BookInfoPage: 获取书籍详情返回null - bookUrl=${book.bookUrl}, origin=${book.origin}');
              }
            } catch (e, stackTrace) {
              // 获取详情失败，记录错误并继续使用基本信息
              AppLog.instance.put('BookInfoPage: 获取书籍详情失败', error: e);
              AppLog.instance.put('错误堆栈: $stackTrace');
              if (mounted) {
                setState(() {
                  _error = '获取书籍详情失败: ${e.toString()}';
                });
              }
            }
          }
        } else {}
      }

      if (book == null) {
        throw Exception('未找到书籍');
      }

      // 再次检查 widget 参数是否变化（防止异步操作期间参数已变化）
      if (widget.bookUrl != book.bookUrl) {
        // 如果参数已变化，重新加载
        if (mounted) {
          _loadBook();
        }
        return;
      }

      if (mounted) {
        setState(() {
          _book = book;
          _isInBookshelf = isInShelf;
          _isLoading = false;
        });

        // 如果书籍在书架，也加载章节列表用于显示
        if (isInShelf) {
          _loadChaptersForDisplay();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshBook() async {
    if (_book == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 更新书籍信息
      final updatedBook = await BookService.instance.getBookInfo(_book!);
      if (updatedBook != null) {
        setState(() {
          _book = updatedBook;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addToBookshelf() async {
    if (_book == null) return;

    try {
      // 如果书籍不是本地书籍，需要先获取章节列表
      if (!_book!.isLocal) {
        try {
          final chapters = await BookService.instance.getChapterList(_book!);
          if (chapters.isNotEmpty) {
            await BookService.instance.saveChapters(chapters);
          }
        } catch (e) {
          // 章节列表获取失败不影响添加书籍
        }
      }

      // 保存书籍
      await BookService.instance.createBook(_book!);

      // 刷新书架 Provider
      ref.invalidate(refreshBookshelfProvider);
      ref.invalidate(bookshelfBooksProvider);

      // 刷新所有分组的书籍列表
      final groupsAsync = ref.read(bookGroupsProvider);
      final groups = groupsAsync.value ?? [];
      for (final group in groups) {
        ref.invalidate(booksByGroupProvider(group.groupId));
      }

      setState(() {
        _isInBookshelf = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到书架')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  Future<void> _removeFromBookshelf() async {
    if (_book == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除书籍'),
        content: Text('确定要从书架移除 "${_book!.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BookService.instance.deleteBook(_book!.bookUrl);

        // 刷新书架 Provider
        ref.invalidate(refreshBookshelfProvider);
        ref.invalidate(bookshelfBooksProvider);

        // 刷新所有分组的书籍列表
        final groupsAsync = ref.read(bookGroupsProvider);
        final groups = groupsAsync.value ?? [];
        for (final group in groups) {
          ref.invalidate(booksByGroupProvider(group.groupId));
        }

        if (mounted) {
          Navigator.of(context).pop(true); // 返回并通知刷新
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('移除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditPage() async {
    if (_book == null) return;

    final result = await Navigator.of(context).push<Book>(
      MaterialPageRoute(
        builder: (context) => BookInfoEditPage(book: _book!),
      ),
    );

    if (result != null) {
      setState(() {
        _book = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    }
  }

  Future<void> _shareBook() async {
    if (_book == null) return;

    try {
      // 将书籍信息转换为JSON
      final bookJson = jsonEncode(_book!.toJson());
      // 分享格式：bookUrl#json
      final shareText = '${_book!.bookUrl}#$bookJson';

      await Share.share(
        shareText,
        subject: _book!.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  /// 加载章节列表用于显示（不阻塞UI）
  Future<void> _loadChaptersForDisplay() async {
    if (_book == null) return;

    try {
      final chapters = await BookService.instance.getChapterList(_book!);
      if (mounted) {
        setState(() {
          _chapters = chapters;
        });
      }
    } catch (e) {
      // 加载失败不影响显示
    }
  }

  Future<void> _openChapterList() async {
    if (_book == null) return;

    try {
      List<BookChapter> chapters;

      // 如果已经有缓存的章节列表（不在书架时）且没有错误，直接使用
      if (!_isInBookshelf && 
          _chapters != null && 
          _chapters!.isNotEmpty && 
          _chapterError == null) {
        chapters = _chapters!;
      } else {
        // 显示加载状态
        if (mounted) {
          setState(() {
            _isLoadingChapters = true;
            _chapterError = null;
          });
        }
        
        // 加载章节列表
        // 如果书籍不在书架，使用不保存到数据库的方法
        chapters = _isInBookshelf
            ? await BookService.instance.getChapterList(_book!)
            : await BookService.instance.getChapterListWithoutSave(_book!);

        // 更新缓存的章节列表
        if (mounted) {
          setState(() {
            _chapters = chapters;
            _isLoadingChapters = false;
            _chapterError = chapters.isEmpty ? '未找到章节' : null;
          });
        }
      }

      if (!mounted) return;

      // 确保当前章节索引在有效范围内
      final currentIndex = _book!.durChapterIndex >= 0 &&
              _book!.durChapterIndex < chapters.length
          ? _book!.durChapterIndex
          : (chapters.isNotEmpty ? 0 : -1);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChapterListPage(
            chapters: chapters,
            currentChapterIndex: currentIndex,
            onChapterSelected: (chapterIndex) {
              Navigator.of(context).pop();
              _startReading(chapterIndex: chapterIndex);
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载章节列表失败: $e')),
        );
      }
    }
  }

  void _startReading({int? chapterIndex}) {
    if (_book == null) return;

    // 根据书籍类型跳转到不同的页面
    if (_book!.type == BookType.audio) {
      // 音频书籍：跳转到音频播放页面
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => AudioPlayPage(
            book: _book!,
          ),
        ),
      )
          .then((_) {
        // 播放返回后刷新书籍信息
        _loadBook();
      });
    } else if (_book!.type == BookType.image) {
      // 漫画书籍：跳转到漫画阅读页面
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => MangaReaderPage(
            book: _book!,
            initialChapterIndex: chapterIndex ?? 0,
          ),
        ),
      )
          .then((_) {
        // 阅读返回后刷新书籍信息
        _loadBook();
      });
    } else {
      // 文本书籍：跳转到阅读页面
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => ReaderPage(
            book: _book!,
            initialChapterIndex: chapterIndex ?? 0,
          ),
        ),
      )
          .then((_) {
        // 阅读返回后刷新书籍信息
        _loadBook();
      });
    }
  }

  Future<void> _showChangeSourceDialog() async {
    if (_book == null) return;

    await showDialog(
      context: context,
      builder: (context) => ChangeSourceDialog(
        oldBook: _book!,
        onSourceChanged: (BookSource source, Book newBook,
            List<BookChapter> chapters) async {
          // 更新书籍信息
          try {
            // 如果书籍在书架中，需要更新数据库
            if (_isInBookshelf) {
              // 删除旧书籍
              await BookService.instance.deleteBook(_book!.bookUrl);
              // 保存新书籍
              await BookService.instance.createBook(newBook);
              // 保存章节列表
              await BookService.instance.saveChapters(chapters);
            }

            setState(() {
              _book = newBook;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('换源成功')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('换源失败: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _updateChapterList() async {
    if (_book == null || _book!.isLocal) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地书籍无法更新目录')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await BookService.instance.updateChapterList(_book!);
      if (success) {
        // 重新加载书籍信息
        await _loadBook();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('目录更新成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('目录更新失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('目录更新失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 显示封面更换对话框
  void _showChangeCoverDialog() {
    if (_book == null) return;

    showDialog(
      context: context,
      builder: (context) => ChangeCoverDialog(
        book: _book!,
        onCoverChanged: (coverUrl) async {
          // 更新书籍封面
          try {
            final updatedBook = _book!.copyWith(
              customCoverUrl: coverUrl.isEmpty ? null : coverUrl,
            );
            await BookService.instance.updateBook(updatedBook);
            setState(() {
              _book = updatedBook;
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('更新封面失败: $e')),
              );
            }
          }
        },
      ),
    );
  }

  /// 显示设置分组对话框
  Future<void> _showChangeGroupDialog() async {
    if (_book == null) return;

    try {
      final groups =
          await BookGroupService.instance.getAllGroups(showOnly: false);
      if (groups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无可用分组')),
          );
        }
        return;
      }

      final selectedGroup = await showDialog<BookGroup>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择分组'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final isSelected = group.groupId == _book!.group;
                return ListTile(
                  title: Text(group.groupName),
                  trailing: isSelected
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(group),
                );
              },
            ),
          ),
        ),
      );

      if (selectedGroup != null) {
        try {
          await BookService.instance
              .updateBookGroup(_book!.bookUrl, selectedGroup.groupId);
          // 更新本地书籍对象的分组信息
          setState(() {
            _book = _book!.copyWith(group: selectedGroup.groupId);
          });
          // 重新加载书籍信息以确保数据同步
          await _loadBook();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已移动到"${selectedGroup.groupName}"')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('设置分组失败: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载分组失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('书籍详情'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white),
        actions: [
          if (_book != null)
            BookInfoMenu(
              book: _book!,
              isInBookshelf: _isInBookshelf,
              onRefresh: _refreshBook,
              onEdit: () => _showEditPage(),
              onShare: () => _shareBook(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
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
                          onPressed: _loadBook,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : _book == null
                  ? const Center(child: Text('书籍不存在'))
                  : Stack(
                      children: [
                        // 背景图片（封面模糊图）
                        if (_book!.displayCover != null &&
                            _book!.displayCover!.isNotEmpty)
                          Positioned.fill(
                            child: ImageFiltered(
                              imageFilter:
                                  ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: CachedNetworkImage(
                                imageUrl: _book!.displayCover!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: theme.scaffoldBackgroundColor,
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: theme.scaffoldBackgroundColor,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(color: theme.scaffoldBackgroundColor),
                        // 半透明遮罩层
                        Positioned.fill(
                          child: Container(
                            color: const Color(0x50000000),
                          ),
                        ),
                        // 顶部区域背景色（覆盖封面区域，使用与信息区域相同的背景色）
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 90 + 160 + 78, // AppBar高度 + 封面高度 + 弧形高度
                          child: Container(
                            color: (theme.brightness == Brightness.dark
                                    ? (Colors.grey[900] ?? Colors.black)
                                    : Colors.white)
                                .withOpacity(0.3), // 半透明背景色，不完全遮挡背景图片
                          ),
                        ),
                        // 内容层
                        Column(
                          children: [
                            // 可滚动内容
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _refreshBook,
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 书籍信息头部（封面区域透明，信息区域有背景色）
                                      BookInfoHeader(
                                        book: _book!,
                                        onCoverTap: () =>
                                            _showChangeCoverDialog(),
                                        onChangeSource: () =>
                                            _showChangeSourceDialog(),
                                        onViewToc: () => _openChapterList(),
                                        onChangeGroup: () =>
                                            _showChangeGroupDialog(),
                                        chapters: _chapters,
                                        isLoadingChapters: _isLoadingChapters,
                                        chapterError: _chapterError,
                                      ),
                                      // 简介
                                      BookInfoIntro(book: _book!),
                                      // 底部间距（为底部操作栏留空间）
                                      SizedBox(
                                          height: 60 +
                                              MediaQuery.of(context)
                                                  .padding
                                                  .bottom),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 底部操作栏
                            BookInfoActions(
                              book: _book!,
                              isInBookshelf: _isInBookshelf,
                              onRead: () => _startReading(),
                              onAddToShelf: _addToBookshelf,
                              onRemoveFromShelf: _removeFromBookshelf,
                              onChangeSource: () => _showChangeSourceDialog(),
                              onUpdateToc: () => _updateChapterList(),
                            ),
                          ],
                        ),
                      ],
                    ),
    );
  }
}
