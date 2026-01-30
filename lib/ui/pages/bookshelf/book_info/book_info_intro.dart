import 'package:flutter/material.dart';
import '../../../../data/models/book.dart';

/// 书籍简介组件
class BookInfoIntro extends StatelessWidget {
  final Book book;

  const BookInfoIntro({
    super.key,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final intro = book.displayIntro;

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8),
      child: SelectableText(
        intro ?? '',
        style: TextStyle(
          fontSize: 14,
          color: theme.textTheme.bodyMedium?.color ?? 
                 (isDark ? Colors.grey[300] : Colors.grey[700]),
          height: 1.5,
        ),
      ),
    );
  }
}
