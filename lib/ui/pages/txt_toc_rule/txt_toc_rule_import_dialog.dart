import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../data/models/txt_toc_rule.dart';
import '../../../services/txt_toc_rule_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// TXT目录规则导入对话框
class TxtTocRuleImportDialog extends BaseBottomSheetStateful {
  final String content;
  final VoidCallback onImportComplete;

  const TxtTocRuleImportDialog({
    super.key,
    required this.content,
    required this.onImportComplete,
  }) : super(
          title: '导入规则',
          heightFactor: 0.8,
        );

  @override
  State<TxtTocRuleImportDialog> createState() => _TxtTocRuleImportDialogState();
}

class _TxtTocRuleImportDialogState
    extends BaseBottomSheetState<TxtTocRuleImportDialog> {
  List<TxtTocRule> _rules = [];
  Set<int> _selectedIndices = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  void _parseContent() {
    try {
      final json = jsonDecode(widget.content);
      List<dynamic> rulesList;

      if (json is List) {
        rulesList = json;
      } else if (json is Map && json.containsKey('rules')) {
        rulesList = json['rules'] as List;
      } else {
        // 尝试作为单个规则解析
        rulesList = [json];
      }

      setState(() {
        _rules = rulesList.map((item) {
          try {
            return TxtTocRule.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            // 如果解析失败，创建一个新的规则
            return TxtTocRule(
              id: DateTime.now().millisecondsSinceEpoch +
                  rulesList.indexOf(item),
              name: item['name']?.toString() ?? '未命名规则',
              rule: item['rule']?.toString() ?? '',
              example: item['example']?.toString(),
            );
          }
        }).toList();
        _selectedIndices =
            Set.from(List.generate(_rules.length, (index) => index));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '解析失败: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices =
          Set.from(List.generate(_rules.length, (index) => index));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  Future<void> _import() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个规则')),
      );
      return;
    }

    try {
      final selectedRules =
          _selectedIndices.map((index) => _rules[index]).toList();
      await TxtTocRuleService.instance.importRules(selectedRules);

      widget.onImportComplete();
      Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 ${selectedRules.length} 个规则')),
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
        // 全选/取消全选按钮
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _selectAll,
                child: const Text('全选'),
              ),
              TextButton(
                onPressed: _deselectAll,
                child: const Text('取消全选'),
              ),
            ],
          ),
        ),
        // 规则列表
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
                          Text(_errorMessage!),
                        ],
                      ),
                    )
                  : _rules.isEmpty
                      ? const Center(child: Text('未找到规则'))
                      : ListView.builder(
                          itemCount: _rules.length,
                          itemBuilder: (context, index) {
                            final rule = _rules[index];
                            final isSelected = _selectedIndices.contains(index);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(index),
                              title: Text(rule.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rule.rule,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (rule.example != null &&
                                      rule.example!.isNotEmpty)
                                    Text(
                                      '示例: ${rule.example}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
        // 底部按钮
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _import,
                child: Text('导入 (${_selectedIndices.length})'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
