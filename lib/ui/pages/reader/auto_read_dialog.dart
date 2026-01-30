import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../widgets/themed/themed_bottom_sheet.dart';
import '../../widgets/themed/themed_slider.dart';
import '../../widgets/themed/themed_button.dart';
import '../../widgets/themed/themed_constants.dart';

/// 自动阅读对话框（已使用统一主题组件）
/// 参考项目：io.legado.app.ui.book.read.config.AutoReadDialog
class AutoReadDialog extends StatefulWidget {
  final VoidCallback? onShowMenuBar;
  final VoidCallback? onOpenChapterList;
  final VoidCallback? onAutoPageStop;
  final VoidCallback? onSettingsChanged;

  const AutoReadDialog({
    super.key,
    this.onShowMenuBar,
    this.onOpenChapterList,
    this.onAutoPageStop,
    this.onSettingsChanged,
  });

  @override
  State<AutoReadDialog> createState() => _AutoReadDialogState();
}

class _AutoReadDialogState extends State<AutoReadDialog> {
  int _speed = 3;

  @override
  void initState() {
    super.initState();
    _speed = AppConfig.getAutoReadSpeed();
    if (_speed < 1) _speed = 1;
  }

  @override
  Widget build(BuildContext context) {
    return ThemedBottomSheet(
      title: '自动阅读',
      heightFactor: 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 阅读速度设置
          Padding(
            padding: ThemedConstants.paddingAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '阅读速度',
                  style: ThemedConstants.bodyStyle.copyWith(
                    color: ThemedConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: ThemedConstants.spacingSmall),
                ThemedSliderSimple(
                  value: _speed.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  displayValue: '${_speed}s',
                  displayWidth: 50,
                  onChanged: (value) {
                    setState(() {
                      _speed = value.round();
                    });
                  },
                  onChangeEnd: (value) {
                    final speed = value.round();
                    AppConfig.setAutoReadSpeed(speed);
                    widget.onSettingsChanged?.call();
                  },
                ),
              ],
            ),
          ),
          Divider(color: ThemedConstants.dividerColor),
          // 操作按钮
          Padding(
            padding: ThemedConstants.paddingAll,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ThemedIconButton(
                  icon: Icons.menu,
                  label: '主菜单',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onShowMenuBar?.call();
                  },
                ),
                ThemedIconButton(
                  icon: Icons.list,
                  label: '目录',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onOpenChapterList?.call();
                  },
                ),
                ThemedIconButton(
                  icon: Icons.stop,
                  label: '停止',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onAutoPageStop?.call();
                  },
                ),
                ThemedIconButton(
                  icon: Icons.settings,
                  label: '设置',
                  onTap: () {
                    // 可以打开页面动画设置等
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

