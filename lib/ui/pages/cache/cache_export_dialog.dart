import 'package:flutter/material.dart';
import '../../../data/models/book.dart';
import '../../../services/reader/cache_export_service.dart';

/// 缓存导出对话框
class CacheExportDialog extends StatefulWidget {
  final Book book;

  const CacheExportDialog({
    super.key,
    required this.book,
  });

  @override
  State<CacheExportDialog> createState() => _CacheExportDialogState();
}

class _CacheExportDialogState extends State<CacheExportDialog> {
  String _exportType = 'txt';
  bool _isExporting = false;
  int _currentProgress = 0;
  int _totalProgress = 0;

  Future<void> _export() async {
    setState(() {
      _isExporting = true;
      _currentProgress = 0;
      _totalProgress = 0;
    });

    try {
      bool success;
      if (_exportType == 'txt') {
        success = await CacheExportService.instance.exportAsTxt(
          widget.book,
          onProgress: (current, total) {
            if (mounted) {
              setState(() {
                _currentProgress = current;
                _totalProgress = total;
              });
            }
          },
        );
      } else {
        success = await CacheExportService.instance.exportAsEpub(
          widget.book,
          onProgress: (current, total) {
            if (mounted) {
              setState(() {
                _currentProgress = current;
                _totalProgress = total;
              });
            }
          },
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '导出成功' : '导出失败'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导出书籍'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('确定要导出"${widget.book.name}"吗？'),
          const SizedBox(height: 16),
          const Text('导出格式：'),
          RadioListTile<String>(
            title: const Text('TXT'),
            value: 'txt',
            groupValue: _exportType,
            onChanged: _isExporting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _exportType = value;
                      });
                    }
                  },
          ),
          RadioListTile<String>(
            title: const Text('EPUB'),
            value: 'epub',
            groupValue: _exportType,
            onChanged: _isExporting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _exportType = value;
                      });
                    }
                  },
          ),
          if (_isExporting && _totalProgress > 0) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _currentProgress / _totalProgress,
            ),
            const SizedBox(height: 8),
            Text('进度: $_currentProgress / $_totalProgress'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _isExporting ? null : _export,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

