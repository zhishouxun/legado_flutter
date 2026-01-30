import 'package:flutter/material.dart';

/// 导入进度对话框
/// 用于显示导入进度和结果
class ImportProgressDialog extends StatefulWidget {
  final Future<void> Function() importTask;
  final String title;
  final String? successMessage;
  final VoidCallback? onSuccess;
  final VoidCallback? onError;

  const ImportProgressDialog({
    super.key,
    required this.importTask,
    required this.title,
    this.successMessage,
    this.onSuccess,
    this.onError,
  });

  @override
  State<ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<ImportProgressDialog> {
  bool _isLoading = true;
  bool _isSuccess = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _executeImport();
  }

  Future<void> _executeImport() async {
    try {
      await widget.importTask();
      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _successMessage = widget.successMessage ?? '导入成功';
      });
      widget.onSuccess?.call();
      
      // 2秒后自动关闭
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _errorMessage = e.toString();
      });
      widget.onError?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在导入...'),
                ],
              )
            else if (_isSuccess)
              Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _successMessage ?? '导入成功',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '导入失败',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red[700],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            if (!_isLoading) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_isSuccess ? '确定' : '关闭'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

