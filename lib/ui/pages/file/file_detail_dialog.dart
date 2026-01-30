import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/file_manage_service.dart';
import '../../widgets/base/base_dialog.dart';

/// 文件详情对话框
class FileDetailDialog extends BaseDialog {
  final FileInfo fileInfo;

  const FileDetailDialog({
    super.key,
    required this.fileInfo,
  }) : super(
          title: '文件信息',
          widthFactor: 0.9,
          maxWidth: 500,
        );

  @override
  Widget buildContent(BuildContext context) {
    final fileService = FileManageService.instance;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: '名称', value: fileInfo.name),
          const SizedBox(height: 8),
          _InfoRow(label: '路径', value: fileInfo.path),
          const SizedBox(height: 8),
          _InfoRow(
            label: '类型',
            value: fileInfo.isDirectory ? '目录' : '文件',
          ),
          if (!fileInfo.isDirectory) ...[
            const SizedBox(height: 8),
            _InfoRow(
              label: '大小',
              value: fileService.formatFileSize(fileInfo.size),
            ),
          ],
          const SizedBox(height: 8),
          _InfoRow(
            label: '修改时间',
            value: DateFormat('yyyy-MM-dd HH:mm:ss').format(fileInfo.lastModified),
          ),
        ],
      ),
    );
  }
}

/// 信息行Widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

