import 'package:flutter/material.dart';
import '../../../data/models/manga_color_filter_config.dart';
import '../../../config/app_config.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 漫画颜色滤镜设置对话框
/// 参考项目：MangaColorFilterDialog.kt
class MangaColorFilterDialog extends BaseBottomSheetStateful {
  final Function(MangaColorFilterConfig)? onConfigChanged;

  const MangaColorFilterDialog({
    super.key,
    this.onConfigChanged,
  }) : super(
          title: '颜色滤镜',
          heightFactor: 0.6,
        );

  @override
  State<MangaColorFilterDialog> createState() => _MangaColorFilterDialogState();
}

class _MangaColorFilterDialogState
    extends BaseBottomSheetState<MangaColorFilterDialog> {
  late MangaColorFilterConfig _config;

  @override
  void initState() {
    super.initState();
    final configStr = AppConfig.getMangaColorFilter();
    _config = MangaColorFilterConfig.fromJsonString(configStr);
  }

  void _updateConfig() {
    // 保存配置
    AppConfig.setMangaColorFilter(_config.toJsonString());
    // 通知回调
    widget.onConfigChanged?.call(_config);
  }

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 亮度
          _buildSlider(
            label: '亮度',
            value: _config.l.toDouble(),
            min: -100,
            max: 100,
            onChanged: (value) {
              setState(() {
                _config.l = value.round();
                _updateConfig();
              });
            },
          ),
          const SizedBox(height: 16),
          // 红色
          _buildSlider(
            label: '红色',
            value: _config.r.toDouble(),
            min: -100,
            max: 100,
            onChanged: (value) {
              setState(() {
                _config.r = value.round();
                _updateConfig();
              });
            },
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          // 绿色
          _buildSlider(
            label: '绿色',
            value: _config.g.toDouble(),
            min: -100,
            max: 100,
            onChanged: (value) {
              setState(() {
                _config.g = value.round();
                _updateConfig();
              });
            },
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          // 蓝色
          _buildSlider(
            label: '蓝色',
            value: _config.b.toDouble(),
            min: -100,
            max: 100,
            onChanged: (value) {
              setState(() {
                _config.b = value.round();
                _updateConfig();
              });
            },
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          // 透明度
          _buildSlider(
            label: '透明度',
            value: _config.a.toDouble(),
            min: -100,
            max: 100,
            onChanged: (value) {
              setState(() {
                _config.a = value.round();
                _updateConfig();
              });
            },
          ),
          const SizedBox(height: 24),
          // 重置按钮
          Center(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _config = MangaColorFilterConfig();
                  _updateConfig();
                });
              },
              child: const Text('重置'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              value.round().toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          label: value.round().toString(),
          onChanged: onChanged,
          activeColor: color,
        ),
      ],
    );
  }
}
