import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/helpers/source/source_help.dart';
import '../../core/constants/app_status.dart';
import '../../utils/app_log.dart';

/// URL确认对话框
/// 参考项目：io.legado.app.ui.association.OpenUrlConfirmDialog
class OpenUrlConfirmDialog extends StatefulWidget {
  final String uri;
  final String? mimeType;
  final String? sourceOrigin;
  final String? sourceName;
  final int sourceType;

  const OpenUrlConfirmDialog({
    super.key,
    required this.uri,
    this.mimeType,
    this.sourceOrigin,
    this.sourceName,
    this.sourceType = AppStatus.sourceTypeBook,
  });

  @override
  State<OpenUrlConfirmDialog> createState() => _OpenUrlConfirmDialogState();
}

class _OpenUrlConfirmDialogState extends State<OpenUrlConfirmDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '确认跳转',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.sourceName != null && widget.sourceName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            widget.sourceName!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 消息内容
            Text(
              '${widget.sourceName ?? "书源"} 正在请求跳转链接/应用，是否跳转？',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            // URL显示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.uri,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
            // 操作按钮
            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _openUrl(),
                        child: const Text('跳转'),
                      ),
                    ],
                  ),
                  if (widget.sourceOrigin != null && widget.sourceOrigin!.isNotEmpty)
                    const Divider(),
                  if (widget.sourceOrigin != null && widget.sourceOrigin!.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.block, size: 18),
                          label: const Text('禁用书源'),
                          onPressed: () => _disableSource(),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          label: const Text('删除书源', style: TextStyle(color: Colors.red)),
                          onPressed: () => _deleteSource(),
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 打开URL
  /// 参考项目：OpenUrlConfirmDialog.openUrl()
  Future<void> _openUrl() async {
    try {
      final uri = Uri.tryParse(widget.uri);
      if (uri == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无效的URL')),
          );
        }
        return;
      }

      // 检查是否可以打开URL
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开链接')),
          );
        }
      }
    } catch (e) {
      AppLog.instance.put('打开链接失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开链接失败: $e')),
        );
      }
    }
  }

  /// 禁用书源
  /// 参考项目：OpenUrlConfirmViewModel.disableSource()
  Future<void> _disableSource() async {
    if (widget.sourceOrigin == null || widget.sourceOrigin!.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await SourceHelp.enableSource(
        widget.sourceOrigin!,
        widget.sourceType,
        false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已禁用书源')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLog.instance.put('禁用书源失败', error: e);
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('禁用失败: $e')),
        );
      }
    }
  }

  /// 删除书源
  /// 参考项目：OpenUrlConfirmViewModel.deleteSource()
  Future<void> _deleteSource() async {
    if (widget.sourceOrigin == null || widget.sourceOrigin!.isEmpty) {
      return;
    }

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书源'),
        content: Text('确定要删除书源 "${widget.sourceName ?? widget.sourceOrigin}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await SourceHelp.deleteSource(
        widget.sourceOrigin!,
        widget.sourceType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除书源')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLog.instance.put('删除书源失败', error: e);
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }
}

