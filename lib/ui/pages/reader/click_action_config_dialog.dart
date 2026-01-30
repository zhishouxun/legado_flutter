import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 点击操作配置对话框
/// 参考项目：io.legado.app.ui.book.read.config.ClickActionConfigDialog
class ClickActionConfigDialog extends BaseBottomSheetStateful {
  final VoidCallback? onConfigChanged;

  const ClickActionConfigDialog({
    super.key,
    this.onConfigChanged,
  }) : super(
          title: '点击区域设置',
          heightFactor: 0.8,
        );

  @override
  State<ClickActionConfigDialog> createState() => _ClickActionConfigDialogState();
}

class _ClickActionConfigDialogState extends BaseBottomSheetState<ClickActionConfigDialog> {
  // 点击操作选项
  static const Map<int, String> _actions = {
    -1: '无操作',
    0: '菜单',
    1: '下一页',
    2: '上一页',
    3: '下一章',
    4: '上一章',
    5: '朗读上一段',
    6: '朗读下一段',
    7: '添加书签',
    8: '编辑内容',
    9: '替换状态切换',
    10: '章节列表',
    11: '搜索内容',
    12: '同步阅读进度',
    13: '朗读暂停/继续',
  };

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '点击屏幕的9个区域可以执行不同的操作',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          // 顶部区域
          _buildSectionTitle('顶部区域'),
          _buildActionRow('左上', AppConfig.getClickActionTL(), (value) {
            AppConfig.setClickActionTL(value);
            widget.onConfigChanged?.call();
            setState(() {});
          }),
          _buildActionRow('中上', AppConfig.getClickActionTC(), (value) {
            AppConfig.setClickActionTC(value);
            widget.onConfigChanged?.call();
            setState(() {});
          }),
          _buildActionRow('右上', AppConfig.getClickActionTR(), (value) {
            AppConfig.setClickActionTR(value);
            widget.onConfigChanged?.call();
            setState(() {});
          }),
          const SizedBox(height: 16),
          // 中间区域
          _buildSectionTitle('中间区域'),
          _buildActionRow('左中', AppConfig.getClickActionML(), (value) {
            AppConfig.setClickActionML(value);
            widget.onConfigChanged?.call();
            setState(() {});
          }),
          _buildActionRow('中中', AppConfig.getClickActionMC(), (value) {
            AppConfig.setClickActionMC(value);
            widget.onConfigChanged?.call();
            setState(() {});
          }),
          _buildActionRow('右中', AppConfig.getClickActionMR(), (value) {
            AppConfig.setClickActionMR(value);
            widget.onConfigChanged?.call();
            setState(() {});
          }),
          const SizedBox(height: 16),
          // 底部区域
          _buildSectionTitle('底部区域'),
          _buildActionRow('左下', AppConfig.getClickActionBL(), (value) {
            AppConfig.setClickActionBL(value);
            widget.onConfigChanged?.call();
            setState(() {});
          }),
          _buildActionRow('中下', AppConfig.getClickActionBC(), (value) {
            AppConfig.setClickActionBC(value);
            widget.onConfigChanged?.call();
            setState(() {});
          }),
          _buildActionRow('右下', AppConfig.getClickActionBR(), (value) {
            AppConfig.setClickActionBR(value);
            widget.onConfigChanged?.call();
            setState(() {});
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionRow(String label, int currentValue, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _showActionSelector(label, currentValue, onChanged),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _actions[currentValue] ?? '未知',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionSelector(String label, int currentValue, Function(int) onChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text('选择$label操作', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _actions.entries.map((entry) {
              return RadioListTile<int>(
                title: Text(
                  entry.value,
                  style: TextStyle(
                    color: entry.key == currentValue ? Colors.orange : Colors.white70,
                  ),
                ),
                value: entry.key,
                groupValue: currentValue,
                activeColor: Colors.orange,
                onChanged: (value) {
                  if (value != null) {
                    Navigator.pop(context);
                    onChanged(value);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

