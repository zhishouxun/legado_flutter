import 'dart:async';
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'base_read_aloud_service.dart';
import '../../utils/app_log.dart';
import '../../data/models/http_tts.dart';
import '../http_tts_service.dart';
import '../network/network_service.dart';
import '../notification_service.dart';

/// HTTP在线朗读服务
/// 参考项目：io.legado.app.service.HttpReadAloudService
class HttpReadAloudService extends BaseReadAloudService {
  static final HttpReadAloudService instance = HttpReadAloudService._init();
  HttpReadAloudService._init();

  final AudioPlayer _player = AudioPlayer();
  HttpTTS? _currentHttpTTS;
  final List<String> _audioUrls = [];
  int _currentAudioIndex = -1;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  static const int _notificationId = 108; // HTTP朗读通知ID

  /// 设置HTTP TTS配置
  Future<void> setHttpTTS(HttpTTS httpTTS) async {
    _currentHttpTTS = httpTTS;
    await HttpTTSService.instance.updateLastUpdateTime(httpTTS.id);
  }

  /// 获取当前HTTP TTS配置
  HttpTTS? get currentHttpTTS => _currentHttpTTS;

  @override
  Future<void> onInit() async {
    // 监听播放状态
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onAudioCompleted();
      } else if (state.processingState == ProcessingState.loading) {
        // 加载中
      } else if (state.playing) {
        // 播放中
      }
    });

    // 监听播放位置
    _positionSubscription = _player.positionStream.listen((position) {
      // 可以用于显示播放进度
    });
  }

  @override
  Future<void> playStart() async {
    if (_currentHttpTTS == null) {
      AppLog.instance.put('HTTP TTS配置未设置');
      onError?.call('HTTP TTS配置未设置');
      return;
    }

    if (paragraphs.isEmpty) {
      AppLog.instance.put('朗读内容为空');
      return;
    }

    try {
      // 显示朗读通知
      await NotificationService.instance.showNotification(
        id: _notificationId,
        title: 'HTTP朗读',
        content: '正在播放...',
        isOngoing: true,
        channelId: NotificationService.channelIdReadAloud,
        payload: 'read_aloud:',
      );

      // 生成音频URL列表
      await _generateAudioUrls();

      if (_audioUrls.isEmpty) {
        AppLog.instance.put('音频URL列表为空');
        onError?.call('音频URL列表为空');
        await NotificationService.instance.cancelNotification(_notificationId);
        return;
      }

      // 从当前段落开始播放
      _currentAudioIndex =
          currentParagraphIndexInternal.clamp(0, _audioUrls.length - 1);
      await _playAudio(_currentAudioIndex);
    } catch (e) {
      AppLog.instance.put('开始播放失败', error: e);
      onError?.call(e.toString());
      await NotificationService.instance.cancelNotification(_notificationId);
    }
  }

  @override
  Future<void> playStop() async {
    await _player.stop();
    _audioUrls.clear();
    _currentAudioIndex = -1;

    // 取消朗读通知
    await NotificationService.instance.cancelNotification(_notificationId);
  }

  @override
  Future<void> pauseReadAloud() async {
    await _player.pause();

    // 更新通知为暂停状态
    await NotificationService.instance.showNotification(
      id: _notificationId,
      title: 'HTTP朗读',
      content: '已暂停',
      isOngoing: true,
      channelId: NotificationService.channelIdReadAloud,
      payload: 'read_aloud:',
    );
  }

  @override
  Future<void> resumeReadAloud() async {
    await _player.play();

    // 更新通知为播放状态
    await NotificationService.instance.showNotification(
      id: _notificationId,
      title: 'HTTP朗读',
      content: '正在播放...',
      isOngoing: true,
      channelId: NotificationService.channelIdReadAloud,
      payload: 'read_aloud:',
    );
  }

  @override
  Future<void> playParagraph(int paragraphIndex) async {
    if (paragraphIndex < 0 || paragraphIndex >= _audioUrls.length) {
      return;
    }

    await _player.stop();
    _currentAudioIndex = paragraphIndex;
    await _playAudio(_currentAudioIndex);
  }

  /// 生成音频URL列表
  /// 参考项目：HttpReadAloudService.downloadAndPlayAudios()
  Future<void> _generateAudioUrls() async {
    if (_currentHttpTTS == null || paragraphs.isEmpty) {
      return;
    }

    _audioUrls.clear();

    try {
      for (int i = 0; i < paragraphs.length; i++) {
        final paragraph = paragraphs[i];
        if (paragraph.trim().isEmpty) {
          continue;
        }

        // 调用HTTP TTS API获取音频URL
        final audioUrl = await _getAudioUrl(paragraph);
        if (audioUrl != null && audioUrl.isNotEmpty) {
          _audioUrls.add(audioUrl);
        } else {
          AppLog.instance.put('获取音频URL失败: 段落 $i');
        }
      }
    } catch (e) {
      AppLog.instance.put('生成音频URL列表失败', error: e);
    }
  }

  /// 获取音频URL
  /// 参考项目：HttpReadAloudService.getMediaItem()
  Future<String?> _getAudioUrl(String text) async {
    if (_currentHttpTTS == null) {
      return null;
    }

    try {
      final httpTTS = _currentHttpTTS!;
      final url = httpTTS.url;

      // 解析请求头
      final headers = NetworkService.parseHeaders(httpTTS.header);

      // 构建请求体（根据contentType）
      dynamic body;
      if (httpTTS.contentType != null && httpTTS.contentType!.isNotEmpty) {
        if (httpTTS.contentType!.contains('json')) {
          // JSON格式：通常需要将text作为字段传递
          body = jsonEncode({'text': text});
          headers['Content-Type'] = 'application/json';
        } else if (httpTTS.contentType!.contains('form')) {
          // Form格式
          body = {'text': text};
          headers['Content-Type'] = 'application/x-www-form-urlencoded';
        } else {
          // 默认：text作为URL参数或body
          body = text;
        }
      } else {
        // 默认：text作为body
        body = text;
      }

      // 如果有JS库，需要执行JS来构建请求
      if (httpTTS.jsLib != null && httpTTS.jsLib!.isNotEmpty) {
        // TODO: 执行JS来构建请求（需要JS引擎）
        AppLog.instance.put('JS库暂不支持: ${httpTTS.jsLib}');
      }

      // 发送HTTP请求
      final response = await NetworkService.instance.post(
        url,
        data: body,
        headers: headers,
      );

      if (response.statusCode == 200) {
        // 解析响应获取音频URL
        // 注意：不同TTS API返回格式可能不同
        // 这里假设返回的是JSON，包含audioUrl字段
        try {
          final responseData = jsonDecode(response.data);
          if (responseData is Map) {
            // 尝试多种可能的字段名
            return responseData['audioUrl'] as String? ??
                responseData['url'] as String? ??
                responseData['audio'] as String? ??
                responseData['data'] as String?;
          } else if (responseData is String) {
            // 如果直接返回URL字符串
            return responseData;
          }
        } catch (e) {
          // 如果不是JSON，尝试直接使用响应数据作为URL
          if (response.data is String) {
            return response.data as String;
          }
        }
      }

      return null;
    } catch (e) {
      AppLog.instance.put('获取音频URL失败', error: e);
      return null;
    }
  }

  /// 播放音频
  Future<void> _playAudio(int index) async {
    if (index < 0 || index >= _audioUrls.length) {
      return;
    }

    try {
      final audioUrl = _audioUrls[index];

      // 使用just_audio播放音频
      await _player.setUrl(audioUrl);
      await _player.play();

      AppLog.instance.put('播放音频: $index/$_audioUrls.length');
    } catch (e) {
      AppLog.instance.put('播放音频失败: $index', error: e);
      onError?.call('播放音频失败: ${e.toString()}');

      // 尝试播放下一段
      if (index + 1 < _audioUrls.length) {
        await Future.delayed(const Duration(seconds: 1));
        await _playAudio(index + 1);
      }
    }
  }

  /// 音频播放完成回调
  void _onAudioCompleted() async {
    if (_currentAudioIndex < 0 || _currentAudioIndex >= _audioUrls.length) {
      return;
    }

    // 更新段落索引
    setCurrentParagraphIndex(_currentAudioIndex);

    // 播放下一段
    if (_currentAudioIndex + 1 < _audioUrls.length) {
      _currentAudioIndex++;
      await _playAudio(_currentAudioIndex);
    } else {
      // 所有段落播放完成
      setCurrentParagraphIndex(paragraphs.length);
      await stop();
    }
  }

  /// 设置播放速度
  /// 参考项目：HttpReadAloudService.upSpeechRate()
  Future<void> setSpeechRate(double rate) async {
    await _player.setSpeed(rate.clamp(0.5, 2.0));
  }

  @override
  Future<void> onDispose() async {
    await _playerStateSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _player.dispose();
    await super.onDispose();
  }
}
