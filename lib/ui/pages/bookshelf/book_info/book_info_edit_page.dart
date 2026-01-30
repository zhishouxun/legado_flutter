import 'package:flutter/material.dart';
import '../../../../data/models/book.dart';
import '../../../../services/book/book_service.dart';

/// 编辑书籍信息页面
class BookInfoEditPage extends StatefulWidget {
  final Book book;

  const BookInfoEditPage({
    super.key,
    required this.book,
  });

  @override
  State<BookInfoEditPage> createState() => _BookInfoEditPageState();
}

class _BookInfoEditPageState extends State<BookInfoEditPage> {
  late TextEditingController _nameController;
  late TextEditingController _authorController;
  late TextEditingController _coverUrlController;
  late TextEditingController _introController;
  late int _selectedType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.book.name);
    _authorController = TextEditingController(text: widget.book.author);
    _coverUrlController = TextEditingController(
      text: widget.book.customCoverUrl ?? widget.book.coverUrl ?? '',
    );
    _introController = TextEditingController(
      text: widget.book.customIntro ?? widget.book.intro ?? '',
    );
    _selectedType = widget.book.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    _coverUrlController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书名不能为空')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 创建更新后的书籍对象
      final updatedBook = widget.book.copyWith(
        name: _nameController.text.trim(),
        author: _authorController.text.trim(),
        customCoverUrl: _coverUrlController.text.trim().isEmpty
            ? null
            : _coverUrlController.text.trim(),
        customIntro: _introController.text.trim().isEmpty
            ? null
            : _introController.text.trim(),
        type: _selectedType,
      );

      // 如果自定义封面URL和原始封面URL相同，则清空自定义封面URL
      if (updatedBook.customCoverUrl == updatedBook.coverUrl) {
        updatedBook.customCoverUrl = null;
      }

      // 如果自定义简介和原始简介相同，则清空自定义简介
      if (updatedBook.customIntro == updatedBook.intro) {
        updatedBook.customIntro = null;
      }

      // 保存到数据库
      await BookService.instance.updateBook(updatedBook);

      if (mounted) {
        Navigator.of(context).pop(updatedBook);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑书籍信息'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
              tooltip: '保存',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 书籍类型
            const Text(
              '书籍类型',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: BookType.text,
                  label: Text('文本'),
                  icon: Icon(Icons.book),
                ),
                ButtonSegment(
                  value: BookType.audio,
                  label: Text('音频'),
                  icon: Icon(Icons.headphones),
                ),
                ButtonSegment(
                  value: BookType.image,
                  label: Text('图片'),
                  icon: Icon(Icons.image),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            // 书名
            const Text(
              '书名',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '请输入书名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 作者
            const Text(
              '作者',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(
                hintText: '请输入作者',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 封面URL
            const Text(
              '封面URL',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _coverUrlController,
              decoration: const InputDecoration(
                hintText: '请输入封面URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 简介
            const Text(
              '简介',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _introController,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: '请输入简介',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
