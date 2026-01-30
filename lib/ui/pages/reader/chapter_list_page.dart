import 'package:flutter/material.dart';
import '../../../data/models/book_chapter.dart';

/// 章节列表页面
class ChapterListPage extends StatefulWidget {
  final List<BookChapter> chapters;
  final int currentChapterIndex;
  final Function(int) onChapterSelected;

  const ChapterListPage({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
  });

  @override
  State<ChapterListPage> createState() => _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _jumpController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<BookChapter> _filteredChapters = [];
  // 性能优化：缓存过滤后的索引映射，避免重复查找
  final Map<int, int> _indexMap = {}; // filteredIndex -> originalIndex
  bool _showUrl = false; // 是否显示章节URL

  @override
  void initState() {
    super.initState();
    _filteredChapters = widget.chapters;
    _rebuildIndexMap();
    // 延迟滚动到当前章节
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentChapter();
    });
  }

  @override
  void didUpdateWidget(ChapterListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果章节列表或当前章节索引发生变化，更新过滤列表和索引映射
    if (oldWidget.chapters != widget.chapters ||
        oldWidget.currentChapterIndex != widget.currentChapterIndex) {
      _filteredChapters = widget.chapters;
      _rebuildIndexMap();
      // 重新滚动到当前章节
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentChapter();
      });
    }
  }

  /// 重建索引映射
  void _rebuildIndexMap() {
    _indexMap.clear();
    for (int i = 0; i < _filteredChapters.length; i++) {
      final originalIndex = widget.chapters.indexOf(_filteredChapters[i]);
      if (originalIndex >= 0) {
        _indexMap[i] = originalIndex;
      }
    }
  }

  /// 获取原始索引（带缓存）
  int _getOriginalIndex(int filteredIndex) {
    return _indexMap[filteredIndex] ??
        widget.chapters.indexOf(_filteredChapters[filteredIndex]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _jumpController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动到当前章节
  void _scrollToCurrentChapter() {
    if (_scrollController.hasClients &&
        widget.currentChapterIndex >= 0 &&
        widget.currentChapterIndex < _filteredChapters.length) {
      // 计算当前章节的位置
      final itemHeight = 56.0; // ListTile 的默认高度
      final targetOffset = widget.currentChapterIndex * itemHeight;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final viewportHeight = _scrollController.position.viewportDimension;

      // 滚动到当前章节，使其居中显示
      final scrollOffset = (targetOffset - viewportHeight / 2 + itemHeight / 2)
          .clamp(0.0, maxScroll);

      _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 搜索章节（性能优化：使用预编译的正则表达式）
  void _searchChapters(String keyword) {
    if (keyword.isEmpty) {
      setState(() {
        _filteredChapters = widget.chapters;
        _rebuildIndexMap();
      });
      return;
    }

    // 性能优化：预编译搜索关键词
    final lowerKeyword = keyword.toLowerCase();
    setState(() {
      _filteredChapters = widget.chapters.where((chapter) {
        return chapter.title.toLowerCase().contains(lowerKeyword);
      }).toList();
      _rebuildIndexMap();
    });
  }

  /// 快速跳转到指定章节
  void _jumpToChapter() {
    final input = _jumpController.text.trim();
    if (input.isEmpty) return;

    int? targetIndex;

    // 尝试解析为数字（章节号）
    final number = int.tryParse(input);
    if (number != null && number > 0 && number <= widget.chapters.length) {
      targetIndex = number - 1; // 转换为索引（从0开始）
    } else {
      // 尝试搜索匹配的章节标题
      final lowerInput = input.toLowerCase();
      for (int i = 0; i < widget.chapters.length; i++) {
        if (widget.chapters[i].title.toLowerCase().contains(lowerInput)) {
          targetIndex = i;
          break;
        }
      }
    }

    if (targetIndex != null) {
      Navigator.pop(context); // 关闭跳转对话框
      Navigator.pop(context); // 关闭目录页面
      widget.onChapterSelected(targetIndex);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到指定章节')),
      );
    }
  }

  /// 显示快速跳转对话框
  void _showJumpDialog() {
    _jumpController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('快速跳转'),
        content: TextField(
          controller: _jumpController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入章节号或章节名',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _jumpToChapter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _jumpToChapter();
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 根据参考项目的颜色定义：
    // 浅色模式：primaryText = #de000000 (87% 黑色), secondaryText = #8a000000 (54% 黑色)
    // 深色模式：primaryText = #ffffffff (100% 白色), secondaryText = #b3ffffff (70% 白色)
    // 参考项目：当前章节使用 accentColor，非当前章节使用 primaryText
    final defaultTextColor = isDark
        ? Colors.white // 深色模式：100% 白色（参考 primaryText）
        : const Color(0xDE000000); // 浅色模式：87% 黑色（参考 primaryText）
    final secondaryTextColor = isDark
        ? const Color(0xB3FFFFFF) // 深色模式：70% 白色（参考 secondaryText）
        : const Color(0x8A000000); // 浅色模式：54% 黑色（参考 secondaryText）

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('目录'),
            const Spacer(),
            Text(
              '共 ${widget.chapters.length} 章',
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation),
            tooltip: '快速跳转',
            onPressed: _showJumpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                ),
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: defaultTextColor),
              decoration: InputDecoration(
                hintText: '搜索章节...',
                hintStyle: TextStyle(color: secondaryTextColor),
                prefixIcon: Icon(Icons.search, color: secondaryTextColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: secondaryTextColor),
                        onPressed: () {
                          _searchController.clear();
                          _searchChapters('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
              ),
              onChanged: _searchChapters,
            ),
          ),
          // 章节列表
          Expanded(
            child: _filteredChapters.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '未找到匹配的章节',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _filteredChapters.length,
                    // 性能优化：设置缓存范围，减少重建
                    cacheExtent: 1000, // 缓存1000像素范围外的项目
                    // 性能优化：使用 addAutomaticKeepAlives 保持滚动位置
                    addAutomaticKeepAlives: true,
                    // 性能优化：使用 addRepaintBoundaries 减少重绘
                    addRepaintBoundaries: true,
                    itemBuilder: (context, index) {
                      final chapter = _filteredChapters[index];
                      // 性能优化：使用 Map 缓存索引映射，避免重复查找
                      final originalIndex = _getOriginalIndex(index);
                      final isCurrent =
                          originalIndex == widget.currentChapterIndex;
                      final isVolume = chapter.isVolume;

                      // 参考项目：当前章节使用 accentColor（主题强调色），非当前章节使用 primaryText
                      // 参考项目：卷名使用 btn_bg_press 作为背景色
                      final backgroundColor = isCurrent
                          ? (isDark
                              ? theme.primaryColor
                                  .withOpacity(0.2) // 深色模式：20% 透明度
                              : theme.primaryColor
                                  .withOpacity(0.1)) // 浅色模式：10% 透明度
                          : (isVolume
                              ? (isDark
                                  ? const Color(0x634D4D4D) // 深色模式：btn_bg_press
                                  : const Color(
                                      0x63ACACAC)) // 浅色模式：btn_bg_press
                              : Colors.transparent);

                      // 参考项目逻辑：
                      // - 当前章节：使用红色（调试用）
                      // - 非当前章节：使用 primaryText（defaultTextColor）
                      // - 卷名：使用 primaryText（defaultTextColor）
                      final titleColor = isCurrent
                          ? Colors.red // 当前章节使用红色（调试用）
                          : (isVolume
                              ? defaultTextColor
                              : defaultTextColor); // 非当前章节和卷名使用主要文字颜色

                      return Container(
                        color: backgroundColor,
                        child: ListTileTheme(
                          // 确保文字颜色正确应用，不会被默认样式覆盖
                          textColor: titleColor,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: isVolume
                                ? Icon(
                                    Icons.folder,
                                    color: theme.primaryColor,
                                  )
                                : null,
                            title: Text(
                              chapter.title.isEmpty ? '无标题' : chapter.title,
                              style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : (isVolume
                                        ? FontWeight.w500
                                        : FontWeight.normal),
                                // 强制设置文字颜色，确保所有章节（包括第一条）都有明确的颜色
                                color: titleColor,
                                fontSize: isVolume ? 15 : 14,
                              ),
                            ),
                            // 显示章节URL（长按切换显示/隐藏）
                            subtitle: _showUrl
                                ? Text(
                                    chapter.url,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.red,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: isCurrent
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.primaryColor,
                                  )
                                : (chapter.isVip
                                    ? Icon(
                                        Icons.lock,
                                        size: 16,
                                        color: Colors.orange,
                                      )
                                    : null),
                            onTap: () {
                              if (!isVolume) {
                                Navigator.pop(context);
                                widget.onChapterSelected(originalIndex);
                              }
                            },
                            onLongPress: () {
                              // 长按切换URL显示状态
                              setState(() {
                                _showUrl = !_showUrl;
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // 底部信息栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.currentChapterIndex >= 0 &&
                            widget.currentChapterIndex < widget.chapters.length
                        ? '当前: ${widget.chapters[widget.currentChapterIndex].title}'
                        : '当前: 未知章节',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.chapters.isNotEmpty
                      ? '${(widget.currentChapterIndex >= 0 && widget.currentChapterIndex < widget.chapters.length ? widget.currentChapterIndex + 1 : 0)}/${widget.chapters.length}'
                      : '0/0',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
