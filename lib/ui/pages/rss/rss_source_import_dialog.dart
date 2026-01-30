import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/models/rss_source.dart';
import '../../../services/rss_service.dart';
import '../../../services/network/network_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// RSS源导入对话框
class RssSourceImportDialog extends BaseBottomSheetStateful {
  const RssSourceImportDialog({super.key}) : super(
          title: '导入RSS源',
          heightFactor: 0.6,
        );

  @override
  State<RssSourceImportDialog> createState() => _RssSourceImportDialogState();
}

class _RssSourceImportDialogState extends BaseBottomSheetState<RssSourceImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  bool _isImporting = false;
  String? _importError;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_importError != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _importError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'RSS源URL或JSON',
              hintText: '输入URL或粘贴JSON内容',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _importFromLocal,
            icon: const Icon(Icons.file_upload),
            label: const Text('从本地文件导入'),
          ),
          const SizedBox(height: 16),
          // 底部按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isImporting ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isImporting ? null : _importFromText,
                child: _isImporting 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('导入'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _importFromText() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _importError = '请输入RSS源URL或JSON内容';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _importError = null;
    });

    try {
      List<RssSource> sources = [];

      // 判断是URL还是JSON
      if (text.startsWith('http://') || text.startsWith('https://')) {
        // 从URL获取
        final response = await NetworkService.instance.get(text);
        final jsonText = await NetworkService.getResponseText(response);
        sources = _parseSources(jsonText);
      } else {
        // 直接解析JSON
        sources = _parseSources(text);
      }

      if (sources.isEmpty) {
        setState(() {
          _importError = '未找到有效的RSS源';
          _isImporting = false;
        });
        return;
      }

      // 保存RSS源
      int successCount = 0;
      for (final source in sources) {
        final success = await RssService.instance.addOrUpdateRssSource(source);
        if (success) successCount++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $successCount / ${sources.length} 个RSS源')),
        );
      }
    } catch (e) {
      setState(() {
        _importError = '导入失败: $e';
        _isImporting = false;
      });
    }
  }

  Future<void> _importFromLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      setState(() {
        _isImporting = true;
        _importError = null;
      });

      final filePath = result.files.single.path!;
      final file = await File(filePath).readAsString();
      final sources = _parseSources(file);

      if (sources.isEmpty) {
        setState(() {
          _importError = '未找到有效的RSS源';
          _isImporting = false;
        });
        return;
      }

      // 保存RSS源
      int successCount = 0;
      for (final source in sources) {
        final success = await RssService.instance.addOrUpdateRssSource(source);
        if (success) successCount++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $successCount / ${sources.length} 个RSS源')),
        );
      }
    } catch (e) {
      setState(() {
        _importError = '导入失败: $e';
        _isImporting = false;
      });
    }
  }

  List<RssSource> _parseSources(String jsonText) {
    try {
      final json = jsonDecode(jsonText);
      final List<RssSource> sources = [];

      if (json is List) {
        for (final item in json) {
          if (item is Map<String, dynamic>) {
            try {
              sources.add(RssSource.fromJson(item));
            } catch (e) {
              // 跳过无效的源
              continue;
            }
          }
        }
      } else if (json is Map<String, dynamic>) {
        // 单个源
        try {
          sources.add(RssSource.fromJson(json));
        } catch (e) {
          // 无效的源
        }
      }

      return sources;
    } catch (e) {
      return [];
    }
  }
}

