import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/book.dart';

/// 高亮文本组件（辅助函数）
Widget _buildHighlightedText({
  required String text,
  required String keyword,
  required TextStyle style,
}) {
  if (keyword.isEmpty) {
    return Text(
      text,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  final keywordLower = keyword.toLowerCase();
  final textLower = text.toLowerCase();
  final index = textLower.indexOf(keywordLower);

  if (index == -1) {
    return Text(
      text,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  final before = text.substring(0, index);
  final match = text.substring(index, index + keyword.length);
  final after = text.substring(index + keyword.length);

  return RichText(
    text: TextSpan(
      style: style,
      children: [
        TextSpan(text: before),
        TextSpan(
          text: match,
          style: style.copyWith(
            backgroundColor: Colors.yellow.withOpacity(0.5),
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

/// 书籍卡片组件
class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSearchResult;
  final String? highlightKeyword; // 高亮关键词

  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
    this.isSearchResult = false,
    this.highlightKeyword,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面图片
                Hero(
                  tag: 'book_cover_${book.bookUrl}',
                  child: _buildCover(context),
                ),
                const SizedBox(width: 14),
                // 书籍信息
                Expanded(child: _buildInfo(context, theme)),
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
      width: 86,
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: coverUrl != null && coverUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => defaultCover,
                errorWidget: (context, url, error) => defaultCover,
              )
            : defaultCover,
      ),
    );
  }

  /// 构建默认封面（参考项目：在封面上绘制书名和作者）
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
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        image: const DecorationImage(
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
    );
  }

  /// 构建信息
  Widget _buildInfo(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.titleMedium?.color ?? (isDark ? Colors.white : Colors.black87);
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? (isDark ? Colors.grey[400] : Colors.grey[600]);
    
    // 确保有内容显示 - 处理空格问题
    final displayName = book.name.trim().isNotEmpty ? book.name.trim() : '未知书籍';
    // 处理作者重复问题
    var displayAuthor = book.author.trim();
    if (displayAuthor.startsWith('作者：') || displayAuthor.startsWith('作者:')) {
      displayAuthor = displayAuthor.replaceFirst(RegExp(r'^作者[：:]'), '').trim();
    }
    displayAuthor = displayAuthor.isNotEmpty ? displayAuthor : '未知作者';
    
    // 获取分类列表
    final kinds = book.kind != null && book.kind!.isNotEmpty
        ? book.kind!.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList()
        : <String>[];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 书名
        highlightKeyword != null && highlightKeyword!.isNotEmpty
            ? _buildHighlightedText(
                text: displayName,
                keyword: highlightKeyword!,
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              )
            : Text(
                displayName,
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        const SizedBox(height: 6),
        // 作者
        Row(
          children: [
            Icon(Icons.person_outline, size: 14, color: secondaryTextColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                displayAuthor,
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 分类标签
        if (isSearchResult && kinds.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: kinds.take(3).map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
        ],
        // 阅读进度（书架显示）
        if (!isSearchResult) ...[
          if (book.durChapterTitle != null && book.durChapterTitle!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined, size: 12, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      book.durChapterTitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              if (book.totalChapterNum > 0)
                Text(
                  '共${book.totalChapterNum}章',
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor?.withOpacity(0.8),
                  ),
                ),
              if (book.latestChapterTitle != null && book.latestChapterTitle!.isNotEmpty) ...[
                if (book.totalChapterNum > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('·', style: TextStyle(color: secondaryTextColor)),
                  ),
                Expanded(
                  child: Text(
                    '更新：${book.latestChapterTitle}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
        // 简介（搜索结果显示）
        if (isSearchResult && book.displayIntro != null && book.displayIntro!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              book.displayIntro!.trim().replaceAll(RegExp(r'\s+'), ' '),
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// 默认封面绘制器（参考项目：在封面上绘制书名和作者）
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
      for (int i = authorChars.length - 1; i >= 0 && i >= authorChars.length - 6; i--) {
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

