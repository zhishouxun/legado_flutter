import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/book.dart';

/// 网格布局书籍卡片组件
class BookGridCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSearchResult;

  const BookGridCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
    this.isSearchResult = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面图片
                Expanded(
                  flex: 3,
                  child: Hero(
                    tag: 'book_cover_${book.bookUrl}',
                    child: _buildCover(context),
                  ),
                ),
                // 书籍信息
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: _buildInfo(context, theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建封面
  Widget _buildCover(BuildContext context) {
    final coverUrl = book.displayCover;

    // 构建默认封面
    Widget defaultCover = _buildDefaultCover(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[isDark(context) ? 800 : 200],
      ),
      child: coverUrl != null && coverUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: coverUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => defaultCover,
              errorWidget: (context, url, error) => defaultCover,
            )
          : defaultCover,
    );
  }

  bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// 构建默认封面（参考项目：在封面上绘制书名和作者，与 BookCard 保持一致）
  Widget _buildDefaultCover(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    // 获取书名和作者
    final displayName = book.name.trim().isNotEmpty ? book.name.trim() : '未知书籍';
    var displayAuthor = book.author.trim();
    if (displayAuthor.startsWith('作者：') || displayAuthor.startsWith('作者:')) {
      displayAuthor = displayAuthor.replaceFirst(RegExp(r'^作者[：:]'), '').trim();
    }
    displayAuthor = displayAuthor.isNotEmpty ? displayAuthor : '未知作者';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/image_cover_default.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: CustomPaint(
          painter: _DefaultCoverPainter(
            name: displayName,
            author: displayAuthor,
            accentColor: accentColor,
          ),
          child: Container(),
        ),
      ),
    );
  }

  /// 构建信息
  Widget _buildInfo(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = theme.textTheme.titleSmall?.color ?? (isDark ? Colors.white : Colors.black87);
    final secondaryColor = theme.textTheme.bodySmall?.color ?? (isDark ? Colors.grey[400] : Colors.grey[600]);

    // 检查是否有阅读进度
    final hasProgress = !isSearchResult &&
        book.durChapterTitle != null &&
        book.durChapterTitle!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 书名 - 2行显示
        Flexible(
          child: Text(
            book.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: titleColor,
              fontSize: 11,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        // 作者与进度
        Text(
          book.displayAuthor,
          style: theme.textTheme.bodySmall?.copyWith(
            color: secondaryColor,
            fontSize: 10,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (hasProgress)
          Text(
            book.durChapterTitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: secondaryColor?.withOpacity(0.7),
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// 默认封面绘制器（参考项目：在封面上绘制书名和作者，与 BookCard 保持一致）
class _DefaultCoverPainter extends CustomPainter {
  final String name;
  final String author;
  final Color accentColor;

  _DefaultCoverPainter({
    required this.name,
    required this.author,
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
      var currentFontSize = nameStyle.fontSize!;
      final lineHeight = currentFontSize * 1.2;

      for (int i = 0; i < nameChars.length && i < 8; i++) {
        final char = nameChars[i];
        final charOffset = Offset(startX, startY);

        // 先绘制描边（白色）
        final strokeSpan = TextSpan(
          text: char,
          style: TextStyle(
            fontSize: currentFontSize,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = currentFontSize / 5
              ..color = Colors.white,
          ),
        );
        final strokePainter = TextPainter(
          text: strokeSpan,
          textDirection: TextDirection.ltr,
        );
        strokePainter.layout();
        strokePainter.paint(canvas, charOffset);

        // 再绘制填充（主题色）
        final fillSpan = TextSpan(
          text: char,
          style: TextStyle(
            fontSize: currentFontSize,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        );
        final fillPainter = TextPainter(
          text: fillSpan,
          textDirection: TextDirection.ltr,
        );
        fillPainter.layout();
        fillPainter.paint(canvas, charOffset);

        startY += lineHeight;

        // 如果超出范围，换列并缩小字体
        if (startY > size.height * 0.8 && i < nameChars.length - 1) {
          startX += currentFontSize * 1.2;
          startY = size.height * 0.2;
          currentFontSize = size.width / 10;
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
          textDirection: TextDirection.ltr,
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
          textDirection: TextDirection.ltr,
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
        oldDelegate.accentColor != accentColor;
  }
}
