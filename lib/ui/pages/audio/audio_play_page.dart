import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/book.dart';
import '../../../services/media/audio_play_service.dart' show AudioPlayService, PlayStatus;
import 'audio_play_control_widget.dart';
import 'audio_play_list_widget.dart';
import 'audio_timer_dialog.dart';

/// 音频播放页面
class AudioPlayPage extends StatefulWidget {
  final Book book;

  const AudioPlayPage({
    super.key,
    required this.book,
  });

  @override
  State<AudioPlayPage> createState() => _AudioPlayPageState();
}

class _AudioPlayPageState extends State<AudioPlayPage> {
  final AudioPlayService _audioService = AudioPlayService.instance;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    await _audioService.init();
    await _audioService.setBook(widget.book);
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    // 注意：不要在这里dispose，因为服务是单例，可能被其他地方使用
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('音频播放'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('音频播放'),
        actions: [
          // 播放列表
          IconButton(
            icon: const Icon(Icons.queue_music),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => AudioPlayListWidget(
                  audioService: _audioService,
                  onChapterSelected: (index) {
                    _audioService.skipToChapter(index);
                    Navigator.pop(context);
                  },
                ),
              );
            },
            tooltip: '播放列表',
          ),
          // 定时停止
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () {
              _showTimerDialog();
            },
            tooltip: '定时停止',
          ),
        ],
      ),
      body: ValueListenableBuilder<PlayStatus>(
        valueListenable: _audioService.statusNotifier,
        builder: (context, status, _) {
          return Column(
            children: [
              // 书籍信息
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 封面
                      Container(
                        width: 200,
                        height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: widget.book.displayCover != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.book.displayCover!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.book,
                                      size: 80,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.book,
                                      size: 80,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.book,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 书名
                      Text(
                        widget.book.displayName,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // 作者
                      Text(
                        widget.book.displayAuthor,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // 当前章节
                      ValueListenableBuilder<String?>(
                        valueListenable: _audioService.chapterTitleNotifier,
                        builder: (context, chapterTitle, _) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '当前章节',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  chapterTitle ?? '加载中...',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              // 播放控制
              AudioPlayControlWidget(
                audioService: _audioService,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AudioTimerDialog(
        currentTimer: _audioService.timerMinute,
        onTimerSelected: (minute) {
          _audioService.setTimer(minute);
          Navigator.pop(context);
        },
      ),
    );
  }
}
