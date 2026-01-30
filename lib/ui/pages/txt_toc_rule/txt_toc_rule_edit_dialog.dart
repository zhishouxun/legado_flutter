import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../../data/models/txt_toc_rule.dart';

/// TXT目录规则编辑对话框
class TxtTocRuleEditDialog extends StatefulWidget {
  final TxtTocRule? rule;
  final Function(TxtTocRule) onSave;

  const TxtTocRuleEditDialog({
    super.key,
    this.rule,
    required this.onSave,
  });

  @override
  State<TxtTocRuleEditDialog> createState() => _TxtTocRuleEditDialogState();
}

class _TxtTocRuleEditDialogState extends State<TxtTocRuleEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _ruleController;
  late TextEditingController _exampleController;
  bool _isValid = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule?.name ?? '');
    _ruleController = TextEditingController(text: widget.rule?.rule ?? '');
    _exampleController =
        TextEditingController(text: widget.rule?.example ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ruleController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  bool _validateRule(String rule) {
    if (rule.isEmpty) {
      setState(() {
        _isValid = false;
        _errorMessage = '规则不能为空';
      });
      return false;
    }

    try {
      // 尝试编译正则表达式
      RegExp(rule, multiLine: true);
      setState(() {
        _isValid = true;
        _errorMessage = null;
      });
      return true;
    } catch (e) {
      setState(() {
        _isValid = false;
        _errorMessage = '正则表达式语法错误: $e';
      });
      return false;
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称不能为空')),
      );
      return;
    }

    final rule = _ruleController.text.trim();
    if (!_validateRule(rule)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage ?? '规则验证失败')),
      );
      return;
    }

    final example = _exampleController.text.trim();
    final txtTocRule = widget.rule?.copyWith(
          name: name,
          rule: rule,
          example: example.isEmpty ? null : example,
        ) ??
        TxtTocRule(
          id: DateTime.now().millisecondsSinceEpoch,
          name: name,
          rule: rule,
          example: example.isEmpty ? null : example,
        );

    widget.onSave(txtTocRule);
    Navigator.pop(context);
  }

  void _copyRule() {
    final rule = widget.rule;
    if (rule != null) {
      Clipboard.setData(ClipboardData(text: rule.toJson().toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  void _pasteRule() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      try {
        // 尝试解析 JSON
        final jsonText = clipboardData.text!.trim();
        // 处理可能的格式问题（去除首尾的引号等）
        String cleanedText = jsonText;
        if (cleanedText.startsWith('"') && cleanedText.endsWith('"')) {
          cleanedText = cleanedText.substring(1, cleanedText.length - 1);
          // 处理转义字符
          cleanedText = cleanedText.replaceAll('\\"', '"');
        }
        
        final json = jsonDecode(cleanedText) as Map<String, dynamic>;
        final rule = TxtTocRule.fromJson(json);
        
        // 填充表单
        setState(() {
          _nameController.text = rule.name;
          _ruleController.text = rule.rule;
          _exampleController.text = rule.example ?? '';
        });
        
        // 验证规则
        _validateRule(rule.rule);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('粘贴成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('粘贴失败: 无法解析JSON格式\n$e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板为空')),
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
                      controller: _ruleController,
                      decoration: InputDecoration(
                        labelText: '正则表达式',
                        hintText: '请输入正则表达式规则',
                        border: const OutlineInputBorder(),
                        errorText: _isValid ? null : _errorMessage,
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        _validateRule(value);
                      },
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '提示：使用正则表达式匹配章节标题。例如：第[0-9一二三四五六七八九十百千万]+[章节回]',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _exampleController,
                      decoration: const InputDecoration(
                        labelText: '示例（可选）',
                        hintText: '请输入示例文本',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
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
