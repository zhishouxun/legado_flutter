import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 漫画电子墨水设置对话框
/// 参考项目：MangaEpaperDialog.kt
class MangaEpaperDialog extends BaseBottomSheetStateful {
  final Function(int)? onThresholdChanged;

  const MangaEpaperDialog({
    super.key,
    this.onThresholdChanged,
  }) : super(
          title: '电子墨水',
          heightFactor: 0.4,
        );

  @override
  State<MangaEpaperDialog> createState() => _MangaEpaperDialogState();
}

class _MangaEpaperDialogState extends BaseBottomSheetState<MangaEpaperDialog> {
  late int _threshold;

  @override
  void initState() {
    super.initState();
    _threshold = AppConfig.getMangaEInkThreshold();
  }

  void _updateThreshold() {
    // 保存配置
    AppConfig.setMangaEInkThreshold(_threshold);
    // 通知回调
    widget.onThresholdChanged?.call(_threshold);
  }

  @override
  Widget buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '二值化阈值',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0'),
              Expanded(
                child: Slider(
                  value: _threshold.toDouble(),
                  min: 0,
                  max: 255,
                  divisions: 255,
                  label: _threshold.toString(),
                  onChanged: (value) {
                    setState(() {
                      _threshold = value.round();
                      _updateThreshold();
                    });
                  },
                ),
              ),
              const Text('255'),
            ],
          ),
          Center(
            child: Text(
              '当前值: $_threshold',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '说明：低于此值的像素变为黑色，高于此值的像素变为白色。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
