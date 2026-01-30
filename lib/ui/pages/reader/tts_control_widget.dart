import 'package:flutter/material.dart';
import '../../../services/media/tts_service.dart';

/// TTS朗读控制组件
class TtsControlWidget extends StatefulWidget {
  final String text;
  final VoidCallback? onClose;

  const TtsControlWidget({
    super.key,
    required this.text,
    this.onClose,
  });

  @override
  State<TtsControlWidget> createState() => _TtsControlWidgetState();
}

class _TtsControlWidgetState extends State<TtsControlWidget> {
  final TtsService _ttsService = TtsService.instance;
  bool _isSpeaking = false;
  bool _isPaused = false;
  double _speechRate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;
  List<String> _languages = [];
  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _speechRate = _ttsService.speechRate;
    _volume = _ttsService.volume;
    _pitch = _ttsService.pitch;
    _loadLanguages();
    _setupListeners();
  }

  void _setupListeners() {
    _ttsService.onStart = () {
      setState(() {
        _isSpeaking = true;
        _isPaused = false;
      });
    };

    _ttsService.onComplete = () {
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    };

    _ttsService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('朗读出错: $error')),
        );
      }
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    };
  }

  Future<void> _loadLanguages() async {
    final languages = await _ttsService.getAvailableLanguages();

    setState(() {
      _languages = languages;
      _selectedLanguage = _ttsService.currentLanguage;
    });
  }

  Future<void> _startSpeaking() async {
    await _ttsService.speak(widget.text);
  }

  Future<void> _stopSpeaking() async {
    await _ttsService.stop();
  }

  Future<void> _pauseSpeaking() async {
    await _ttsService.pause();
    setState(() {
      _isPaused = true;
    });
  }

  Future<void> _resumeSpeaking() async {
    // FlutterTts 没有直接的 resume，需要重新开始
    await _startSpeaking();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF2C2C2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动指示器
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              Row(
                children: [
                  const Text(
                    '朗读控制',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              const Divider(height: 1, color: Colors.grey),
              const SizedBox(height: 16),
              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white),
                    onPressed: _isSpeaking && !_isPaused
                        ? _pauseSpeaking
                        : _isPaused
                            ? _resumeSpeaking
                            : null,
                    iconSize: 32,
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.white),
                    onPressed: _isSpeaking ? _stopSpeaking : null,
                    iconSize: 32,
                  ),
                  const SizedBox(width: 20),
                  if (!_isSpeaking)
                    IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.orange),
                      onPressed: _startSpeaking,
                      iconSize: 32,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // 速度调节
              Row(
                children: [
                  const Text('速度:', style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: _speechRate,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: _speechRate.toStringAsFixed(1),
                      activeColor: Colors.orange,
                      onChanged: (value) {
                        setState(() {
                          _speechRate = value;
                        });
                        _ttsService.setSpeechRate(value);
                      },
                    ),
                  ),
                  Text(_speechRate.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              // 音量调节
              Row(
                children: [
                  const Text('音量:', style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: (_volume * 100).toStringAsFixed(0),
                      activeColor: Colors.orange,
                      onChanged: (value) {
                        setState(() {
                          _volume = value;
                        });
                        _ttsService.setVolume(value);
                      },
                    ),
                  ),
                  Text('${(_volume * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              // 音调调节
              Row(
                children: [
                  const Text('音调:', style: TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: _pitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: _pitch.toStringAsFixed(1),
                      activeColor: Colors.orange,
                      onChanged: (value) {
                        setState(() {
                          _pitch = value;
                        });
                        _ttsService.setPitch(value);
                      },
                    ),
                  ),
                  Text(_pitch.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
              // 语言选择
              if (_languages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Text('语言:',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2C2C2C),
                          style: const TextStyle(color: Colors.white),
                          items: _languages.map((lang) {
                            return DropdownMenuItem(
                              value: lang,
                              child: Text(lang),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedLanguage = value;
                              });
                              _ttsService.setLanguage(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }
}
