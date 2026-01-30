import 'package:flutter/material.dart';
import '../../../data/models/http_tts.dart';
import '../../../services/http_tts_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';
import '../../widgets/common/custom_switch_list_tile.dart';
import '../../../utils/app_log.dart';

/// HTTP TTS编辑对话框
/// 参考项目：io.legado.app.ui.book.read.config.HttpTtsEditDialog
class HttpTtsEditDialog extends BaseBottomSheetStateful {
  final HttpTTS? httpTTS;

  const HttpTtsEditDialog({
    super.key,
    this.httpTTS,
  }) : super(
          title: httpTTS == null ? '添加HTTP TTS' : '编辑HTTP TTS',
          heightFactor: 0.9,
        );

  @override
  State<HttpTtsEditDialog> createState() => _HttpTtsEditDialogState();
}

class _HttpTtsEditDialogState extends BaseBottomSheetState<HttpTtsEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _contentTypeController;
  late TextEditingController _headerController;
  late TextEditingController _jsLibController;
  late TextEditingController _loginUrlController;
  late TextEditingController _loginUiController;
  late TextEditingController _loginCheckJsController;
  late TextEditingController _concurrentRateController;
  bool _enabledCookieJar = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final httpTTS = widget.httpTTS;
    _nameController = TextEditingController(text: httpTTS?.name ?? '');
    _urlController = TextEditingController(text: httpTTS?.url ?? '');
    _contentTypeController = TextEditingController(text: httpTTS?.contentType ?? '');
    _headerController = TextEditingController(text: httpTTS?.header ?? '');
    _jsLibController = TextEditingController(text: httpTTS?.jsLib ?? '');
    _loginUrlController = TextEditingController(text: httpTTS?.loginUrl ?? '');
    _loginUiController = TextEditingController(text: httpTTS?.loginUi ?? '');
    _loginCheckJsController = TextEditingController(text: httpTTS?.loginCheckJs ?? '');
    _concurrentRateController = TextEditingController(text: httpTTS?.concurrentRate ?? '0');
    _enabledCookieJar = httpTTS?.enabledCookieJar ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _contentTypeController.dispose();
    _headerController.dispose();
    _jsLibController.dispose();
    _loginUrlController.dispose();
    _loginUiController.dispose();
    _loginCheckJsController.dispose();
    _concurrentRateController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _nameController,
            label: '名称',
            hint: 'HTTP TTS名称',
            required: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _urlController,
            label: 'URL',
            hint: 'HTTP TTS请求URL',
            required: true,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _contentTypeController,
            label: 'Content-Type',
            hint: '音频内容类型（如：audio/mpeg）',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _headerController,
            label: '请求头',
            hint: 'JSON格式的请求头',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _jsLibController,
            label: 'JS库',
            hint: 'JavaScript库代码',
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _loginUrlController,
            label: '登录URL',
            hint: '登录请求URL',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _loginUiController,
            label: '登录UI',
            hint: '登录界面配置（JSON格式）',
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _loginCheckJsController,
            label: '登录检测JS',
            hint: '登录状态检测JavaScript代码',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _concurrentRateController,
            label: '并发率',
            hint: '并发请求数量限制',
          ),
          const SizedBox(height: 16),
          CustomSwitchListTile(
            title: const Text('启用CookieJar', style: TextStyle(color: Colors.white)),
            value: _enabledCookieJar,
            onChanged: (value) {
              setState(() {
                _enabledCookieJar = value;
              });
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveHttpTTS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('保存', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.orange),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveHttpTTS() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('名称不能为空'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL不能为空'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final httpTTS = HttpTTS(
        id: widget.httpTTS?.id,
        name: name,
        url: url,
        contentType: _contentTypeController.text.trim().isEmpty
            ? null
            : _contentTypeController.text.trim(),
        header: _headerController.text.trim().isEmpty
            ? null
            : _headerController.text.trim(),
        jsLib: _jsLibController.text.trim().isEmpty
            ? null
            : _jsLibController.text.trim(),
        loginUrl: _loginUrlController.text.trim().isEmpty
            ? null
            : _loginUrlController.text.trim(),
        loginUi: _loginUiController.text.trim().isEmpty
            ? null
            : _loginUiController.text.trim(),
        loginCheckJs: _loginCheckJsController.text.trim().isEmpty
            ? null
            : _loginCheckJsController.text.trim(),
        concurrentRate: _concurrentRateController.text.trim().isEmpty
            ? '0'
            : _concurrentRateController.text.trim(),
        enabledCookieJar: _enabledCookieJar,
      );

      final success = await HttpTTSService.instance.saveHttpTTS(httpTTS);
      if (success && mounted) {
        Navigator.pop(context, httpTTS);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLog.instance.put('保存HTTP TTS失败', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

