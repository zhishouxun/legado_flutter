import 'package:flutter/material.dart';
import '../../../services/media/audio_play_service.dart' show AudioPlayService, PlayStatus, PlayMode;

/// 音频播放控制组件
class AudioPlayControlWidget extends StatefulWidget {
  final AudioPlayService audioService;

  const AudioPlayControlWidget({
    super.key,
    required this.audioService,
  });

  @override
  State<AudioPlayControlWidget> createState() => _AudioPlayControlWidgetState();
}

class _AudioPlayControlWidgetState extends State<AudioPlayControlWidget> {
  bool _isDragging = false;
  double _dragValue = 0;

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          ValueListenableBuilder<int>(
            valueListenable: widget.audioService.progressNotifier,
            builder: (context, progress, _) {
              return ValueListenableBuilder<int>(
                valueListenable: widget.audioService.durationNotifier,
                builder: (context, duration, _) {
                  final currentValue = _isDragging ? _dragValue : progress.toDouble();
                  final maxValue = duration > 0 ? duration.toDouble() : 1.0;

                  return Column(
                    children: [
                      // 时间显示
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(currentValue.toInt()),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _formatDuration(duration),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      // 进度条
                      Slider(
                        value: currentValue.clamp(0, maxValue),
                        max: maxValue,
                        onChanged: (value) {
                          setState(() {
                            _isDragging = true;
                            _dragValue = value;
                          });
                        },
                        onChangeEnd: (value) {
                          widget.audioService.seekTo(Duration(seconds: value.toInt()));
                          setState(() {
                            _isDragging = false;
                          });
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 上一章
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 32,
                onPressed: () => widget.audioService.prevChapter(),
                tooltip: '上一章',
              ),
              const SizedBox(width: 16),
              // 播放/暂停
              ValueListenableBuilder<PlayStatus>(
                valueListenable: widget.audioService.statusNotifier,
                builder: (context, status, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.audioService.loadingNotifier,
                    builder: (context, loading, _) {
                      if (loading) {
                        return const SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (status == PlayStatus.playing) {
                        return IconButton(
                          icon: const Icon(Icons.pause_circle_filled),
                          iconSize: 64,
                          color: Theme.of(context).primaryColor,
                          onPressed: () => widget.audioService.pause(),
                          tooltip: '暂停',
                        );
                      } else {
                        return IconButton(
                          icon: const Icon(Icons.play_circle_filled),
                          iconSize: 64,
                          color: Theme.of(context).primaryColor,
                          onPressed: () => widget.audioService.play(),
                          tooltip: '播放',
                        );
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 16),
              // 下一章
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 32,
                onPressed: () => widget.audioService.nextChapter(),
                tooltip: '下一章',
              ),
              const SizedBox(width: 16),
              // 播放模式
              ValueListenableBuilder<PlayMode>(
                valueListenable: widget.audioService.playModeNotifier,
                builder: (context, playMode, _) {
                  IconData modeIcon;
                  String modeTooltip;
                  switch (playMode) {
                    case PlayMode.listEndStop:
                      modeIcon = Icons.playlist_play;
                      modeTooltip = '列表结束停止';
                      break;
                    case PlayMode.singleLoop:
                      modeIcon = Icons.repeat_one;
                      modeTooltip = '单曲循环';
                      break;
                    case PlayMode.random:
                      modeIcon = Icons.shuffle;
                      modeTooltip = '随机播放';
                      break;
                    case PlayMode.listLoop:
                      modeIcon = Icons.repeat;
                      modeTooltip = '列表循环';
                      break;
                  }

                  return IconButton(
                    icon: Icon(modeIcon),
                    iconSize: 28,
                    onPressed: () {
                      widget.audioService.changePlayMode();
                      setState(() {}); // 刷新UI
                    },
                    tooltip: modeTooltip,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

