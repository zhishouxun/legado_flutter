import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../data/models/dict_rule.dart';
import '../../../services/dict_rule_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 字典规则导入对话框
class DictRuleImportDialog extends BaseBottomSheetStateful {
  final String content;
  final VoidCallback onImportComplete;

  const DictRuleImportDialog({
    super.key,
    required this.content,
    required this.onImportComplete,
  }) : super(
          title: '导入规则',
          heightFactor: 0.8,
        );

  @override
  State<DictRuleImportDialog> createState() => _DictRuleImportDialogState();
}

class _DictRuleImportDialogState
    extends BaseBottomSheetState<DictRuleImportDialog> {
  List<DictRule> _rules = [];
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
            return DictRule.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            // 如果解析失败，创建一个新的规则
            return DictRule(
              name: item['name']?.toString() ?? '未命名规则',
              urlRule: item['urlRule']?.toString() ?? '',
              showRule: item['showRule']?.toString() ?? '',
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
      await DictRuleService.instance.importRules(selectedRules);

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
                                    'URL规则: ${rule.urlRule}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (rule.showRule.isNotEmpty)
                                    Text(
                                      '显示规则: ${rule.showRule}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontFamily: 'monospace',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
