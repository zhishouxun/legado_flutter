import 'package:flutter/material.dart';
import '../../../data/models/replace_rule.dart';
import '../../widgets/common/custom_switch.dart';

/// 替换规则项组件
class ReplaceRuleItemWidget extends StatelessWidget {
  final ReplaceRule rule;
  final bool isBatchMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onMoveToTop;
  final VoidCallback? onMoveToBottom;

  const ReplaceRuleItemWidget({
    super.key,
    required this.rule,
    required this.isBatchMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    required this.onToggleEnabled,
    required this.onDelete,
    required this.onEdit,
    this.onMoveToTop,
    this.onMoveToBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 批量选择复选框
              if (isBatchMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    if (value != null) {
                      onTap();
                    }
                  },
                ),
              // 规则信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rule.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (rule.group != null && rule.group!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              rule.group!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        if (!rule.enabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '已禁用',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '模式: ${rule.pattern}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rule.replacement.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '替换为: ${rule.replacement}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // 显示作用范围信息
                    if (rule.scope != null && rule.scope!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.my_location, size: 12, color: Colors.blue[300]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '作用范围: ${rule.scope}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // 显示作用类型
                    if (rule.scopeTitle || rule.scopeContent) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (rule.scopeTitle)
                            Chip(
                              label: const Text('标题', style: TextStyle(fontSize: 10)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          if (rule.scopeContent)
                            Chip(
                              label: const Text('正文', style: TextStyle(fontSize: 10)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          if (!rule.isRegex)
                            Chip(
                              label: const Text('普通文本', style: TextStyle(fontSize: 10)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // 操作按钮
              if (!isBatchMode) ...[
                CustomSwitch(
                  value: rule.enabled,
                  onChanged: onToggleEnabled,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'top':
                        onMoveToTop?.call();
                        break;
                      case 'bottom':
                        onMoveToBottom?.call();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    if (onMoveToTop != null)
                      const PopupMenuItem(
                        value: 'top',
                        child: Row(
                          children: [
                            Icon(Icons.vertical_align_top, size: 20),
                            SizedBox(width: 8),
                            Text('置顶'),
                          ],
                        ),
                      ),
                    if (onMoveToBottom != null)
                      const PopupMenuItem(
                        value: 'bottom',
                        child: Row(
                          children: [
                            Icon(Icons.vertical_align_bottom, size: 20),
                            SizedBox(width: 8),
                            Text('置底'),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

