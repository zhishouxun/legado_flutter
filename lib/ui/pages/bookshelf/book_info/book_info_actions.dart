import 'package:flutter/material.dart';
import '../../../../data/models/book.dart';

/// 书籍操作按钮组件
class BookInfoActions extends StatelessWidget {
  final Book book;
  final bool isInBookshelf;
  final VoidCallback? onRead;
  final VoidCallback? onAddToShelf;
  final VoidCallback? onRemoveFromShelf;
  final VoidCallback? onChangeSource;
  final VoidCallback? onUpdateToc;

  const BookInfoActions({
    super.key,
    required this.book,
    required this.isInBookshelf,
    this.onRead,
    this.onAddToShelf,
    this.onRemoveFromShelf,
    this.onChangeSource,
    this.onUpdateToc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? theme.colorScheme.surface
        : theme.colorScheme.surface.withOpacity(0.95);
    final dividerColor = theme.dividerColor;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: dividerColor,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              // 移除/添加到书架按钮
              Expanded(
                child: InkWell(
                  onTap: isInBookshelf ? onRemoveFromShelf : onAddToShelf,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    child: Text(
                      isInBookshelf ? '移出书架' : '放入书架',
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
              ),
              // 分隔线
              Container(
                width: 1,
                height: 50,
                color: dividerColor,
              ),
              // 开始阅读按钮
              Expanded(
                child: InkWell(
                  onTap: onRead,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '阅读',
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
