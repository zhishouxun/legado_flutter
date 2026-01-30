import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../data/models/book.dart';
import '../../../../data/models/book_chapter.dart';
import '../../../../services/book_group_service.dart';
import '../../../../data/models/book_group.dart';
import 'package:intl/intl.dart';

/// 书籍信息头部组件
class BookInfoHeader extends StatefulWidget {
  final Book book;
  final VoidCallback? onCoverTap;
  final VoidCallback? onChangeSource;
  final VoidCallback? onViewToc;
  final VoidCallback? onChangeGroup;
  final List<BookChapter>? chapters; // 章节列表（可选，用于显示章节数量）
  final bool isLoadingChapters; // 是否正在加载章节
  final String? chapterError; // 章节加载错误信息

  const BookInfoHeader({
    super.key,
    required this.book,
    this.onCoverTap,
    this.onChangeSource,
    this.onViewToc,
    this.onChangeGroup,
    this.chapters,
    this.isLoadingChapters = false,
    this.chapterError,
  });

  @override
  State<BookInfoHeader> createState() => _BookInfoHeaderState();
}

class _BookInfoHeaderState extends State<BookInfoHeader> {
  BookGroup? _group;
  bool _isLoadingGroup = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  @override
  void didUpdateWidget(BookInfoHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果书籍的分组发生变化，重新加载分组信息
    if (oldWidget.book.group != widget.book.group) {
      _loadGroup();
    }
  }

  Future<void> _loadGroup() async {
    if (widget.book.group == 0) {
      setState(() {
        _group = null;
        _isLoadingGroup = false;
      });
      return;
    }

    try {
      final group =
          await BookGroupService.instance.getGroupById(widget.book.group);
      setState(() {
        _group = group;
        _isLoadingGroup = false;
      });
    } catch (e) {
      setState(() {
        _group = null;
        _isLoadingGroup = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final book = widget.book;
    final coverUrl = book.displayCover;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;

    // 输出封面地址调试信息

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 信息区域背景（延伸到顶部）
        Positioned(
          top: 90 + 78, // 封面区域顶部 + 弧形高度
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: backgroundColor,
          ),
        ),
        // 弧形背景（在封面下方）
        Positioned(
          top: 90,
          left: 0,
          right: 0,
          height: 78,
          child: ClipPath(
            clipper: _ArcClipper(),
            child: Container(
              color: backgroundColor,
            ),
          ),
        ),
        // 内容层
        Column(
          children: [
            // 封面区域（顶部居中）
            Container(
              margin: const EdgeInsets.only(top: 90),
              child: Stack(
                children: [
                  // 封面
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: widget.onCoverTap,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: _buildCover(context, coverUrl),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 信息区域
            Container(
              color: backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: [
                  // 书名（居中）
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        book.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // 分类标签和状态（居中）
                  Container(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          // 分类标签
                          if (book.kind != null && book.kind!.isNotEmpty)
                            ...book.kind!.split(',').take(3).map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  tag.trim(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              );
                            }),
                          // 连载状态标签
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '连载中',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          // 更新时间
                          if (book.latestChapterTime > 0)
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm:ss').format(
                                DateTime.fromMillisecondsSinceEpoch(
                                    book.latestChapterTime),
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color ??
                                    Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // 信息项
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Column(
                      children: [
                        // 作者
                        _buildInfoRow(
                          context,
                          icon: Icons.person_outline,
                          text: '作者:${book.displayAuthor}',
                          onTap: null,
                        ),
                        // 来源
                        _buildInfoRow(
                          context,
                          icon: Icons.language,
                          text: '来源:${book.originName}',
                          onTap: null,
                          trailing: !book.isLocal
                              ? _buildActionChip(
                                  context,
                                  '换源',
                                  widget.onChangeSource ?? () {},
                                )
                              : null,
                        ),
                        // 最新章节
                        if (book.latestChapterTitle != null &&
                            book.latestChapterTitle!.isNotEmpty)
                          _buildInfoRow(
                            context,
                            icon: Icons.bookmark_outline,
                            text: '最新:${book.latestChapterTitle}',
                            onTap: null,
                            trailing: _buildActionChip(
                              context,
                              '设置分组',
                              widget.onChangeGroup ?? () {},
                            ),
                          ),
                        // 分组
                        _buildInfoRow(
                          context,
                          icon: Icons.folder_outlined,
                          text:
                              '分组:${_isLoadingGroup ? '加载中...' : (_group?.groupName ?? '未分组')}',
                          onTap: null,
                        ),
                        // 目录
                        if (!book.isLocal)
                          _buildInfoRow(
                            context,
                            icon: Icons.list,
                            text: widget.isLoadingChapters
                                ? '目录:加载中...'
                                : widget.chapterError != null
                                    ? '目录:加载失败（点击重试）'
                                    : widget.chapters != null
                                        ? widget.chapters!.isEmpty
                                            ? '目录:暂无章节'
                                            : '目录:${widget.chapters!.length}章${widget.chapters!.isNotEmpty ? "（${widget.chapters!.first.title}）" : ""}'
                                        : (book.durChapterTitle != null &&
                                                book.durChapterTitle!.isNotEmpty
                                            ? '目录:${book.durChapterTitle}'
                                            : book.totalChapterNum > 0
                                                ? '目录:${book.totalChapterNum}章'
                                                : '目录:点击查看'),
                            onTap: widget.chapterError != null
                                ? widget.onViewToc // 错误时点击标题也可以重试
                                : null,
                            trailing: _buildActionChip(
                              context,
                              widget.chapterError != null ? '重试' : '查看目录',
                              widget.onViewToc ?? () {},
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建封面
  Widget _buildCover(BuildContext context, String? coverUrl) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[800] : Colors.grey[300];

    // 构建默认封面（显示书名和作者）
    Widget defaultCover = _buildDefaultCover(context);

    return Container(
      width: 110,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: backgroundColor,
      ),
      child: coverUrl != null && coverUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                httpHeaders: {
                  'Referer': widget.book.origin.isNotEmpty
                      ? widget.book.origin
                      : (widget.book.bookUrl.isNotEmpty
                          ? Uri.parse(widget.book.bookUrl).origin
                          : ''),
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                },
                placeholder: (context, url) => defaultCover,
                errorWidget: (context, url, error) {
                  // 封面加载失败，显示默认封面
                  return defaultCover;
                },
              ),
            )
          : defaultCover,
    );
  }

  /// 构建默认封面
  Widget _buildDefaultCover(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[800] : Colors.grey[300];
    final textColor = isDark ? Colors.white : Colors.black87;
    final accentColor = theme.colorScheme.primary;
    final book = widget.book;

    // 获取书名和作者
    final displayName = book.name.trim().isNotEmpty ? book.name.trim() : '未知书籍';
    var displayAuthor = book.author.trim();
    if (displayAuthor.startsWith('作者：') || displayAuthor.startsWith('作者:')) {
      displayAuthor = displayAuthor.replaceFirst(RegExp(r'^作者[：:]'), '').trim();
    }
    displayAuthor = displayAuthor.isNotEmpty ? displayAuthor : '未知作者';

    return Container(
      width: 110,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: backgroundColor,
        image: const DecorationImage(
          image: AssetImage('assets/images/image_cover_default.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: CustomPaint(
        painter: _DefaultCoverPainter(
          name: displayName,
          author: displayAuthor,
          textColor: textColor,
          accentColor: accentColor,
        ),
        child: Container(),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodySmall?.color ?? Colors.grey[600];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: textColor,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionChip(
      BuildContext context, String text, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// 弧形裁剪器
class _ArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final arcHeight = 36.0;

    path.moveTo(0, arcHeight);
    path.quadraticBezierTo(
      size.width / 2,
      -arcHeight,
      size.width,
      arcHeight,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 默认封面绘制器
class _DefaultCoverPainter extends CustomPainter {
  final String name;
  final String author;
  final Color textColor;
  final Color accentColor;

  _DefaultCoverPainter({
    required this.name,
    required this.author,
    required this.textColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制书名（参考项目：在封面左侧垂直显示，每个字符一行）
    if (name.isNotEmpty) {
      final nameChars = name.split('');
      final nameStyle = TextStyle(
        fontSize: size.width / 6,
        fontWeight: FontWeight.bold,
        color: accentColor,
      );

      var startX = size.width * 0.2;
      var startY = size.height * 0.2;
      final lineHeight = nameStyle.fontSize! * 1.2;

      for (int i = 0; i < nameChars.length && i < 8; i++) {
        final char = nameChars[i];
        final charOffset = Offset(startX, startY);

        // 先绘制描边（白色）
        final strokeSpan = TextSpan(
          text: char,
          style: nameStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = nameStyle.fontSize! / 5
              ..color = Colors.white,
          ),
        );
        final strokePainter = TextPainter(
          text: strokeSpan,
          textDirection: ui.TextDirection.ltr,
        );
        strokePainter.layout();
        strokePainter.paint(canvas, charOffset);

        // 再绘制填充（主题色）
        final fillSpan = TextSpan(
          text: char,
          style: nameStyle,
        );
        final fillPainter = TextPainter(
          text: fillSpan,
          textDirection: ui.TextDirection.ltr,
        );
        fillPainter.layout();
        fillPainter.paint(canvas, charOffset);

        startY += lineHeight;

        // 如果超出范围，换列
        if (startY > size.height * 0.8 && i < nameChars.length - 1) {
          startX += nameStyle.fontSize! * 1.2;
          startY = size.height * 0.2;
        }
      }
    }

    // 绘制作者（参考项目：在封面右侧垂直显示，每个字符一行）
    if (author.isNotEmpty) {
      final authorChars = author.split('');
      final authorStyle = TextStyle(
        fontSize: size.width / 10,
        color: accentColor,
      );

      var startX = size.width * 0.8;
      var startY = size.height * 0.95;
      final lineHeight = authorStyle.fontSize! * 1.2;

      // 从下往上绘制
      for (int i = authorChars.length - 1;
          i >= 0 && i >= authorChars.length - 6;
          i--) {
        final char = authorChars[i];
        startY -= lineHeight;

        if (startY < size.height * 0.3) break;

        final charOffset = Offset(startX, startY);

        // 先绘制描边（白色）
        final strokeSpan = TextSpan(
          text: char,
          style: authorStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = authorStyle.fontSize! / 5
              ..color = Colors.white,
          ),
        );
        final strokePainter = TextPainter(
          text: strokeSpan,
          textDirection: ui.TextDirection.ltr,
        );
        strokePainter.layout();
        strokePainter.paint(canvas, charOffset);

        // 再绘制填充（主题色）
        final fillSpan = TextSpan(
          text: char,
          style: authorStyle,
        );
        final fillPainter = TextPainter(
          text: fillSpan,
          textDirection: ui.TextDirection.ltr,
        );
        fillPainter.layout();
        fillPainter.paint(canvas, charOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DefaultCoverPainter oldDelegate) {
    return oldDelegate.name != name ||
        oldDelegate.author != author ||
        oldDelegate.textColor != textColor ||
        oldDelegate.accentColor != accentColor;
  }
}
