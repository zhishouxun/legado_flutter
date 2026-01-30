import '../../core/base/base_service.dart';
import '../../config/app_config.dart';
import '../../core/constants/prefer_key.dart';
import '../../utils/app_log.dart';
import '../media/audio_play_service.dart' show AudioPlayService, PlayStatus;
import '../media/tts_service.dart';
import '../book/book_service.dart';
import '../book/local_book_service.dart';
import '../source/book_source_service.dart';
import 'reader_controller.dart';

/// 媒体按钮处理器
/// 参考项目：io.legado.app.receiver.MediaButtonReceiver
class MediaButtonHandler extends BaseService {
  static final MediaButtonHandler instance = MediaButtonHandler._init();
  MediaButtonHandler._init();

  // AudioHandler需要完整的audio_service集成，暂时注释
  // AudioHandler? _audioHandler;

  /// 初始化媒体按钮监听
  /// 参考项目：MediaButtonReceiver注册
  @override
  Future<void> onInit() async {
    try {
      // 使用audio_service实现媒体按钮监听
      // 注意：audio_service需要配置AudioHandler，这里提供基础框架
      // 完整的实现需要创建自定义AudioHandler类
      AppLog.instance.put('媒体按钮处理器已初始化');
    } catch (e) {
      AppLog.instance.put('初始化媒体按钮处理器失败: $e', error: e);
    }
  }

  /// 处理媒体按钮事件
  /// 参考项目：MediaButtonReceiver.handleIntent()
  ///
  /// [button] 媒体按钮类型
  /// [isMediaKey] 是否为媒体键
  ///
  /// 返回 true 表示已处理该事件，false 表示未处理或处理失败
  Future<bool> handleMediaButton(MediaButton button,
      {bool isMediaKey = true}) async {
    try {
      // 检查配置：readAloudByMediaButton
      if (isMediaKey && !AppConfig.getReadAloudByMediaButton()) {
        AppLog.instance.put('媒体按钮功能已禁用（readAloudByMediaButton=false）');
        return false;
      }

      switch (button) {
        case MediaButton.skipToPrevious:
          // 上一章/上一段
          return await _handlePrevious();

        case MediaButton.skipToNext:
          // 下一章/下一段
          return await _handleNext();

        case MediaButton.play:
        case MediaButton.pause:
        case MediaButton.playPause:
          // 播放/暂停
          return await _handlePlayPause(isMediaKey);

        case MediaButton.stop:
          // 停止播放/朗读
          return await _handleStop();
      }
    } catch (e) {
      AppLog.instance.put('处理媒体按钮失败: $button', error: e);
      return false;
    }
  }

  /// 处理停止按钮
  Future<bool> _handleStop() async {
    try {
      // 停止TTS朗读
      if (TtsService.instance.isSpeaking) {
        await TtsService.instance.stop();
        AppLog.instance.put('通过媒体按钮停止TTS朗读');
        return true;
      }

      // 停止音频播放
      if (AudioPlayService.instance.status == PlayStatus.playing ||
          AudioPlayService.instance.status == PlayStatus.paused) {
        await AudioPlayService.instance.stop();
        AppLog.instance.put('通过媒体按钮停止音频播放');
        return true;
      }

      return false;
    } catch (e) {
      AppLog.instance.put('处理停止按钮失败: $e', error: e);
      return false;
    }
  }

  /// 处理上一章/上一段
  /// 参考项目：MediaButtonReceiver.handleIntent() - KEYCODE_MEDIA_PREVIOUS
  Future<bool> _handlePrevious() async {
    try {
      // 检查配置：mediaButtonPerNext（媒体按钮控制章节切换）
      final mediaButtonPerNext =
          AppConfig.getBool(PreferKey.mediaButtonPerNext, defaultValue: false);

      if (mediaButtonPerNext) {
        // 控制章节切换
        return await ReaderController.instance.moveToPrevChapter();
      } else {
        // 控制朗读段落
        if (TtsService.instance.isSpeaking) {
          return await TtsService.instance.prevParagraph();
        }
        // 如果没有TTS在运行，尝试控制音频播放的上一章
        if (AudioPlayService.instance.status == PlayStatus.playing ||
            AudioPlayService.instance.status == PlayStatus.paused) {
          await AudioPlayService.instance.prevChapter();
          return true;
        }
        return false;
      }
    } catch (e) {
      AppLog.instance.put('处理上一章失败: $e', error: e);
      return false;
    }
  }

  /// 处理下一章/下一段
  /// 参考项目：MediaButtonReceiver.handleIntent() - KEYCODE_MEDIA_NEXT
  Future<bool> _handleNext() async {
    try {
      // 检查配置：mediaButtonPerNext
      final mediaButtonPerNext =
          AppConfig.getBool(PreferKey.mediaButtonPerNext, defaultValue: false);

      if (mediaButtonPerNext) {
        // 控制章节切换
        return await ReaderController.instance.moveToNextChapter();
      } else {
        // 控制朗读段落
        if (TtsService.instance.isSpeaking) {
          return await TtsService.instance.nextParagraph();
        }
        // 如果没有TTS在运行，尝试控制音频播放的下一章
        if (AudioPlayService.instance.status == PlayStatus.playing ||
            AudioPlayService.instance.status == PlayStatus.paused) {
          await AudioPlayService.instance.nextChapter();
          return true;
        }
        return false;
      }
    } catch (e) {
      AppLog.instance.put('处理下一章失败: $e', error: e);
      return false;
    }
  }

  /// 处理播放/暂停
  Future<bool> _handlePlayPause(bool isMediaKey) async {
    try {
      // 检查是否有TTS朗读服务在运行
      if (TtsService.instance.isSpeaking) {
        if (TtsService.instance.isPaused) {
          // 继续朗读
          await TtsService.instance.resume();
          return true;
        } else {
          // 暂停朗读
          await TtsService.instance.pause();
          return true;
        }
      }

      // 检查是否有音频播放服务在运行
      if (AudioPlayService.instance.status == PlayStatus.playing) {
        await AudioPlayService.instance.pause();
        return true;
      } else if (AudioPlayService.instance.status == PlayStatus.paused) {
        await AudioPlayService.instance.play();
        return true;
      }

      // 如果都没有运行，检查是否应该启动朗读
      if (isMediaKey) {
        // 检查配置：mediaButtonOnExit（退出应用时媒体按钮仍有效）
        final mediaButtonOnExit = AppConfig.getMediaButtonOnExit();

        if (mediaButtonOnExit) {
          // 尝试启动朗读
          await startReadAloud(isMediaKey: isMediaKey);
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLog.instance.put('处理播放/暂停失败: $e', error: e);
      return false;
    }
  }

  /// 启动朗读（通过媒体按钮）
  /// 参考项目：MediaButtonReceiver.readAloud()
  Future<void> startReadAloud({bool isMediaKey = true}) async {
    try {
      // 检查配置
      if (isMediaKey && !AppConfig.getReadAloudByMediaButton()) {
        return;
      }

      // 获取最后阅读的书籍
      final lastBook = await BookService.instance.getLastReadBook();
      if (lastBook == null) {
        AppLog.instance.put('没有最后阅读的书籍');
        return;
      }

      // 获取当前章节内容
      try {
        final chapters = await BookService.instance.getChapterList(lastBook);
        if (chapters.isEmpty) {
          AppLog.instance.put('书籍没有章节');
          return;
        }

        // 获取当前章节索引
        final currentChapterIndex =
            lastBook.durChapterIndex.clamp(0, chapters.length - 1);
        final chapter = chapters[currentChapterIndex];

        // 获取章节内容
        String? content;
        if (lastBook.isLocal) {
          content = await LocalBookService.instance
              .getChapterContent(chapter, lastBook);
        } else {
          // 获取书源
          final source = await BookSourceService.instance
              .getBookSourceByUrl(lastBook.origin);
          if (source == null) {
            AppLog.instance.put('无法获取书源: ${lastBook.origin}');
            return;
          }
          content = await BookService.instance.getChapterContent(
            chapter,
            source,
            bookName: lastBook.name,
            bookOrigin: lastBook.origin,
            book: lastBook, // 传入 book 参数，启用缓存优化
          );
        }

        if (content == null || content.isEmpty) {
          AppLog.instance.put('章节内容为空');
          return;
        }

        // 启动TTS朗读
        await TtsService.instance.speak(content);
        AppLog.instance.put('通过媒体按钮启动朗读: ${lastBook.name} - ${chapter.title}');
      } catch (e) {
        AppLog.instance.put('启动朗读失败: $e', error: e);
      }
    } catch (e) {
      AppLog.instance.put('启动朗读失败: $e', error: e);
    }
  }

  @override
  Future<void> onDispose() async {
    // 清理资源
  }
}

/// 媒体按钮类型（简化版）
enum MediaButton {
  play,
  pause,
  playPause,
  skipToNext,
  skipToPrevious,
  stop,
}
