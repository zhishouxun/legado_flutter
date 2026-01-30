import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../../data/models/dict_rule.dart';

/// 字典规则编辑对话框
class DictRuleEditDialog extends StatefulWidget {
  final DictRule? rule;
  final Function(DictRule) onSave;

  const DictRuleEditDialog({
    super.key,
    this.rule,
    required this.onSave,
  });

  @override
  State<DictRuleEditDialog> createState() => _DictRuleEditDialogState();
}

class _DictRuleEditDialogState extends State<DictRuleEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _urlRuleController;
  late TextEditingController _showRuleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule?.name ?? '');
    _urlRuleController =
        TextEditingController(text: widget.rule?.urlRule ?? '');
    _showRuleController =
        TextEditingController(text: widget.rule?.showRule ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlRuleController.dispose();
    _showRuleController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称不能为空')),
      );
      return;
    }

    final urlRule = _urlRuleController.text.trim();
    if (urlRule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL规则不能为空')),
      );
      return;
    }

    final showRule = _showRuleController.text.trim();
    final dictRule = widget.rule?.copyWith(
          name: name,
          urlRule: urlRule,
          showRule: showRule,
        ) ??
        DictRule(
          name: name,
          urlRule: urlRule,
          showRule: showRule,
        );

    widget.onSave(dictRule);
    Navigator.pop(context);
  }

  void _copyRule() {
    final rule = widget.rule;
    if (rule != null) {
      final jsonString = jsonEncode(rule.toJson());
      Clipboard.setData(ClipboardData(text: jsonString));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  void _pasteRule() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      try {
        final json = jsonDecode(clipboardData!.text!);
        final rule = DictRule.fromJson(json as Map<String, dynamic>);

        setState(() {
          _nameController.text = rule.name;
          _urlRuleController.text = rule.urlRule;
          _showRuleController.text = rule.showRule;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已粘贴规则')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('粘贴失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.rule == null ? '新增规则' : '编辑规则',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.rule != null) ...[
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white),
                      onPressed: _copyRule,
                      tooltip: '复制规则',
                    ),
                    IconButton(
                      icon: const Icon(Icons.paste, color: Colors.white),
                      onPressed: _pasteRule,
                      tooltip: '粘贴规则',
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 表单内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '规则名称',
                        hintText: '请输入规则名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _urlRuleController,
                      decoration: const InputDecoration(
                        labelText: 'URL规则',
                        hintText: '请输入URL规则，使用{{key}}作为查询关键词占位符',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '提示：URL规则用于构建请求URL，{{key}}会被替换为查询的关键词。例如：https://fanyi.baidu.com/transapi?from=auto&to=auto&query={{key}}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _showRuleController,
                      decoration: const InputDecoration(
                        labelText: '显示规则（可选）',
                        hintText: '用于提取显示内容的规则，留空则显示原始响应',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '提示：显示规则用于从响应中提取要显示的内容，支持CSS选择器或XPath。留空则显示原始响应内容。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
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
                    onPressed: _save,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
