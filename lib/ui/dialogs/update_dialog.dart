import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/update/app_update.dart';
import '../../services/download_service.dart';
import '../../utils/app_log.dart';

/// 更新对话框
/// 参考项目：io.legado.app.ui.about.UpdateDialog
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      updateInfo.tagName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // 更新日志内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(
                  data: updateInfo.updateLog.isEmpty
                      ? '暂无更新日志'
                      : updateInfo.updateLog,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14),
                    h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            // 操作按钮
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _downloadUpdate(context),
                    child: const Text('下载'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 下载更新
  /// 参考项目：UpdateDialog.onMenuItemClick()
  Future<void> _downloadUpdate(BuildContext context) async {
    try {
      Navigator.of(context).pop(); // 关闭对话框

      // 使用DownloadService下载更新包
      final taskId = await DownloadService.instance.startDownload(
        updateInfo.downloadUrl,
        fileName: updateInfo.fileName,
      );

      if (taskId != null) {
        AppLog.instance.put('开始下载更新包: ${updateInfo.fileName}');
        // 显示提示
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已开始下载更新包'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        AppLog.instance.put('下载更新包失败');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('下载失败，请稍后重试'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      AppLog.instance.put('下载更新包失败: $e', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

