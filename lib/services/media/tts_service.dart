import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import '../../utils/app_log.dart';
import 'base_read_aloud_service.dart';
import '../notification_service.dart';

/// TTS朗读服务
/// 参考项目：io.legado.app.help.TTS
/// 继承 BaseReadAloudService 以复用公共功能
class TtsService extends BaseReadAloudService {
  static final TtsService instance = TtsService._init();
  final FlutterTts _flutterTts = FlutterTts();

  double _speechRate = 0.5; // 0.0 - 1.0
  double _volume = 1.0; // 0.0 - 1.0
  double _pitch = 1.0; // 0.5 - 2.0
  String? _currentLanguage;
  String? _currentVoice;

  Timer? _clearTtsTimer;
  final bool _onInit = false;
  String? _pausedText; // 暂停时的文本内容（用于resume）
  static const int _notificationId = 107; // TTS朗读通知ID

  TtsService._init();

  @override
  Future<void> onInit() async {
    return await execute(
      action: () async {
        // 设置语言
        await _flutterTts.setLanguage("zh-CN");

        // 设置回调
        _flutterTts.setStartHandler(() {
          // 取消清理任务
          _clearTtsTimer?.cancel();

          // 初始化已朗读字符数（参考项目：TTSUtteranceListener.onStart）
          final startPos =
              getParagraphStartPosition(currentParagraphIndexInternal);
          setReadAloudNumber(startPos);
          // 发送初始进度
          upTtsProgress(startPos + 1);

          onStart?.call();
        });

        _flutterTts.setCompletionHandler(() {
          // 更新当前段落索引（一段朗读完成，移动到下一段）
          // 参考项目：TTSUtteranceListener.onDone -> nextParagraph
          if (paragraphs.isNotEmpty &&
              currentParagraphIndexInternal >= 0 &&
              currentParagraphIndexInternal < paragraphs.length - 1) {
            // 更新已朗读字符数
            final currentParagraph = paragraphs[currentParagraphIndexInternal];
            setReadAloudNumber(
                readAloudNumberInternal + currentParagraph.length + 1);

            setCurrentParagraphIndex(currentParagraphIndexInternal + 1);
            // 注意：flutter_tts会自动处理队列中的下一段，这里只是更新索引
            // 如果队列中还有段落，isRunning会保持true
          } else {
            // 所有段落朗读完成
            // 重置进度
            upTtsProgress(0);
            // 一分钟没有朗读释放资源
            _clearTtsTimer?.cancel();
            _clearTtsTimer = Timer(const Duration(minutes: 1), () {
              clearTts();
            });
            onComplete?.call();
          }
        });

        _flutterTts.setErrorHandler((msg) {
          AppLog.instance.put('TTS错误: $msg');
          onError?.call(msg);
        });

        _flutterTts.setProgressHandler(
            (String text, int startOffset, int endOffset, String word) {
          // 参考项目：TTSUtteranceListener.onRangeStart
          // 计算在整章中的位置
          final chapterPosition = readAloudNumberInternal + startOffset;
          upTtsProgress(chapterPosition);

          // 保留原有的段落内进度回调
          onProgress?.call(startOffset, endOffset);
        });

        // 设置默认参数
        await _flutterTts.setSpeechRate(_speechRate);
        await _flutterTts.setVolume(_volume);
        await _flutterTts.setPitch(_pitch);
      },
      operationName: '初始化TTS服务',
      logError: true,
    );
  }

  /// 朗读文本（便捷方法）
  /// 参考项目：TTS.speak()
  /// 此方法会自动设置内容并开始播放
  Future<void> speak(String text) async {
    if (!isInitialized) {
      await init();
    }

    if (text.isEmpty) return;

    // 取消清理任务
    _clearTtsTimer?.cancel();

    if (_onInit) {
      // 正在初始化，等待初始化完成
      return;
    }

    return await execute(
      action: () async {
        // 按换行符分割文本
        final lines =
            text.split('\n').where((line) => line.trim().isNotEmpty).toList();

        if (lines.isEmpty) return;

        // 设置内容
        setContent(lines);

        // 开始播放
        await play();
      },
      operationName: '朗读文本',
      logError: false, // 错误通过回调处理
      defaultValue: null,
    ).catchError((e) {
      AppLog.instance.put('TTS朗读出错: $text', error: e);
      onError?.call(e.toString());
    });
  }

  @override
  Future<void> playStart() async {
    if (paragraphs.isEmpty) {
      AppLog.instance.put('朗读内容为空');
      return;
    }

    try {
      // 显示朗读通知
      await NotificationService.instance.showNotification(
        id: _notificationId,
        title: 'TTS朗读',
        content: '正在朗读...',
        isOngoing: true,
        channelId: NotificationService.channelIdReadAloud,
        payload: 'read_aloud:',
      );

      // 先清空队列
      await _flutterTts.stop();

      // 从当前段落索引开始播放
      final startIndex =
          currentParagraphIndexInternal.clamp(0, paragraphs.length - 1);

      // 第一段使用 stop 清空队列后朗读
      await _flutterTts.speak(paragraphs[startIndex]);

      // 后续段落添加到队列
      for (int i = startIndex + 1; i < paragraphs.length; i++) {
        final line = paragraphs[i];
        if (line.trim().isEmpty) continue;

        // flutter_tts 会自动将多个 speak 调用加入队列
        await _flutterTts.speak(line);
      }
    } catch (e) {
      AppLog.instance.put('TTS播放失败', error: e);
      onError?.call(e.toString());
      await NotificationService.instance.cancelNotification(_notificationId);
    }
  }

  @override
  Future<void> playStop() async {
    try {
      await _flutterTts.stop();
      _pausedText = null;

      // 取消朗读通知
      await NotificationService.instance.cancelNotification(_notificationId);
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  @override
  Future<void> pauseReadAloud() async {
    try {
      await _flutterTts.pause();
      // 保存当前朗读的文本内容（用于resume）
      if (paragraphs.isNotEmpty &&
          currentParagraphIndexInternal >= 0 &&
          currentParagraphIndexInternal < paragraphs.length) {
        // 保存从当前段落开始的剩余文本
        final remainingParagraphs =
            paragraphs.sublist(currentParagraphIndexInternal);
        _pausedText = remainingParagraphs.join('\n');
      }

      // 更新通知为暂停状态
      await NotificationService.instance.showNotification(
        id: _notificationId,
        title: 'TTS朗读',
        content: '已暂停',
        isOngoing: true,
        channelId: NotificationService.channelIdReadAloud,
        payload: 'read_aloud:',
      );
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  @override
  Future<void> resumeReadAloud() async {
    try {
      // flutter_tts 没有直接的 resume 方法
      // 如果有保存的暂停文本，重新朗读
      if (_pausedText != null && _pausedText!.isNotEmpty) {
        // 重新朗读暂停的文本
        final lines = _pausedText!
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          setContent(lines, startParagraphIndex: 0);
          await playStart();
        }
        _pausedText = null;
      } else if (paragraphs.isNotEmpty &&
          currentParagraphIndexInternal >= 0 &&
          currentParagraphIndexInternal < paragraphs.length) {
        // 如果没有保存的文本，从当前段落开始重新朗读
        await playStart();
      }
    } catch (e) {
      AppLog.instance.put('TTS继续朗读失败: $e', error: e);
      onError?.call(e.toString());
    }
  }

  @override
  Future<void> playParagraph(int paragraphIndex) async {
    if (paragraphIndex < 0 || paragraphIndex >= paragraphs.length) {
      return;
    }

    try {
      // 停止当前朗读
      await _flutterTts.stop();

      // 设置当前段落索引
      setCurrentParagraphIndex(paragraphIndex);

      // 重新朗读从指定段落开始的所有段落
      for (int i = paragraphIndex; i < paragraphs.length; i++) {
        await _flutterTts.speak(paragraphs[i]);
      }

      AppLog.instance.put('播放段落: $paragraphIndex');
    } catch (e) {
      AppLog.instance.put('播放段落失败: $paragraphIndex', error: e);
      onError?.call(e.toString());
    }
  }

  /// 清理 TTS 资源
  /// 参考项目：TTS.clearTts()
  Future<void> clearTts() async {
    try {
      await _flutterTts.stop();
      _clearTtsTimer?.cancel();
      _clearTtsTimer = null;
      _pausedText = null;
      await stop(); // 调用基类的stop方法
    } catch (e) {
      AppLog.instance.put('清理TTS资源失败', error: e);
    }
  }

  /// 设置朗读速度 (0.0 - 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    try {
      await _flutterTts.setSpeechRate(_speechRate);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 设置音量 (0.0 - 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _flutterTts.setVolume(_volume);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 设置音调 (0.5 - 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    try {
      await _flutterTts.setPitch(_pitch);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    try {
      final result = await _flutterTts.setLanguage(language);
      if (result != null && result != "error") {
        _currentLanguage = language;
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 获取可用语言列表
  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// 获取可用语音列表
  Future<List<Map<String, String>>> getAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices != null) {
        return voices.cast<Map<String, String>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 设置语音
  Future<void> setVoice(Map<String, String> voice) async {
    _currentVoice = voice['name'];
    try {
      await _flutterTts.setVoice(voice);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 是否正在朗读（兼容性方法）
  bool get isSpeaking => isRunning;

  /// 获取当前朗读速度
  double get speechRate => _speechRate;

  /// 获取当前音量
  double get volume => _volume;

  /// 获取当前音调
  double get pitch => _pitch;

  /// 获取当前语言
  String? get currentLanguage => _currentLanguage;

  /// 获取当前语音
  String? get currentVoice => _currentVoice;

  @override
  Future<void> onDispose() async {
    await clearTts();
    await super.onDispose();
  }
}
