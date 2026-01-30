import 'package:flutter/material.dart';
import '../../../data/models/replace_rule.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';
import '../../../config/app_config.dart';
import '../replace_rule/replace_rule_edit_dialog.dart';
import '../../../services/replace_rule_service.dart';

/// 生效的替换规则对话框
/// 参考项目：io.legado.app.ui.book.read.EffectiveReplacesDialog
class EffectiveReplacesDialog extends BaseBottomSheetStateful {
  final List<ReplaceRule>? effectiveReplaceRules;

  const EffectiveReplacesDialog({
    super.key,
    this.effectiveReplaceRules,
  }) : super(
          title: '生效的替换规则',
          heightFactor: 0.7,
        );

  @override
  State<EffectiveReplacesDialog> createState() => _EffectiveReplacesDialogState();
}

class _EffectiveReplacesDialogState extends BaseBottomSheetState<EffectiveReplacesDialog> {
  List<ReplaceRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _rules = List.from(widget.effectiveReplaceRules ?? []);
  }

  /// 获取繁简转换类型名称
  String _getChineseConverterTypeName(int type) {
    switch (type) {
      case 1:
        return '简体';
      case 2:
        return '繁体';
      case 3:
        return '台湾繁体';
      case 4:
        return '香港繁体';
      default:
        return '无';
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    final chineseConverterType = AppConfig.getChineseConverterType();
    final hasChineseConverter = chineseConverterType > 0;
    final totalCount = _rules.length + (hasChineseConverter ? 1 : 0);

    if (totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '当前章节没有生效的替换规则',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // 如果是最后一个且启用了繁简转换，显示繁简转换项
        if (hasChineseConverter && index == _rules.length) {
          return ListTile(
            leading: const Icon(Icons.translate, color: Colors.orange),
            title: const Text(
              '繁简转换',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '转换类型: ${_getChineseConverterTypeName(chineseConverterType)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70),
              onPressed: () => _showChineseConverterDialog(),
            ),
            onTap: () => _showChineseConverterDialog(),
          );
        }

        final rule = _rules[index];
        return ListTile(
          title: Text(
            rule.name,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: rule.pattern.isNotEmpty
              ? Text(
                  '${rule.pattern} → ${rule.replacement}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.edit, color: Colors.white70),
            onPressed: () => _editRule(rule),
          ),
          onTap: () => _editRule(rule),
        );
      },
    );
  }

  void _showChineseConverterDialog() {
    final currentType = AppConfig.getChineseConverterType();
    const types = ['无', '简体', '繁体', '台湾繁体', '香港繁体'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('繁简转换', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: types.asMap().entries.map((entry) {
            return RadioListTile<int>(
              title: Text(
                entry.value,
                style: TextStyle(
                  color: entry.key == currentType ? Colors.orange : Colors.white70,
                ),
              ),
              value: entry.key,
              groupValue: currentType,
              activeColor: Colors.orange,
              onChanged: (value) {
                if (value != null) {
                  AppConfig.setChineseConverterType(value);
                  Navigator.pop(context);
                  setState(() {}); // 刷新显示
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _editRule(ReplaceRule rule) async {
    final result = await showDialog<ReplaceRule>(
      context: context,
      builder: (context) => ReplaceRuleEditDialog(
        rule: rule,
        onSave: (updatedRule) {
          Navigator.pop(context, updatedRule);
        },
      ),
    );

    if (result != null) {
      // 更新规则（使用updateRule方法）
      await ReplaceRuleService.instance.updateRule(result);
      setState(() {
        // 更新列表中的规则
        final index = _rules.indexWhere((r) => r.id == rule.id);
        if (index >= 0) {
          _rules[index] = result;
        }
      });
    }
  }
}

