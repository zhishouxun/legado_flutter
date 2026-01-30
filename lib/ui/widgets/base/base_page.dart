import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_config.dart';
import '../../../utils/app_log.dart';
import '../../../utils/eink_theme.dart';

/// 基础页面 Widget
/// 统一处理页面主题、系统栏、背景图片等
/// 参考项目：BaseActivity.kt
abstract class BasePage extends StatefulWidget {
  /// 是否全屏
  final bool fullScreen;

  /// 是否显示背景图片
  final bool showBackgroundImage;

  /// 自定义背景图片路径
  final String? backgroundImagePath;

  const BasePage({
    super.key,
    this.fullScreen = false,
    this.showBackgroundImage = false,
    this.backgroundImagePath,
  });
}

/// 基础页面状态
abstract class BasePageState<T extends BasePage> extends State<T>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupSystemUI();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreSystemUI();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _setupSystemUI();
    }
  }

  /// 设置系统 UI（状态栏、导航栏等）
  void _setupSystemUI() {
    if (!widget.fullScreen) return;

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  /// 恢复系统 UI
  void _restoreSystemUI() {
    if (!widget.fullScreen) return;

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  /// 构建页面内容
  Widget buildContent(BuildContext context);

  /// 构建背景装饰
  Widget? buildBackgroundDecoration(BuildContext context) {
    if (!widget.showBackgroundImage) return null;

    String? imagePath = widget.backgroundImagePath;
    imagePath ??= AppConfig.getString('bg_image', defaultValue: '');

    if (imagePath.isEmpty) return null;

    // 这里可以根据路径类型（asset 或 file）加载图片
    // 简化实现，实际使用时需要根据路径判断
    return Container(
      decoration: BoxDecoration(
        image: imagePath.startsWith('assets/')
            ? DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
                opacity: 0.3,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundDecoration = buildBackgroundDecoration(context);

    Widget content = buildContent(context);

    if (backgroundDecoration != null && !EInkTheme.isEInkMode) {
      // 电子墨水模式下不显示背景图片
      content = Stack(
        children: [
          backgroundDecoration,
          content,
        ],
      );
    }

    return Scaffold(
      body: content,
      backgroundColor: EInkTheme.getBackgroundColor(context),
    );
  }

  /// 隐藏软键盘
  void hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  /// 显示提示消息
  void showMessage(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  /// 显示错误消息
  void showError(String message, {Object? error}) {
    if (error != null) {
      AppLog.instance.put(message, error: error);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 显示成功消息
  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// 基础页面 Widget（无状态版本）
abstract class BaseStatelessPage extends StatelessWidget {
  /// 是否全屏
  final bool fullScreen;

  /// 是否显示背景图片
  final bool showBackgroundImage;

  /// 自定义背景图片路径
  final String? backgroundImagePath;

  const BaseStatelessPage({
    super.key,
    this.fullScreen = false,
    this.showBackgroundImage = false,
    this.backgroundImagePath,
  });

  /// 构建页面内容
  Widget buildContent(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildContent(context),
      backgroundColor: EInkTheme.getBackgroundColor(context),
    );
  }
}
