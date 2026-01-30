import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

/// 崩溃日志列表项组件
class CrashLogItem extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const CrashLogItem({
    super.key,
    required this.file,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = path.basename(file.path);
    // 从文件名提取时间戳（格式：crash_yyyy-MM-dd_HH-mm-ss.txt）
    String displayName = fileName;
    if (fileName.startsWith('crash_') && fileName.endsWith('.txt')) {
      final timeStr = fileName.substring(6, fileName.length - 4);
      // 将下划线替换为空格，便于阅读
      displayName = timeStr.replaceAll('_', ' ').replaceAll('-', ':');
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[300]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // 图标
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.bug_report,
                size: 24,
                color: Colors.red[600],
              ),
            ),
            // 文件名和时间
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            // 删除按钮
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.grey[600],
              onPressed: onDelete,
              tooltip: '删除',
            ),
            // 右箭头
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

