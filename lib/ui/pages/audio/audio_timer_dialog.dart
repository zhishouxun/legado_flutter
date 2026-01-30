import 'package:flutter/material.dart';
import '../../widgets/base/base_dialog.dart';

/// 定时停止对话框
class AudioTimerDialog extends BaseDialog {
  final int currentTimer;
  final ValueChanged<int> onTimerSelected;

  const AudioTimerDialog({
    super.key,
    required this.currentTimer,
    required this.onTimerSelected,
  }) : super(
          title: '定时停止',
          widthFactor: 0.9,
          maxWidth: 400,
        );

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTimerOption(context, 0, '关闭'),
        _buildTimerOption(context, 15, '15分钟'),
        _buildTimerOption(context, 30, '30分钟'),
        _buildTimerOption(context, 45, '45分钟'),
        _buildTimerOption(context, 60, '60分钟'),
        _buildTimerOption(context, 90, '90分钟'),
        _buildTimerOption(context, 120, '120分钟'),
      ],
    );
  }

  Widget _buildTimerOption(BuildContext context, int minutes, String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<int>(
        value: minutes,
        groupValue: currentTimer,
        onChanged: (value) {
          if (value != null) {
            onTimerSelected(value);
          }
        },
      ),
      onTap: () {
        onTimerSelected(minutes);
        Navigator.pop(context);
      },
    );
  }
}

