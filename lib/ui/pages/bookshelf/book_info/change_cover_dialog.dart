import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import '../../../../data/models/book.dart';
import '../../../../services/book/book_service.dart';
import '../../../../services/cover_search_service.dart';
import '../../../../utils/app_log.dart';
import '../../../widgets/base/base_bottom_sheet_stateful.dart';

/// 封面更换对话框
class ChangeCoverDialog extends BaseBottomSheetStateful {
  final Book book;
  final Function(String coverUrl)? onCoverChanged;

  const ChangeCoverDialog({
    super.key,
    required this.book,
    this.onCoverChanged,
  }) : super(
          title: '更换封面',
          heightFactor: 0.9,
        );

  @override
  State<ChangeCoverDialog> createState() => _ChangeCoverDialogState();
}

class _ChangeCoverDialogState extends BaseBottomSheetState<ChangeCoverDialog> {
  final TextEditingController _urlController = TextEditingController();
  String? _selectedImagePath;
  bool _isLoading = false;
  bool _isSearching = false;
  List<CoverSearchResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _urlController.text =
        widget.book.customCoverUrl ?? widget.book.coverUrl ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
          _urlController.text = '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
          _urlController.text = '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  Future<void> _saveCover() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? coverUrl;

      if (_selectedImagePath != null) {
        // 使用本地图片，保存到应用目录
        final savedPath = await _saveImageToAppDir(_selectedImagePath!);
        if (savedPath != null) {
          coverUrl = savedPath;
        } else {
          // 如果保存失败，使用原始路径
          coverUrl = _selectedImagePath;
        }
      } else if (_urlController.text.trim().isNotEmpty) {
        // 使用URL
        coverUrl = _urlController.text.trim();
      } else {
        // 清空自定义封面
        coverUrl = null;
      }

      // 更新书籍封面
      final updatedBook = widget.book.copyWith(
        customCoverUrl: coverUrl,
      );

      await BookService.instance.updateBook(updatedBook);

      if (mounted) {
        widget.onCoverChanged?.call(coverUrl ?? '');
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('封面已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 保存图片到应用目录
  /// 参考 WelcomeImagePicker._saveImage 的实现
  Future<String?> _saveImageToAppDir(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        AppLog.instance.put('图片文件不存在: $imagePath');
        return null;
      }

      // 读取文件内容
      final imageBytes = await imageFile.readAsBytes();

      // 计算MD5作为文件名
      final digest = md5.convert(imageBytes);
      final extension = path.extension(imagePath);
      final fileName = '${digest.toString()}$extension';

      // 保存到应用目录的 covers 文件夹
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final savedFile = File('${coversDir.path}/$fileName');
      await savedFile.writeAsBytes(imageBytes);

      AppLog.instance.put('封面图片已保存到: ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      AppLog.instance.put('保存封面图片失败: $e', error: e);
      return null;
    }
  }

  void _clearCover() {
    setState(() {
      _selectedImagePath = null;
      _urlController.text = '';
    });
  }

  Future<void> _searchCover() async {
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await CoverSearchService.instance.searchCover(
        widget.book.name,
        widget.book.author,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  void _selectCoverFromSearch(String coverUrl) {
    setState(() {
      _urlController.text = coverUrl;
      _selectedImagePath = null;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 网络搜索按钮
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                onPressed: _isSearching ? null : _searchCover,
                tooltip: '网络搜索封面',
              ),
            ],
          ),
        ),
        // 内容区域
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 当前封面预览
                Center(
                  child: Container(
                    width: 150,
                    height: 210,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[300],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildPreviewImage(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // 网络搜索结果
                if (_searchResults.isNotEmpty) ...[
                  const Text(
                    '网络搜索结果',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return GestureDetector(
                          onTap: () => _selectCoverFromSearch(result.coverUrl),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _urlController.text == result.coverUrl
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[300]!,
                                width: _urlController.text == result.coverUrl
                                    ? 2
                                    : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: result.coverUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // 选择方式
                const Text(
                  '选择封面',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('从相册选择'),
                        onPressed: _pickImageFromGallery,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('拍照'),
                        onPressed: _takePhoto,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // URL输入
                const Text(
                  '或输入封面URL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: '请输入封面图片URL',
                    border: const OutlineInputBorder(),
                    suffixIcon: _urlController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _urlController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isNotEmpty) {
                        _selectedImagePath = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 24),
                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearCover,
                        child: const Text('清空'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveCover,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewImage() {
    if (_selectedImagePath != null) {
      return Image.file(
        File(_selectedImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 40,
            ),
          );
        },
      );
    }

    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 40,
            ),
          );
        },
      );
    }

    final currentCover = widget.book.displayCover;
    if (currentCover != null && currentCover.isNotEmpty) {
      return Image.network(
        currentCover,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(
              Icons.book,
              color: Colors.grey,
              size: 40,
            ),
          );
        },
      );
    }

    return Container(
      color: Colors.grey[300],
      child: const Icon(
        Icons.book,
        color: Colors.grey,
        size: 40,
      ),
    );
  }
}
