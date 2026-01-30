import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

/// 欢迎页图片选择对话框
class WelcomeImagePicker extends StatefulWidget {
  final String? currentImagePath;

  const WelcomeImagePicker({
    super.key,
    this.currentImagePath,
  });

  @override
  State<WelcomeImagePicker> createState() => _WelcomeImagePickerState();
}

class _WelcomeImagePickerState extends State<WelcomeImagePicker> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessing = false;

  Future<String?> _saveImage(File imageFile) async {
    try {
      // 读取文件内容
      final imageBytes = await imageFile.readAsBytes();
      
      // 计算MD5作为文件名
      final digest = md5.convert(imageBytes);
      final extension = path.extension(imageFile.path);
      final fileName = '${digest.toString()}$extension';
      
      // 保存到应用目录
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }
      
      final savedFile = File('${coversDir.path}/$fileName');
      await savedFile.writeAsBytes(imageBytes);
      
      return savedFile.path;
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final savedPath = await _saveImage(imageFile);
        
        if (savedPath != null && mounted) {
          Navigator.of(context).pop(savedPath);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存图片失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _deleteImage() {
    Navigator.of(context).pop('');
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.currentImagePath != null && widget.currentImagePath!.isNotEmpty;

    return AlertDialog(
      title: const Text('选择背景图片'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasImage) ...[
            // 预览当前图片
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(widget.currentImagePath!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            if (hasImage) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除图片', style: TextStyle(color: Colors.red)),
                onTap: () {
                  _deleteImage();
                },
              ),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

