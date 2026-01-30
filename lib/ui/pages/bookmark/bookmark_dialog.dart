import 'package:flutter/material.dart';
import '../../../data/models/bookmark.dart';
import '../../../services/bookmark_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 书签编辑对话框
class BookmarkDialog extends BaseBottomSheetStateful {
  final Bookmark bookmark;
  final bool isEdit;

  BookmarkDialog({
    super.key,
    required this.bookmark,
    this.isEdit = false,
  }) : super(
          title: bookmark.bookName,
          heightFactor: 0.7,
        );

  @override
  State<BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends BaseBottomSheetState<BookmarkDialog> {
  late TextEditingController _bookTextController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _bookTextController = TextEditingController(text: widget.bookmark.bookText);
    _contentController = TextEditingController(text: widget.bookmark.content);
  }

  @override
  void dispose() {
    _bookTextController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 章节信息
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            widget.bookmark.chapterName,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        // 内容区域
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 书签文本
                const Text(
                  '书签文本',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bookTextController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '输入书签文本',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // 摘要内容
                const Text(
                  '摘要',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: '输入摘要内容（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 底部按钮
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
                  if (widget.isEdit)
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text('删除'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('删除书签'),
                              content: const Text('确定要删除这个书签吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(context); // 关闭确认对话框
                                    await BookmarkService.instance
                                        .deleteBookmark(widget.bookmark.time);
                                    if (context.mounted) {
                                      Navigator.pop(context); // 关闭书签对话框
                                    }
                                  },
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (widget.isEdit) const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // 更新书签
                        final updatedBookmark = Bookmark(
                          time: widget.bookmark.time,
                          bookName: widget.bookmark.bookName,
                          bookAuthor: widget.bookmark.bookAuthor,
                          chapterIndex: widget.bookmark.chapterIndex,
                          chapterPos: widget.bookmark.chapterPos,
                          chapterName: widget.bookmark.chapterName,
                          bookText: _bookTextController.text.trim(),
                          content: _contentController.text.trim(),
                        );

                        await BookmarkService.instance
                            .addBookmark(updatedBookmark);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('保存'),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
