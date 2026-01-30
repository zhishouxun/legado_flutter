import 'package:flutter/material.dart';
import '../../../data/models/manga_footer_config.dart';
import '../../../config/app_config.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 漫画页脚设置对话框
/// 参考项目：MangaFooterSettingDialog.kt
class MangaFooterSettingDialog extends BaseBottomSheetStateful {
  final Function(MangaFooterConfig)? onConfigChanged;

  const MangaFooterSettingDialog({
    super.key,
    this.onConfigChanged,
  }) : super(
          title: '页脚设置',
          heightFactor: 0.7,
        );

  @override
  State<MangaFooterSettingDialog> createState() =>
      _MangaFooterSettingDialogState();
}

class _MangaFooterSettingDialogState
    extends BaseBottomSheetState<MangaFooterSettingDialog> {
  late MangaFooterConfig _config;

  @override
  void initState() {
    super.initState();
    final configStr = AppConfig.getMangaFooterConfig();
    _config = MangaFooterConfig.fromJsonString(configStr);
  }

  void _updateConfig() {
    // 保存配置
    AppConfig.setMangaFooterConfig(_config.toJsonString());
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
          // 显示/隐藏页脚
          _buildSection(
            title: '页脚显示',
            children: [
              RadioListTile<bool>(
                title: const Text('显示'),
                value: false,
                groupValue: _config.hideFooter,
                onChanged: (value) {
                  setState(() {
                    _config.hideFooter = false;
                    _updateConfig();
                  });
                },
              ),
              RadioListTile<bool>(
                title: const Text('隐藏'),
                value: true,
                groupValue: _config.hideFooter,
                onChanged: (value) {
                  setState(() {
                    _config.hideFooter = true;
                    _updateConfig();
                  });
                },
              ),
            ],
          ),
          const Divider(),
          // 页脚对齐方式
          _buildSection(
            title: '对齐方式',
            children: [
              RadioListTile<int>(
                title: const Text('左对齐'),
                value: MangaFooterAlignment.left,
                groupValue: _config.footerOrientation,
                onChanged: (value) {
                  setState(() {
                    _config.footerOrientation = value!;
                    _updateConfig();
                  });
                },
              ),
              RadioListTile<int>(
                title: const Text('居中'),
                value: MangaFooterAlignment.center,
                groupValue: _config.footerOrientation,
                onChanged: (value) {
                  setState(() {
                    _config.footerOrientation = value!;
                    _updateConfig();
                  });
                },
              ),
            ],
          ),
          const Divider(),
          // 显示选项
          _buildSection(
            title: '显示选项',
            children: [
              CheckboxListTile(
                title: const Text('章节标签'),
                value: !_config.hideChapterLabel,
                onChanged: (value) {
                  setState(() {
                    _config.hideChapterLabel = !value!;
                    _updateConfig();
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('章节号'),
                value: !_config.hideChapter,
                onChanged: (value) {
                  setState(() {
                    _config.hideChapter = !value!;
                    _updateConfig();
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('页码标签'),
                value: !_config.hidePageNumberLabel,
                onChanged: (value) {
                  setState(() {
                    _config.hidePageNumberLabel = !value!;
                    _updateConfig();
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('页码'),
                value: !_config.hidePageNumber,
                onChanged: (value) {
                  setState(() {
                    _config.hidePageNumber = !value!;
                    _updateConfig();
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('进度比例标签'),
                value: !_config.hideProgressRatioLabel,
                onChanged: (value) {
                  setState(() {
                    _config.hideProgressRatioLabel = !value!;
                    _updateConfig();
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('进度比例'),
                value: !_config.hideProgressRatio,
                onChanged: (value) {
                  setState(() {
                    _config.hideProgressRatio = !value!;
                    _updateConfig();
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('章节名称'),
                value: !_config.hideChapterName,
                onChanged: (value) {
                  setState(() {
                    _config.hideChapterName = !value!;
                    _updateConfig();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
