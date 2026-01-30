import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../data/models/book_source.dart';
import '../../../services/source/book_source_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 书源导入对话框
class BookSourceImportDialog extends BaseBottomSheetStateful {
  final String content;
  final VoidCallback? onImportComplete;

  const BookSourceImportDialog({
    super.key,
    required this.content,
    this.onImportComplete,
  }) : super(
          title: '导入书源',
          heightFactor: 0.8,
        );

  @override
  State<BookSourceImportDialog> createState() => _BookSourceImportDialogState();
}

class _BookSourceImportDialogState
    extends BaseBottomSheetState<BookSourceImportDialog> {
  List<BookSource> _sources = [];
  final Map<int, bool> _selectedStatus = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  Future<void> _parseContent() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 尝试解析JSON
      dynamic jsonData;
      try {
        jsonData = jsonDecode(widget.content);
      } catch (e) {
        throw Exception('JSON格式错误: $e');
      }

      List<BookSource> sources = [];

      if (jsonData is List) {
        // 数组格式
        for (final item in jsonData) {
          try {
            if (item is Map<String, dynamic>) {
              final source = BookSource.fromJson(item);
              sources.add(source);
            } else if (item is Map) {
              // 处理 Map<dynamic, dynamic>
              final source =
                  BookSource.fromJson(Map<String, dynamic>.from(item));
              sources.add(source);
            }
          } catch (e) {
            // 跳过无效的书源
            continue;
          }
        }
      } else if (jsonData is Map<String, dynamic>) {
        // 单个书源对象
        try {
          final source = BookSource.fromJson(jsonData);
          sources.add(source);
        } catch (e) {
          throw Exception('书源格式错误: $e');
        }
      } else if (jsonData is Map) {
        // 处理 Map<dynamic, dynamic>
        try {
          final source =
              BookSource.fromJson(Map<String, dynamic>.from(jsonData));
          sources.add(source);
        } catch (e) {
          throw Exception('书源格式错误: $e');
        }
      } else {
        throw Exception('不支持的格式');
      }

      if (sources.isEmpty) {
        throw Exception('未找到有效的书源');
      }

      // 初始化选择状态（默认全选）
      for (int i = 0; i < sources.length; i++) {
        _selectedStatus[i] = true;
      }

      setState(() {
        _sources = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  bool get _isAllSelected {
    if (_sources.isEmpty) return false;
    return _selectedStatus.values.every((selected) => selected);
  }

  int get _selectedCount {
    return _selectedStatus.values.where((selected) => selected).length;
  }

  void _toggleSelectAll() {
    final selectAll = !_isAllSelected;
    setState(() {
      for (int i = 0; i < _sources.length; i++) {
        _selectedStatus[i] = selectAll;
      }
    });
  }

  void _toggleSelect(int index) {
    setState(() {
      _selectedStatus[index] = !(_selectedStatus[index] ?? false);
    });
  }

  Future<void> _import() async {
    final selectedSources = <BookSource>[];
    for (int i = 0; i < _sources.length; i++) {
      if (_selectedStatus[i] == true) {
        selectedSources.add(_sources[i]);
      }
    }

    if (selectedSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个书源')),
      );
      return;
    }

    try {
      final result =
          await BookSourceService.instance.importBookSources(selectedSources);
      final imported = result['imported'] ?? 0;
      final blocked = result['blocked'] ?? 0;

      if (mounted) {
        Navigator.pop(context);
        widget.onImportComplete?.call();

        String message = '成功导入 $imported 个书源';
        if (blocked > 0) {
          message += '，已过滤 $blocked 个18+网站';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 内容区域
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : _sources.isEmpty
                      ? const Center(child: Text('未找到有效的书源'))
                      : Column(
                          children: [
                            // 全选按钮
                            Container(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _isAllSelected,
                                    onChanged: (_) => _toggleSelectAll(),
                                  ),
                                  Text(
                                      '全选 (已选择 $_selectedCount/${_sources.length})'),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // 书源列表
                            Expanded(
                              child: ListView.builder(
                                itemCount: _sources.length,
                                itemBuilder: (context, index) {
                                  final source = _sources[index];
                                  final isSelected =
                                      _selectedStatus[index] ?? false;

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (_) => _toggleSelect(index),
                                    title: Text(source.bookSourceName),
                                    subtitle: Text(
                                      source.bookSourceUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
        ),
        // 底部按钮
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading || _errorMessage != null ? null : _import,
                child: const Text('导入'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
