import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';
import '../../widgets/common/custom_switch.dart';
import 'auto_read_dialog.dart';
import 'click_action_config_dialog.dart';
import 'page_key_dialog.dart';

/// 更多设置对话框
class MoreSettingsDialog extends BaseBottomSheetStateful {
  final VoidCallback? onSettingsChanged;

  const MoreSettingsDialog({
    super.key,
    this.onSettingsChanged,
  }) : super(
          title: '更多设置',
          heightFactor: 0.7,
        );

  @override
  State<MoreSettingsDialog> createState() => _MoreSettingsDialogState();
}

class _MoreSettingsDialogState extends BaseBottomSheetState<MoreSettingsDialog> {
  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('屏幕设置'),
          _buildScreenOrientationSetting(),
          _buildKeepLightSetting(),
          _buildHideStatusBarSetting(),
          _buildHideNavigationBarSetting(),
          const SizedBox(height: 24),
          _buildSectionTitle('阅读设置'),
          _buildTextSelectableSetting(),
          _buildShowBrightnessViewSetting(),
          _buildVolumeKeyPageSetting(),
          _buildMouseWheelPageSetting(),
          const SizedBox(height: 24),
          _buildSectionTitle('其他设置'),
          _buildAutoChangeSourceSetting(),
          _buildDisableReturnKeySetting(),
          _buildAutoReadSetting(),
          _buildClickActionConfigSetting(),
          _buildPageKeyConfigSetting(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
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

  /// 屏幕方向设置
  Widget _buildScreenOrientationSetting() {
    final currentValue =
        AppConfig.getInt('screen_orientation', defaultValue: 0);
    const options = ['跟随系统', '竖屏', '横屏', '自动旋转'];
    const values = [0, 1, 2, 3];

    return _buildListTile(
      title: '屏幕方向',
      subtitle: options[values.indexOf(currentValue)],
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: const Text('选择屏幕方向', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.asMap().entries.map((entry) {
                return RadioListTile<int>(
                  title: Text(entry.value,
                      style: const TextStyle(color: Colors.white70)),
                  value: values[entry.key],
                  groupValue: currentValue,
                  activeColor: Colors.orange,
                  onChanged: (value) {
                    if (value != null) {
                      AppConfig.setInt('screen_orientation', value);
                      setState(() {});
                      Navigator.pop(context);
                      widget.onSettingsChanged?.call();
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// 保持屏幕常亮
  Widget _buildKeepLightSetting() {
    final currentValue = AppConfig.getInt('keep_light', defaultValue: 0);
    const options = ['跟随系统', '常亮', '30秒', '1分钟', '5分钟', '10分钟', '30分钟'];
    const values = [0, -1, 30, 60, 300, 600, 1800];

    return _buildListTile(
      title: '保持屏幕常亮',
      subtitle: options[values.indexOf(currentValue)],
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title:
                const Text('选择屏幕常亮时间', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.asMap().entries.map((entry) {
                return RadioListTile<int>(
                  title: Text(entry.value,
                      style: const TextStyle(color: Colors.white70)),
                  value: values[entry.key],
                  groupValue: currentValue,
                  activeColor: Colors.orange,
                  onChanged: (value) {
                    if (value != null) {
                      AppConfig.setInt('keep_light', value);
                      setState(() {});
                      Navigator.pop(context);
                      widget.onSettingsChanged?.call();
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// 隐藏状态栏
  Widget _buildHideStatusBarSetting() {
    final value = AppConfig.getBool('hide_status_bar', defaultValue: false);
    return _buildSwitchTile(
      title: '隐藏状态栏',
      value: value,
      onChanged: (newValue) {
        setState(() {
          AppConfig.setBool('hide_status_bar', newValue);
        });
        widget.onSettingsChanged?.call();
      },
    );
  }

  /// 隐藏导航栏
  Widget _buildHideNavigationBarSetting() {
    final value = AppConfig.getBool('hide_navigation_bar', defaultValue: false);
    return _buildSwitchTile(
      title: '隐藏导航栏',
      value: value,
      onChanged: (newValue) {
        setState(() {
          AppConfig.setBool('hide_navigation_bar', newValue);
        });
        widget.onSettingsChanged?.call();
      },
    );
  }

  /// 文本可选择
  Widget _buildTextSelectableSetting() {
    final value = AppConfig.getBool('select_text', defaultValue: true);
    return _buildSwitchTile(
      title: '长按选择文本',
      value: value,
      onChanged: (newValue) {
        setState(() {
          AppConfig.setBool('select_text', newValue);
        });
        widget.onSettingsChanged?.call();
      },
    );
  }

  /// 显示亮度控制
  Widget _buildShowBrightnessViewSetting() {
    final value = AppConfig.getBool('show_brightness_view', defaultValue: true);
    return _buildSwitchTile(
      title: '显示亮度控制',
      value: value,
      onChanged: (newValue) {
        setState(() {
          AppConfig.setBool('show_brightness_view', newValue);
        });
        // 亮度控制显示设置已实现，通过onSettingsChanged回调触发UI更新
        widget.onSettingsChanged?.call();
      },
    );
  }

  /// 音量键翻页
  Widget _buildVolumeKeyPageSetting() {
    final value = AppConfig.getVolumeKeyPage();
    return _buildSwitchTile(
      title: '音量键翻页',
      value: value,
      onChanged: (newValue) {
        setState(() {
          AppConfig.setVolumeKeyPage(newValue);
        });
        // 音量键翻页设置已实现，通过RawKeyboardListener自动响应配置变化
        widget.onSettingsChanged?.call();
      },
    );
  }

  /// 鼠标滚轮翻页
  Widget _buildMouseWheelPageSetting() {
    final value = AppConfig.getBool('mouse_wheel_page', defaultValue: true);
    return _buildSwitchTile(
      title: '鼠标滚轮翻页',
      value: value,
      onChanged: (newValue) {
        setState(() {
          AppConfig.setBool('mouse_wheel_page', newValue);
        });
        // 鼠标滚轮翻页设置已实现，通过Listener的onPointerSignal自动响应配置变化
        widget.onSettingsChanged?.call();
      },
    );
  }

  /// 自动切换书源
  Widget _buildAutoChangeSourceSetting() {
    final value = AppConfig.getBool('auto_change_source', defaultValue: true);
    return _buildSwitchTile(
      title: '自动切换书源',
      value: value,
      onChanged: (newValue) {
        setState(() {
          AppConfig.setBool('auto_change_source', newValue);
        });
      },
    );
  }

  /// 禁用返回键
  Widget _buildDisableReturnKeySetting() {
    final value = AppConfig.getBool('disable_return_key', defaultValue: false);
    return _buildSwitchTile(
      title: '禁用返回键',
      value: value,
      onChanged: (newValue) {
        setState(() {
          AppConfig.setBool('disable_return_key', newValue);
        });
        // 返回键设置需要在WillPopScope中处理，这里只保存配置
        // 实际应用需要在ReaderPage的WillPopScope中检查配置
        widget.onSettingsChanged?.call();
      },
    );
  }

  /// 自动阅读设置
  Widget _buildAutoReadSetting() {
    return _buildListTile(
      title: '自动阅读',
      subtitle: '设置自动翻页速度',
      onTap: () {
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => AutoReadDialog(
            onShowMenuBar: () {
              // 显示主菜单
            },
            onOpenChapterList: () {
              // 打开章节列表
            },
            onAutoPageStop: () {
              // 停止自动翻页
            },
            onSettingsChanged: () {
              widget.onSettingsChanged?.call();
            },
          ),
        );
      },
    );
  }

  /// 点击区域设置
  Widget _buildClickActionConfigSetting() {
    return _buildListTile(
      title: '点击区域设置',
      subtitle: '配置9个点击区域的操作',
      onTap: () {
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => ClickActionConfigDialog(
            onConfigChanged: () {
              widget.onSettingsChanged?.call();
            },
          ),
        );
      },
    );
  }

  /// 自定义翻页按键设置
  Widget _buildPageKeyConfigSetting() {
    return _buildListTile(
      title: '自定义翻页按键',
      subtitle: '配置翻页快捷键',
      onTap: () {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) => const PageKeyDialog(),
        );
      },
    );
  }

  /// 构建列表项
  Widget _buildListTile({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            )
          : null,
      trailing:
          const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  /// 构建开关项
  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      trailing: CustomSwitch(
        value: value,
        onChanged: onChanged,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
