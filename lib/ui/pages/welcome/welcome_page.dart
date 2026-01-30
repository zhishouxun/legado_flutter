import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_config.dart';
import '../../../core/constants/prefer_key.dart';
import '../../../services/book/book_service.dart';
import '../../../utils/app_log.dart';
import '../reader/reader_page.dart';
import '../main/main_page.dart';

/// 欢迎页（启动页）
/// 参考项目：io.legado.app.ui.welcome.WelcomeActivity
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _imagePath;
  bool _showText = true;
  bool _showIcon = true;
  bool _hasNavigated = false; // 防止重复导航
  Timer? _startTimer; // 用于启动导航的计时器

  @override
  void initState() {
    super.initState();
    // 添加生命周期观察者，确保应用在后台时也能正常启动
    WidgetsBinding.instance.addObserver(this);
    _loadWelcomeConfig();
    // 使用 Timer 代替 Future.delayed，确保在后台时也能触发
    _scheduleNavigation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startTimer?.cancel();
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// 监听应用生命周期状态变化
  /// 解决问题：macOS 上窗口不在前台时启动页面会卡住
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当应用恢复活跃状态时，如果还没有导航，立即执行导航
    if (state == AppLifecycleState.resumed && !_hasNavigated) {
      _startMainActivity();
    }
  }

  /// 调度导航
  /// 使用 Timer 代替 Future.delayed，确保即使窗口不在前台也能触发
  void _scheduleNavigation() {
    // 减少延迟时间，加快启动速度（从300ms减少到100ms）
    // 使用 Timer 而不是 Future.delayed
    // Timer 基于事件循环，不受 UI 线程暂停影响
    _startTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && !_hasNavigated) {
        _startMainActivity();
      }
    });
  }

  /// 加载欢迎页配置
  void _loadWelcomeConfig() {
    final customWelcome =
        AppConfig.getBool(PreferKey.customWelcome, defaultValue: false);

    if (customWelcome) {
      // 根据当前主题选择图片
      final brightness = MediaQuery.of(context).platformBrightness;
      final isDark = brightness == Brightness.dark;

      if (isDark) {
        _imagePath = AppConfig.getWelcomeImageDark();
        _showText = AppConfig.getWelcomeShowTextDark();
        _showIcon = AppConfig.getWelcomeShowIconDark();
      } else {
        _imagePath = AppConfig.getWelcomeImage();
        _showText = AppConfig.getWelcomeShowText();
        _showIcon = AppConfig.getWelcomeShowIcon();
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// 启动主Activity
  /// 参考项目：WelcomeActivity.startMainActivity
  Future<void> _startMainActivity() async {
    // 防止重复导航
    if (_hasNavigated) return;
    if (!mounted) return;

    _hasNavigated = true;

    // 检查是否配置了默认打开阅读
    final defaultToRead =
        AppConfig.getBool(PreferKey.defaultToRead, defaultValue: false);

    if (defaultToRead) {
      // 获取最后阅读的书籍（优化：使用超时，避免长时间阻塞）
      try {
        final lastReadBook = await BookService.instance
            .getLastReadBook()
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
        if (lastReadBook != null && mounted) {
          // 直接打开阅读页面
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ReaderPage(book: lastReadBook),
            ),
          );
          return;
        }
      } catch (e) {
        // 获取失败，继续跳转到主页面
        AppLog.instance.put('获取最后阅读书籍失败', error: e);
      }
    }

    // 跳转到主页面
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 设置全屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      body: _buildWelcomeContent(isDark),
    );
  }

  /// 构建欢迎页内容
  Widget _buildWelcomeContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 如果有自定义背景图片
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // 背景图片
          Image.file(
            File(_imagePath!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 图片加载失败，使用默认背景
              return _buildDefaultBackground(isDark);
            },
          ),
          // 内容层
          if (_showText || _showIcon) _buildContentOverlay(isDark),
        ],
      );
    }

    // 默认背景
    return _buildDefaultBackground(isDark);
  }

  /// 构建默认背景
  Widget _buildDefaultBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  Colors.grey[900]!,
                  Colors.black,
                ]
              : [
                  Colors.blue[50]!,
                  Colors.blue[100]!,
                ],
        ),
      ),
      child: _buildContentOverlay(isDark),
    );
  }

  /// 构建内容覆盖层
  Widget _buildContentOverlay(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_showIcon) ...[
            Icon(
              Icons.menu_book,
              size: 80,
              color: isDark ? Colors.white70 : Colors.blue[700],
            ),
            const SizedBox(height: 24),
          ],
          if (_showText) ...[
            Text(
              'Legado',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.blue[900],
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 3,
              decoration: BoxDecoration(
                color: isDark ? Colors.white70 : Colors.blue[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '开源阅读',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.blue[800],
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
