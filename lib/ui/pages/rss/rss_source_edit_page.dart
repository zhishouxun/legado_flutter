import 'package:flutter/material.dart';
import '../../../data/models/rss_source.dart';
import '../../../services/rss_service.dart';
import '../../widgets/common/custom_switch_list_tile.dart';

/// RSS源编辑页面
class RssSourceEditPage extends StatefulWidget {
  final RssSource? source;

  const RssSourceEditPage({super.key, this.source});

  @override
  State<RssSourceEditPage> createState() => _RssSourceEditPageState();
}

class _RssSourceEditPageState extends State<RssSourceEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _sourceUrlController;
  late TextEditingController _sourceNameController;
  late TextEditingController _sourceGroupController;
  late TextEditingController _sourceCommentController;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _sourceUrlController = TextEditingController(text: widget.source?.sourceUrl ?? '');
    _sourceNameController = TextEditingController(text: widget.source?.sourceName ?? '');
    _sourceGroupController = TextEditingController(text: widget.source?.sourceGroup ?? '');
    _sourceCommentController = TextEditingController(text: widget.source?.sourceComment ?? '');
    _enabled = widget.source?.enabled ?? true;
  }

  @override
  void dispose() {
    _sourceUrlController.dispose();
    _sourceNameController.dispose();
    _sourceGroupController.dispose();
    _sourceCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source == null ? '添加RSS源' : '编辑RSS源'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _sourceUrlController,
              decoration: const InputDecoration(
                labelText: 'RSS源URL *',
                hintText: '请输入RSS源的URL',
                border: OutlineInputBorder(),
              ),
              enabled: widget.source == null,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入RSS源URL';
                }
                if (!value.startsWith('http://') && !value.startsWith('https://')) {
                  return 'URL必须以http://或https://开头';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sourceNameController,
              decoration: const InputDecoration(
                labelText: 'RSS源名称 *',
                hintText: '请输入RSS源名称',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入RSS源名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sourceGroupController,
              decoration: const InputDecoration(
                labelText: '分组',
                hintText: '请输入分组名称（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sourceCommentController,
              decoration: const InputDecoration(
                labelText: '注释',
                hintText: '请输入注释（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            CustomSwitchListTile(
              title: const Text('启用'),
              subtitle: const Text('是否启用此RSS源'),
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
            const SizedBox(height: 32),
            if (widget.source != null)
              ElevatedButton(
                onPressed: _delete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('删除'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final source = RssSource(
      sourceUrl: _sourceUrlController.text.trim(),
      sourceName: _sourceNameController.text.trim(),
      sourceGroup: _sourceGroupController.text.trim().isEmpty 
          ? null 
          : _sourceGroupController.text.trim(),
      sourceComment: _sourceCommentController.text.trim().isEmpty 
          ? null 
          : _sourceCommentController.text.trim(),
      enabled: _enabled,
    );

    final success = await RssService.instance.addOrUpdateRssSource(source);
    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.source == null ? '添加成功' : '保存成功')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败')),
      );
    }
  }

  Future<void> _delete() async {
    if (widget.source == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除此RSS源吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await RssService.instance.deleteRssSource(widget.source!.sourceUrl);
    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除成功')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败')),
      );
    }
  }
}

