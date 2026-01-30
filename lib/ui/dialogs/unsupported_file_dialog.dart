import 'package:flutter/material.dart';

/// 不支持的文件类型对话框
/// 参考项目：FileAssociationActivity.notSupportedLiveData
class UnsupportedFileDialog extends StatelessWidget {
  final String fileName;
  final String? fileExtension;

  const UnsupportedFileDialog({
    super.key,
    required this.fileName,
    this.fileExtension,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('不支持的文件类型'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('无法打开此文件类型'),
          if (fileExtension != null && fileExtension!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '文件扩展名: .$fileExtension',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '文件名: $fileName',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          const Text(
            '支持的文件类型：',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '• 书籍文件：EPUB, MOBI, AZW, AZW3, FB2, UMD, TXT, PDF\n'
            '• 配置文件：JSON\n'
            '• 压缩包：ZIP（包含书籍文件）',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('确定'),
        ),
      ],
    );
  }

  /// 显示对话框
  static Future<void> show(BuildContext context, String fileName, {String? fileExtension}) {
    return showDialog(
      context: context,
      builder: (context) => UnsupportedFileDialog(
        fileName: fileName,
        fileExtension: fileExtension,
      ),
    );
  }
}

