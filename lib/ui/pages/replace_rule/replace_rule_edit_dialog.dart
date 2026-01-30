import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../../data/models/replace_rule.dart';
import '../../widgets/common/custom_switch_list_tile.dart';

/// 替换规则编辑对话框
class ReplaceRuleEditDialog extends StatefulWidget {
  final ReplaceRule? rule;
  final Function(ReplaceRule) onSave;

  const ReplaceRuleEditDialog({
    super.key,
    this.rule,
    required this.onSave,
  });

  @override
  State<ReplaceRuleEditDialog> createState() => _ReplaceRuleEditDialogState();
}

class _ReplaceRuleEditDialogState extends State<ReplaceRuleEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _patternController;
  late TextEditingController _replacementController;
  late TextEditingController _groupController;
  late TextEditingController _scopeController;
  late TextEditingController _excludeScopeController;

  bool _isRegex = true;
  bool _scopeTitle = false;
  bool _scopeContent = true;
  int _timeoutMillisecond = 3000;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule?.name ?? '');
    _patternController =
        TextEditingController(text: widget.rule?.pattern ?? '');
    _replacementController =
        TextEditingController(text: widget.rule?.replacement ?? '');
    _groupController = TextEditingController(text: widget.rule?.group ?? '');
    _scopeController = TextEditingController(text: widget.rule?.scope ?? '');
    _excludeScopeController =
        TextEditingController(text: widget.rule?.excludeScope ?? '');
    _isRegex = widget.rule?.isRegex ?? true;
    _scopeTitle = widget.rule?.scopeTitle ?? false;
    _scopeContent = widget.rule?.scopeContent ?? true;
    _timeoutMillisecond = widget.rule?.timeoutMillisecond ?? 3000;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    _replacementController.dispose();
    _groupController.dispose();
    _scopeController.dispose();
    _excludeScopeController.dispose();
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

    final pattern = _patternController.text.trim();
    if (pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('替换模式不能为空')),
      );
      return;
    }

    // 如果是正则表达式，验证正则表达式是否有效
    if (_isRegex) {
      try {
        RegExp(pattern);
        // 检查是否以未转义的 | 结尾（可能导致超时）
        if (pattern.endsWith('|') && !pattern.endsWith('\\|')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('替换模式不能以未转义的 | 结尾')),
          );
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正则表达式格式错误: $e')),
        );
        return;
      }
    }

    final replacement = _replacementController.text;
    final group = _groupController.text.trim();
    final scope = _scopeController.text.trim();
    final excludeScope = _excludeScopeController.text.trim();

    final replaceRule = widget.rule?.copyWith(
          name: name,
          pattern: pattern,
          replacement: replacement,
          group: group.isEmpty ? null : group,
          scope: scope.isEmpty ? null : scope,
          excludeScope: excludeScope.isEmpty ? null : excludeScope,
          isRegex: _isRegex,
          scopeTitle: _scopeTitle,
          scopeContent: _scopeContent,
          timeoutMillisecond: _timeoutMillisecond,
        ) ??
        ReplaceRule(
          name: name,
          pattern: pattern,
          replacement: replacement,
          group: group.isEmpty ? null : group,
          scope: scope.isEmpty ? null : scope,
          excludeScope: excludeScope.isEmpty ? null : excludeScope,
          isRegex: _isRegex,
          scopeTitle: _scopeTitle,
          scopeContent: _scopeContent,
          timeoutMillisecond: _timeoutMillisecond,
        );

    widget.onSave(replaceRule);
    Navigator.pop(context);
  }

  void _testPattern() {
    final pattern = _patternController.text.trim();
    final replacement = _replacementController.text;
    final testText = '测试文本：这是一段测试文本，用于验证替换规则是否正确。';

    if (pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入替换模式')),
      );
      return;
    }

    try {
      String result;
      if (_isRegex) {
        final regex = RegExp(pattern, multiLine: true);
        result = testText.replaceAll(regex, replacement);
      } else {
        result = testText.replaceAll(pattern, replacement);
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('测试结果'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('原始文本:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(testText, style: const TextStyle(fontFamily: 'monospace')),
              const SizedBox(height: 16),
              const Text('替换后:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(result, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正则表达式错误: $e')),
      );
    }
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
        final rule = ReplaceRule.fromJson(json as Map<String, dynamic>);

        setState(() {
          _nameController.text = rule.name;
          _patternController.text = rule.pattern;
          _replacementController.text = rule.replacement;
          _groupController.text = rule.group ?? '';
          _scopeController.text = rule.scope ?? '';
          _excludeScopeController.text = rule.excludeScope ?? '';
          _isRegex = rule.isRegex;
          _scopeTitle = rule.scopeTitle;
          _scopeContent = rule.scopeContent;
          _timeoutMillisecond = rule.timeoutMillisecond;
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
        height: MediaQuery.of(context).size.height * 0.85,
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
                        labelText: '规则名称 *',
                        hintText: '请输入规则名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _patternController,
                      decoration: InputDecoration(
                        labelText: _isRegex ? '替换模式（正则表达式）*' : '替换模式（普通文本）*',
                        hintText:
                            _isRegex ? '请输入正则表达式，例如：\\n\\s*\\n' : '请输入要替换的文本',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegex
                          ? '提示：替换模式使用正则表达式。常用示例：\n'
                              '• 去除空行：\\n\\s*\\n\n'
                              '• 去除行首行尾空格：^\\s+|\\s+\$\n'
                              '• 去除HTML标签：<[^>]+>'
                          : '提示：替换模式使用普通文本匹配。例如：输入"广告"会将所有"广告"文本替换为指定内容。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: _isRegex ? 'monospace' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _replacementController,
                      decoration: const InputDecoration(
                        labelText: '替换内容',
                        hintText: '请输入替换后的内容，留空表示删除匹配的内容',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('测试规则'),
                      onPressed: _testPattern,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _groupController,
                      decoration: const InputDecoration(
                        labelText: '分组（可选）',
                        hintText: '请输入分组名称，用于分类管理',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 作用范围
                    TextField(
                      controller: _scopeController,
                      decoration: const InputDecoration(
                        labelText: '作用范围（可选）',
                        hintText: '书籍名称或来源，用逗号分隔，留空表示所有书籍',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '提示：指定规则只对特定书籍生效。例如：输入"小说A,小说B"表示只对这两本书生效。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 排除范围
                    TextField(
                      controller: _excludeScopeController,
                      decoration: const InputDecoration(
                        labelText: '排除范围（可选）',
                        hintText: '书籍名称或来源，用逗号分隔',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '提示：指定规则不对哪些书籍生效。例如：输入"小说C"表示对小说C不生效。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 作用类型
                    const Text(
                      '作用类型',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomSwitchListTile(
                      title: const Text('作用于标题'),
                      subtitle: const Text('是否对章节标题应用此规则'),
                      value: _scopeTitle,
                      onChanged: (value) {
                        setState(() {
                          _scopeTitle = value;
                        });
                      },
                    ),
                    CustomSwitchListTile(
                      title: const Text('作用于正文'),
                      subtitle: const Text('是否对正文内容应用此规则'),
                      value: _scopeContent,
                      onChanged: (value) {
                        setState(() {
                          _scopeContent = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // 替换类型
                    const Text(
                      '替换类型',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomSwitchListTile(
                      title: const Text('正则表达式'),
                      subtitle: const Text('开启后使用正则表达式，关闭后使用普通文本替换'),
                      value: _isRegex,
                      onChanged: (value) {
                        setState(() {
                          _isRegex = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // 超时时间
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '超时时间（毫秒）',
                        hintText: '正则表达式执行超时时间，默认3000',
                        border: const OutlineInputBorder(),
                        suffixText: 'ms',
                      ),
                      controller: TextEditingController(
                        text: _timeoutMillisecond.toString(),
                      ),
                      onChanged: (value) {
                        final timeout = int.tryParse(value);
                        if (timeout != null && timeout > 0) {
                          setState(() {
                            _timeoutMillisecond = timeout;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '提示：防止正则表达式执行时间过长导致卡顿。',
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
