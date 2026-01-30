import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../data/models/replace_rule.dart';
import '../../../services/replace_rule_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 替换规则导入对话框
class ReplaceRuleImportDialog extends BaseBottomSheetStateful {
  final String content;
  final VoidCallback onImportComplete;

  const ReplaceRuleImportDialog({
    super.key,
    required this.content,
    required this.onImportComplete,
  }) : super(
          title: '导入规则',
          heightFactor: 0.8,
        );

  @override
  State<ReplaceRuleImportDialog> createState() =>
      _ReplaceRuleImportDialogState();
}

class _ReplaceRuleImportDialogState
    extends BaseBottomSheetState<ReplaceRuleImportDialog> {
  List<ReplaceRule> _parsedRules = [];
  Set<String> _selectedNames = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _parseContent();
  }

  void _parseContent() {
    try {
      final content = widget.content.trim();

      // 尝试解析为JSON数组
      final dynamic jsonData = jsonDecode(content);

      List<ReplaceRule> rules = [];
      if (jsonData is List) {
        for (var item in jsonData) {
          try {
            final rule = ReplaceRule.fromJson(item as Map<String, dynamic>);
            rules.add(rule);
            _selectedNames.add(rule.name);
          } catch (e) {
            // 跳过无效的规则
            continue;
          }
        }
      } else if (jsonData is Map) {
        // 单个规则对象
        final rule = ReplaceRule.fromJson(jsonData as Map<String, dynamic>);
        rules.add(rule);
        _selectedNames.add(rule.name);
      }

      setState(() {
        _parsedRules = rules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '解析失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _import() async {
    if (_selectedNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个规则')),
      );
      return;
    }

    final rulesToImport = _parsedRules
        .where((rule) => _selectedNames.contains(rule.name))
        .toList();

    try {
      await ReplaceRuleService.instance.importRules(rulesToImport);
      widget.onImportComplete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 ${rulesToImport.length} 个规则')),
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
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(_error!),
                        ],
                      ),
                    )
                  : _parsedRules.isEmpty
                      ? const Center(
                          child: Text('未找到有效的规则'),
                        )
                      : Column(
                          children: [
                            // 全选/取消全选
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _selectedNames.length ==
                                        _parsedRules.length,
                                    tristate: true,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedNames = _parsedRules
                                              .map((r) => r.name)
                                              .toSet();
                                        } else {
                                          _selectedNames.clear();
                                        }
                                      });
                                    },
                                  ),
                                  const Text('全选'),
                                  const Spacer(),
                                  Text(
                                      '已选择 ${_selectedNames.length}/${_parsedRules.length}'),
                                ],
                              ),
                            ),
                            const Divider(),
                            // 规则列表
                            Expanded(
                              child: ListView.builder(
                                itemCount: _parsedRules.length,
                                itemBuilder: (context, index) {
                                  final rule = _parsedRules[index];
                                  final isSelected =
                                      _selectedNames.contains(rule.name);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedNames.add(rule.name);
                                        } else {
                                          _selectedNames.remove(rule.name);
                                        }
                                      });
                                    },
                                    title: Text(rule.name),
                                    subtitle: Text(
                                      '${rule.pattern} → ${rule.replacement}',
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectedNames.isEmpty ? null : _import,
                child: Text('导入 (${_selectedNames.length})'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
