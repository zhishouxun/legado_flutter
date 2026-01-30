import 'package:flutter/material.dart';
import '../../../data/models/book_chapter.dart';
import '../../../data/models/book.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';
import '../../../utils/app_log.dart';
import '../../../utils/helpers/book_help.dart';
import '../../../services/book/book_service.dart';

/// 内容编辑对话框
/// 参考项目：io.legado.app.ui.book.read.ContentEditDialog
class ContentEditDialog extends BaseBottomSheetStateful {
  final Book book;
  final BookChapter chapter;
  final String initialContent;
  final int? initialScrollPosition;
  final VoidCallback? onContentSaved;

  const ContentEditDialog({
    super.key,
    required this.book,
    required this.chapter,
    required this.initialContent,
    this.initialScrollPosition,
    this.onContentSaved,
  }) : super(
          title: '编辑内容',
          heightFactor: 0.9,
        );

  @override
  State<ContentEditDialog> createState() => _ContentEditDialogState();
}

class _ContentEditDialogState extends BaseBottomSheetState<ContentEditDialog> {
  late TextEditingController _contentController;
  late TextEditingController _titleController;
  final ScrollController _scrollController = ScrollController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _titleController = TextEditingController(text: widget.chapter.title);
    
    // 如果有初始滚动位置，滚动到该位置
    if (widget.initialScrollPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // 估算滚动位置（简化实现）
          final lineHeight = 20.0; // 估算行高
          final estimatedOffset = widget.initialScrollPosition! * lineHeight;
          _scrollController.jumpTo(estimatedOffset.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ));
        }
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 标题编辑
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '章节标题',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.orange),
              ),
            ),
          ),
        ),
        const Divider(color: Colors.white24),
        // 内容编辑
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _contentController,
              scrollController: _scrollController,
              maxLines: null,
              expands: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '编辑章节内容...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ),
        ),
        // 操作按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveContent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('保存', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveContent() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final newTitle = _titleController.text.trim();
      final newContent = _contentController.text;

      if (newContent.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('内容不能为空'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 1. 更新章节标题（如果改变）
      if (newTitle.isNotEmpty && newTitle != widget.chapter.title) {
        // 创建新的章节对象（因为title是final，需要创建新对象）
        final updatedChapter = BookChapter(
          url: widget.chapter.url,
          title: newTitle,
          isVolume: widget.chapter.isVolume,
          baseUrl: widget.chapter.baseUrl,
          bookUrl: widget.chapter.bookUrl,
          index: widget.chapter.index,
          isVip: widget.chapter.isVip,
          isPay: widget.chapter.isPay,
          resourceUrl: widget.chapter.resourceUrl,
          tag: widget.chapter.tag,
          wordCount: widget.chapter.wordCount,
          start: widget.chapter.start,
          end: widget.chapter.end,
          startFragmentId: widget.chapter.startFragmentId,
          endFragmentId: widget.chapter.endFragmentId,
          variable: widget.chapter.variable,
        );
        // 更新数据库中的章节标题
        final chapters = [updatedChapter];
        await BookService.instance.saveChapters(chapters);
      }

      // 2. 保存章节内容到缓存文件
      // 使用BookHelp.saveText方法（它会处理文件名生成）
      await BookHelp.saveText(widget.book, widget.chapter, newContent);

      // 3. 清除章节缓存（如果需要重新加载）
      // 这里不清除，因为我们已经更新了缓存文件

      AppLog.instance.put('章节内容已保存: ${widget.chapter.title}');

      if (mounted) {
        widget.onContentSaved?.call();
        Navigator.pop(context, true); // 返回true表示已保存
      }
    } catch (e) {
      AppLog.instance.put('保存章节内容失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

