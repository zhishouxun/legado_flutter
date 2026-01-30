import 'package:flutter/material.dart';
import '../../../services/media/audio_play_service.dart';

/// 音频播放列表组件
class AudioPlayListWidget extends StatefulWidget {
  final AudioPlayService audioService;
  final ValueChanged<int> onChapterSelected;

  const AudioPlayListWidget({
    super.key,
    required this.audioService,
    required this.onChapterSelected,
  });

  @override
  State<AudioPlayListWidget> createState() => _AudioPlayListWidgetState();
}

class _AudioPlayListWidgetState extends State<AudioPlayListWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 标题
          Row(
            children: [
              const Text(
                '播放列表',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          // 章节列表
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: widget.audioService.chapterIndexNotifier,
              builder: (context, currentIndex, _) {
                final chapters = widget.audioService.chapters;
                if (chapters.isEmpty) {
                  return const Center(
                    child: Text('暂无章节'),
                  );
                }

                return ListView.builder(
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final isCurrent = index == currentIndex;
                    return ListTile(
                      leading: isCurrent
                          ? const Icon(Icons.play_arrow, color: Colors.blue)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                      title: Text(
                        chapter.title,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? Theme.of(context).primaryColor : null,
                        ),
                      ),
                      onTap: () {
                        widget.onChapterSelected(index);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

