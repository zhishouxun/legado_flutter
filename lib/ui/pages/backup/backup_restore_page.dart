import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../services/storage/backup_service.dart';
import '../../../services/storage/restore_service.dart';
import '../../../services/storage/webdav_service.dart';
import '../../../utils/app_log.dart';
import 'backup_config_page.dart';

/// 备份恢复管理页面
class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool _isLoading = false;
  List<String> _webDavBackups = [];
  bool _isLoadingBackups = false;

  @override
  void initState() {
    super.initState();
    _loadWebDavBackups();
  }

  /// 加载WebDAV备份列表
  Future<void> _loadWebDavBackups() async {
    setState(() {
      _isLoadingBackups = true;
    });

    try {
      final backups = await RestoreService.instance.getWebDavBackupList();
      setState(() {
        _webDavBackups = backups;
      });
    } catch (e) {
      AppLog.instance.put('加载WebDAV备份列表失败', error: e);
    } finally {
      setState(() {
        _isLoadingBackups = false;
      });
    }
  }

  /// 备份到本地
  Future<void> _backupToLocal() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存备份文件',
        fileName: 'backup_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null) {
        await BackupService.instance.backupToLocal(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 备份到WebDAV
  Future<void> _backupToWebDav() async {
    // 检查WebDAV配置
    await WebDavService.instance.loadConfig();
    if (!WebDavService.instance.isConfigured) {
      if (mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('WebDAV未配置'),
            content: const Text('请先配置WebDAV设置'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('去设置'),
              ),
            ],
          ),
        );

        if (result == true) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const BackupConfigPage()),
          );
          _loadWebDavBackups();
        }
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await BackupService.instance.backupToWebDav();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('备份到WebDAV成功')),
        );
        _loadWebDavBackups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份到WebDAV失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 从本地恢复
  Future<void> _restoreFromLocal() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text('恢复备份将覆盖当前数据，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await RestoreService.instance.restoreFromLocal(filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('恢复成功')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 从WebDAV恢复
  Future<void> _restoreFromWebDav(String backupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认恢复'),
        content: Text('恢复备份 "$backupName" 将覆盖当前数据，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await RestoreService.instance.restoreFromWebDav(backupName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('恢复成功')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份恢复'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BackupConfigPage()),
              );
              _loadWebDavBackups();
            },
            tooltip: 'WebDAV设置',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 备份操作
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '备份',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _backupToLocal,
                          icon: const Icon(Icons.save),
                          label: const Text('备份到本地'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _backupToWebDav,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text('备份到WebDAV'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 恢复操作
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '恢复',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _restoreFromLocal,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('从本地恢复'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // WebDAV备份列表
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'WebDAV备份',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadWebDavBackups,
                              tooltip: '刷新',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingBackups)
                          const Center(child: CircularProgressIndicator())
                        else if (_webDavBackups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              '暂无备份',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ..._webDavBackups.map((backup) => ListTile(
                                title: Text(backup),
                                trailing: IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _restoreFromWebDav(backup),
                                  tooltip: '恢复',
                                ),
                              )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

