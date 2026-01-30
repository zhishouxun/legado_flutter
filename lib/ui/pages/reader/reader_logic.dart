part of 'reader_page.dart';

/// 阅读器核心业务逻辑（最终修复版 - 确保编译与加载）
extension ReaderLogicMethods on _ReaderPageState {
  /// 加载章节列表
  Future<void> _loadChapters() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final chapters = await BookService.instance.getChapterList(widget.book);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });
      await _loadContent(_currentChapterIndex, resetPageOffset: true);
    } catch (e) {
      AppLog.instance.put('加载章节列表失败', error: e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 加载章节内容
  Future<void> _loadContent(int index, {bool resetPageOffset = false}) async {
    if (index < 0 || index >= _chapters.length) return;
    if (_loadingChapters.contains(index)) return;

    final chapter = _chapters[index];
    _loadingChapters.add(index);

    try {
      String? content = await CacheService.instance
          .getCachedChapterContent(widget.book, chapter);

      if (content == null || content.isEmpty) {
        if (_bookSource == null) {
          _bookSource = await BookSourceService.instance
              .getBookSourceByUrl(widget.book.origin);
        }
        if (_bookSource != null) {
          content = await BookService.instance
              .getChapterContent(chapter, _bookSource!, book: widget.book);
        }
      }

      if (content != null && mounted) {
        await _onContentLoaded(index, content, resetPageOffset);
      }
    } catch (e) {
      AppLog.instance.put('加载章节内容失败: $index', error: e);
    } finally {
      _loadingChapters.remove(index);
    }
  }

  /// 内容加载完成后的处理
  Future<void> _onContentLoaded(
      int index, String content, bool resetPageOffset) async {
    final processor = ContentProcessor.get(widget.book);
    final processedResult =
        await processor.getContent(widget.book, _chapters[index], content);
    final processed = processedResult.contents.join('\n');

    if (!mounted) return;

    // 获取屏幕尺寸进行分页
    final screenSize = MediaQuery.of(context).size;
    final layoutProvider = ChapterLayoutProvider();
    
    // 更新分页配置
    layoutProvider.updateConfig(
      viewWidth: screenSize.width,
      viewHeight: screenSize.height,
      paddingHorizontal: _readConfig.paddingLeft,
      paddingVertical: _readConfig.paddingTop,
      fontSize: _readConfig.fontSize,
      lineHeight: _readConfig.lineHeight,
      letterSpacing: _readConfig.letterSpacing,
      fontWeight: _readConfig.fontWeight,
      fontFamily: _readConfig.fontFamily,
      titleSize: _readConfig.titleSize.toDouble(),
      titleTopSpacing: _readConfig.titleTopSpacing.toDouble(),
      titleBottomSpacing: _readConfig.titleBottomSpacing.toDouble(),
      titleMode: _readConfig.titleMode,
      paragraphIndent: _readConfig.paragraphIndent,
      paragraphSpacing: _readConfig.paragraphSpacing.toInt(),
    );
    
    // 使用 ChapterLayoutProvider 进行正确的分页
    final textChapter = layoutProvider.layoutChapter(
      chapter: _chapters[index],
      content: processed,
      chapterIndex: index,
      chaptersSize: _chapters.length,
    );

    if (!mounted) return;

    setState(() {
      if (index == _currentChapterIndex) {
        _curTextChapter = textChapter;
        if (resetPageOffset) _currentPageIndex = 0;
      } else if (index == _currentChapterIndex + 1) {
        _nextTextChapter = textChapter;
      } else if (index == _currentChapterIndex - 1) {
        _prevTextChapter = textChapter;
      }
    });

    _updateProgress();
  }

  /// 保存进度
  void _updateProgress() {
    widget.book.durChapterIndex = _currentChapterIndex;
    widget.book.durChapterPos = _currentPageIndex;
    widget.book.durChapterTime = DateTime.now().millisecondsSinceEpoch;
    BookService.instance.updateBook(widget.book);
  }

  /// 是否有下一章
  bool _hasNextChapter() => _currentChapterIndex < _chapters.length - 1;

  /// 是否有上一章
  bool _hasPrevChapter() => _currentChapterIndex > 0;

  /// 章节切换回调
  void _onChapterChanged(int index, {int? targetPageIndex}) {
    if (index == _currentChapterIndex) return;
    if (index < 0 || index >= _chapters.length) return;

    // 检查是否是相邻章节跳转
    final isAdjacentNext = index == _currentChapterIndex + 1;
    final isAdjacentPrev = index == _currentChapterIndex - 1;

    setState(() {
      if (isAdjacentNext && _nextTextChapter != null) {
        // 跳转到下一章，且下一章已预加载
        _prevTextChapter = _curTextChapter;
        _curTextChapter = _nextTextChapter;
        _nextTextChapter = null;
      } else if (isAdjacentPrev && _prevTextChapter != null) {
        // 跳转到上一章，且上一章已预加载
        _nextTextChapter = _curTextChapter;
        _curTextChapter = _prevTextChapter;
        _prevTextChapter = null;
      } else {
        // 跳转到非相邻章节，清空所有缓存
        _prevTextChapter = null;
        _curTextChapter = null;
        _nextTextChapter = null;
      }
      _currentChapterIndex = index;
      // 如果指定了目标页面索引，使用指定值；否则默认为第一页
      _currentPageIndex = targetPageIndex ?? 0;
    });

    // 在翻页模式下，在下一帧重置 PageController 到目标页面
    // 使用 addPostFrameCallback 确保 PageView 完全重建后再跳转
    if (_readConfig.pageMode != AppStatus.pageModeScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && mounted) {
          _pageController.jumpToPage(_currentPageIndex);
        }
      });
    }

    // 始终加载目标章节内容（如果当前章节为空或章节索引不匹配）
    if (_curTextChapter == null || _curTextChapter!.chapterIndex != index) {
      _loadContent(index, resetPageOffset: true);
    } else {
      _updateProgress();
    }
    
    // 预加载相邻章节
    _loadContent(index + 1);
    _loadContent(index - 1);
  }

  /// 滚动模式下的翻页处理
  void _handleScrollPageTap(bool isNext) {
    final controller = _chapterScrollControllers[_currentChapterIndex];
    if (controller == null || !controller.hasClients) return;

    final viewHeight = controller.position.viewportDimension;
    const retentionHeight = 40.0;
    double targetOffset = isNext
        ? controller.offset + viewHeight - retentionHeight
        : controller.offset - viewHeight + retentionHeight;

    if (isNext && targetOffset >= controller.position.maxScrollExtent - 5) {
      _switchToNextChapter();
    } else if (!isNext && targetOffset <= 5) {
      _switchToPreviousChapter();
    } else {
      controller.animateTo(
        targetOffset.clamp(0.0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _switchToNextChapter() {
    if (_hasNextChapter()) {
      // 跳转到下一章时，显示第一页（索引0）
      _onChapterChanged(_currentChapterIndex + 1, targetPageIndex: 0);
      // PageView 会通过 key 重建，不需要手动 jumpToPage
    }
  }

  void _switchToPreviousChapter() {
    if (_hasPrevChapter()) {
      final prevChapterIndex = _currentChapterIndex - 1;
      // 获取上一章的页数
      final prevChapter = _prevTextChapter;
      int lastPageIndex = 0;

      if (prevChapter != null && prevChapter.pages.isNotEmpty) {
        // 如果上一章已加载，跳转到最后一页
        lastPageIndex = prevChapter.pages.length - 1;
      }

      // 跳转到上一章时，显示最后一页
      _onChapterChanged(prevChapterIndex, targetPageIndex: lastPageIndex);
      // PageView 会通过 key 重建，不需要手动 jumpToPage
    }
  }

  void _startTts() {
    if (_curTextChapter == null || _curTextChapter!.content == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前章节内容为空')),
      );
      return;
    }

    setState(() => _showMenu = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TtsControlWidget(
        text: _curTextChapter!.content!,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _showChapterList() async {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChapterListPage(
            chapters: _chapters,
            currentChapterIndex: _currentChapterIndex,
            onChapterSelected: (index) {
              if (mounted) {
                // 章节列表选择章节时，跳转到该章的第一页
                _onChapterChanged(index, targetPageIndex: 0);
              }
            },
          ),
        ));
  }

  void _showThemeSettings() {
    setState(() => _showMenu = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReaderSettingsPage(
        book: widget.book,
        onConfigChanged: (config) {
          if (mounted) {
            setState(() {
              _readConfig = config;
            });
          }
        },
      ),
    );
  }

  void _showMoreSettings() {
    setState(() => _showMenu = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MoreSettingsDialog(
        onSettingsChanged: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  void _showSearchContent() {
    setState(() => _showMenu = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchContentPage(
          book: widget.book,
          onResultSelected: (chapterIndex, position, keyword) {
            if (mounted) {
              setState(() {
                _searchChapterIndex = chapterIndex;
                _searchPosition = position;
                _searchKeyword = keyword;
              });
              _onChapterChanged(chapterIndex);
            }
          },
        ),
      ),
    );
  }

  void _showAutoRead() {
    setState(() => _showMenu = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AutoReadDialog(),
    );
  }

  void _refreshChapter() async {
    if (_currentChapterIndex < 0 || _currentChapterIndex >= _chapters.length)
      return;

    setState(() => _showMenu = false);

    // 清除缓存
    _chapterContents.remove(_currentChapterIndex);
    _chapterPages.remove(_currentChapterIndex);
    _curTextChapter = null;

    // 重新加载
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在刷新章节...')),
    );

    // 重新加载当前章节
    _onChapterChanged(_currentChapterIndex);

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('章节刷新成功')),
      );
    }
  }

  void _toggleDayNight() {
    setState(() {
      if (_readConfig.backgroundColor == 0xFF000000) {
        // 切换到日间模式
        _readConfig = _readConfig.copyWith(
          backgroundColor: 0xFFFFFFFF,
          textColor: 0xFF000000,
        );
        // 保存全局主题模式为日间
        AppConfig.setIsNightTheme(false);
      } else {
        // 切换到夜间模式
        _readConfig = _readConfig.copyWith(
          backgroundColor: 0xFF000000,
          textColor: 0xFFFFFFFF,
        );
        // 保存全局主题模式为夜间
        AppConfig.setIsNightTheme(true);
      }
    });

    // 保存配置
    final updatedBook = widget.book.copyWith(readConfig: _readConfig);
    BookService.instance.saveBook(updatedBook);
  }
}
