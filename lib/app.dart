import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'config/theme_config.dart';
import 'config/app_config.dart';
import 'ui/pages/welcome/welcome_page.dart';
import 'ui/pages/search/search_page.dart';
import 'services/receiver/media_button_handler.dart';
import 'utils/localization_helper.dart';
import 'providers/main_page_index_provider.dart';
import 'providers/book_update_count_provider.dart';
import 'utils/app_log.dart';
import 'services/media/audio_play_service.dart';
import 'services/local_config_service.dart';
import 'services/storage/webdav_service.dart';
import 'services/book/book_service.dart';
import 'data/models/book.dart';
import 'ui/pages/audio/audio_play_page.dart';
import 'ui/pages/book_source/book_source_manage_page.dart';
import 'ui/pages/about/markdown_viewer_page.dart';
import 'ui/dialogs/add_to_bookshelf_dialog.dart';
import 'ui/dialogs/unsupported_file_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'ui/pages/splash_screen.dart';
import 'dart:async';

class LegadoApp extends ConsumerStatefulWidget {
  const LegadoApp({super.key});

  @override
  ConsumerState<LegadoApp> createState() => _LegadoAppState();
}

class _LegadoAppState extends ConsumerState<LegadoApp> {
  Timer? _navigationCheckTimer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // 定期检查pending_navigation配置
    _navigationCheckTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _checkPendingNavigation();
    });
    // 延迟启动初始化，确保UI先显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeOnStart();
    });
  }

  @override
  void dispose() {
    _navigationCheckTimer?.cancel();
    super.dispose();
  }

  /// 启动时初始化
  /// 参考项目：MainActivity.onPostCreate()
  Future<void> _initializeOnStart() async {
    if (_initialized) return;
    _initialized = true;

    // 移除延迟，立即开始初始化（UI已显示，可以立即执行后台任务）

    if (!mounted) return;

    try {
      // 并行执行多个初始化任务，不互相依赖
      Future.wait([
        // 1. 隐私协议（异步执行，不阻塞UI）
        _checkPrivacyPolicy().then((privacyOk) {
          if (!privacyOk && mounted) {
            // 用户拒绝隐私协议，可以显示提示但不退出应用
            AppLog.instance.put('用户拒绝隐私协议');
          }
        }).catchError((e) {
          AppLog.instance.put('检查隐私协议失败', error: e);
        }),

        // 2. 版本更新日志（立即执行）
        () async {
          if (mounted) {
            await _checkVersionUpdate();
          }
        }()
            .catchError((e) {
          AppLog.instance.put('检查版本更新失败', error: e);
        }),

        // 3. 设置本地密码（立即执行）
        () async {
          if (mounted) {
            await _checkLocalPassword();
          }
        }()
            .catchError((e) {
          AppLog.instance.put('检查本地密码失败', error: e);
        }),

        // 4. 崩溃日志通知（立即执行）
        () async {
          if (mounted) {
            await _checkCrashLog();
          }
        }()
            .catchError((e) {
          AppLog.instance.put('检查崩溃日志失败', error: e);
        }),

        // 5. 备份同步（立即执行）
        () async {
          if (mounted) {
            await _checkBackupSync();
          }
        }()
            .catchError((e) {
          AppLog.instance.put('检查备份同步失败', error: e);
        }),

        // 6. 自动更新书籍目录（延迟一点执行，避免影响UI响应）
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (mounted) {
            await _autoRefreshBooks();
          }
        }).catchError((e) {
          AppLog.instance.put('自动更新书籍目录失败', error: e);
        }),
      ]);
    } catch (e) {
      // 初始化失败不影响应用运行
      AppLog.instance.put('启动初始化失败', error: e);
    }
  }

  /// 检查隐私协议
  /// 参考项目：MainActivity.privacyPolicy()
  Future<bool> _checkPrivacyPolicy() async {
    final localConfig = LocalConfigService.instance;
    if (localConfig.privacyPolicyOk) {
      return true;
    }

    // 显示隐私协议对话框
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('隐私政策'),
        content: SingleChildScrollView(
          child: FutureBuilder<String>(
            future: rootBundle.loadString('assets/privacyPolicy.md'),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text(snapshot.data!);
              } else if (snapshot.hasError) {
                return Text('加载隐私政策失败: ${snapshot.error}');
              } else {
                return const CircularProgressIndicator();
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('拒绝'),
          ),
          TextButton(
            onPressed: () async {
              await localConfig.setPrivacyPolicyOk(true);
              Navigator.of(context).pop(true);
            },
            child: const Text('同意'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// 检查版本更新
  /// 参考项目：MainActivity.upVersion()
  Future<void> _checkVersionUpdate() async {
    final localConfig = LocalConfigService.instance;
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    final savedVersionCode = localConfig.versionCode;

    if (currentVersionCode == savedVersionCode) {
      return;
    }

    // 更新保存的版本号
    await localConfig.setVersionCode(currentVersionCode);

    if (!mounted) return;

    // 首次打开应用，显示帮助文档
    if (localConfig.isFirstOpenApp) {
      await _showHelpDialog();
      return;
    }

    // 非调试模式，显示更新日志
    // 注意：Flutter中需要从环境变量判断是否为调试模式
    // 这里暂时总是显示更新日志
    await _showUpdateLogDialog();
  }

  /// 显示帮助对话框
  Future<void> _showHelpDialog() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MarkdownViewerPage(
          title: '帮助',
          assetPath: 'assets/web/help/md/appHelp.md',
        ),
      ),
    );
  }

  /// 显示更新日志对话框
  Future<void> _showUpdateLogDialog() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MarkdownViewerPage(
          title: '更新日志',
          assetPath: 'assets/updateLog.md',
        ),
      ),
    );
  }

  /// 检查本地密码
  /// 参考项目：MainActivity.setLocalPassword()
  Future<void> _checkLocalPassword() async {
    final localConfig = LocalConfigService.instance;
    if (localConfig.password != null) {
      return;
    }

    if (!mounted) return;

    final controller = TextEditingController();
    String? result;
    try {
      result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('设置本地密码'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'password',
                labelText: '本地密码',
              ),
              obscureText: true,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop('');
                },
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(controller.text);
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    } finally {
      // 确保在对话框关闭后清理 controller，避免 UndoHistoryState 断言失败
      controller.dispose();
    }

    if (result != null) {
      await localConfig.setPassword(result.isEmpty ? null : result);
    }
  }

  /// 检查崩溃日志
  /// 参考项目：MainActivity.notifyAppCrash()
  Future<void> _checkCrashLog() async {
    // 注意：这里需要从LocalConfig中读取appCrash标志
    // 暂时不实现，因为需要修改LocalConfigService
    // TODO: 实现崩溃日志检查
  }

  /// 检查备份同步
  /// 参考项目：MainActivity.backupSync()
  Future<void> _checkBackupSync() async {
    if (!AppConfig.getAutoCheckNewBackup()) {
      return;
    }

    try {
      final webDavService = WebDavService.instance;
      await webDavService.loadConfig();

      if (!webDavService.isConfigured) {
        return;
      }

      final lastBackupFile = await webDavService.getLastBackup();
      if (lastBackupFile == null) {
        return;
      }

      final localConfig = LocalConfigService.instance;
      final lastBackupTime = localConfig.lastBackup;
      final cloudTime = lastBackupFile.lastModified.millisecondsSinceEpoch;

      // 检查云端备份是否比本地新（超过1分钟）
      if (cloudTime - lastBackupTime > 60 * 1000) {
        await localConfig.setLastBackup(cloudTime);

        if (!mounted) return;

        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('恢复'),
            content: const Text('检测到WebDAV中有新的备份，是否恢复？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确定'),
              ),
            ],
          ),
        );

        if (result == true && mounted) {
          // 导航到备份恢复页面
          // TODO: 实现备份恢复功能
        }
      }
    } catch (e) {
      // 备份检查失败不影响应用运行
      AppLog.instance.put('备份同步检查失败', error: e);
    }
  }

  /// 自动更新书籍目录
  /// 参考项目：MainActivity.onPostCreate() -> viewModel.upAllBookToc()
  Future<void> _autoRefreshBooks() async {
    if (!AppConfig.getAutoRefresh()) {
      return;
    }

    // 延迟执行，避免影响启动速度（优化：减少延迟时间）
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      // 获取所有可更新的书籍
      final allBooks = await BookService.instance.getBookshelfBooks();
      final booksToUpdate =
          allBooks.where((book) => !book.isLocal && book.canUpdate).toList();

      if (booksToUpdate.isEmpty) {
        return;
      }

      // 在后台更新目录（不阻塞UI）
      // 直接在后台执行，不等待完成
      _updateBooksInBackground(booksToUpdate);
    } catch (e) {
      AppLog.instance.put('自动更新书籍目录失败', error: e);
    }
  }

  /// 在后台更新书籍目录
  /// 不阻塞UI，静默执行
  Future<void> _updateBooksInBackground(List<Book> books) async {
    try {
      // 在后台执行更新任务
      final results = await BookService.instance.updateChapterLists(books);

      final successCount = results.values.where((v) => v == true).length;
      final failCount = results.length - successCount;

      AppLog.instance.put('自动更新书籍目录完成: 成功 $successCount 本，失败 $failCount 本');

      // 更新完成后，刷新更新数量Badge
      if (mounted) {
        // 使用 WidgetsBinding 确保在正确的上下文中执行
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 刷新更新数量Badge
          if (mounted) {
            ref.read(bookUpdateCountProvider.notifier).refresh();
          }
        });
      }
    } catch (e) {
      AppLog.instance.put('后台更新书籍目录失败', error: e);
    }
  }

  Future<void> _checkPendingNavigation() async {
    try {
      final pendingNav = AppConfig.getString('pending_navigation');
      if (pendingNav.isEmpty) {
        return;
      }

      // 清除pending_navigation，避免重复处理
      await AppConfig.setString('pending_navigation', '');

      if (!mounted) return;

      final navigator = Navigator.of(context);

      switch (pendingNav) {
        case 'search':
          final searchText = AppConfig.getString('pending_search_text');
          await AppConfig.setString('pending_search_text', '');
          navigator.push(
            MaterialPageRoute(
              builder: (context) => SearchPage(
                initialKeyword: searchText.isNotEmpty ? searchText : null,
              ),
            ),
          );
          break;

        case 'bookshelf':
          // 导航到书架（已经是主页面，不需要额外操作）
          // 可以通过Provider切换到书架tab
          ref.read(mainPageIndexProvider.notifier).switchToBookshelf();
          break;

        case 'read':
          // 阅读页面导航需要书籍URL，暂时不处理
          break;

        case 'readAloud':
          // 启动朗读功能（通过媒体按钮处理器）
          MediaButtonHandler.instance.startReadAloud(isMediaKey: false);
          break;

        case 'web_service':
          // 导航到Web服务页面（我的页面中的Web服务设置）
          ref.read(mainPageIndexProvider.notifier).switchToMy();
          // TODO: 可以进一步导航到Web服务设置页面
          break;

        case 'book_source':
          // 导航到书源管理页面
          ref.read(mainPageIndexProvider.notifier).switchToMy();
          // 延迟导航，确保页面已切换
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            navigator.push(
              MaterialPageRoute(
                builder: (context) => const BookSourceManagePage(),
              ),
            );
          }
          break;

        case 'download':
          // 下载完成，可以打开文件
          final downloadPath = AppConfig.getString('pending_download_path');
          await AppConfig.setString('pending_download_path', '');
          if (downloadPath.isNotEmpty) {
            try {
              // 使用 open_filex 打开文件
              final result = await OpenFilex.open(downloadPath);
              if (result.type != ResultType.done) {
                AppLog.instance.put('无法打开文件: ${result.message}');
              } else {
                AppLog.instance.put('打开下载文件: $downloadPath');
              }
            } catch (e) {
              AppLog.instance.put('打开文件失败: $downloadPath', error: e);
            }
          }
          break;

        case 'audio_play':
          // 导航到音频播放页面
          try {
            final audioService = AudioPlayService.instance;
            final currentBook = audioService.currentBook;
            if (currentBook != null) {
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => AudioPlayPage(book: currentBook),
                ),
              );
            } else {
              AppLog.instance.put('没有正在播放的音频书籍');
            }
          } catch (e) {
            AppLog.instance.put('导航到音频播放页面失败', error: e);
          }
          break;

        case 'addToBookshelf':
          // 显示添加到书架对话框
          final bookUrl = AppConfig.getString('pending_book_url');
          await AppConfig.setString('pending_book_url', '');
          if (bookUrl.isNotEmpty) {
            try {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AddToBookshelfDialog(
                  bookUrl: bookUrl,
                  finishOnDismiss: false,
                ),
              );
            } catch (e) {
              AppLog.instance.put('显示添加到书架对话框失败', error: e);
            }
          }
          break;

        case 'unsupported_file':
          // 显示不支持的文件类型对话框
          final fileName = AppConfig.getString('pending_unsupported_file_name');
          final fileExtension =
              AppConfig.getString('pending_unsupported_file_extension');
          await AppConfig.setString('pending_unsupported_file_name', '');
          await AppConfig.setString('pending_unsupported_file_extension', '');
          if (fileName.isNotEmpty) {
            try {
              await UnsupportedFileDialog.show(
                context,
                fileName,
                fileExtension: fileExtension.isNotEmpty ? fileExtension : null,
              );
            } catch (e) {
              AppLog.instance.put('显示不支持文件类型对话框失败', error: e);
            }
          }
          break;
      }
    } catch (e) {
      // 忽略错误
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = ref.watch(appThemeProvider);
    final localizationHelper = LocalizationHelper.instance;

    return MaterialApp(
      title: 'Legado',
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: themeMode,
      locale: localizationHelper.getCurrentLocale(),
      supportedLocales: LocalizationHelper.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // 应用字体缩放
        final mediaQuery = MediaQuery.of(context);
        final textScaleFactor = localizationHelper.getTextScaleFactor();
        return MediaQuery(
          data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        );
      },
      home: SplashScreen(home: const WelcomePage()),
    );
  }
}
