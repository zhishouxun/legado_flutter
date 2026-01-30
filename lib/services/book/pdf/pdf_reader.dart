/// PDF 文件解析器
/// 参考项目：io.legado.app.model.localBook.PdfFile
///
/// PDF 解析说明：
/// 1. PDF 以图片形式渲染，每页渲染为图片
/// 2. 章节分页，默认每 10 页为一章
/// 3. 内容返回 <img> 标签形式，由阅读器处理图片渲染
///
/// 依赖说明：
/// - 需要添加 pdfx 依赖到 pubspec.yaml
/// - iOS/macOS 需要配置 PDFKit
/// - Android 使用 PdfRenderer API
library;

import 'dart:io';
import 'dart:typed_data';
import '../../../data/models/book.dart';
import '../../../data/models/book_chapter.dart';
import '../../../utils/app_log.dart';

/// PDF 分页大小（每章包含的页数）
const int pdfPageSize = 10;

/// PDF 文件读取器
class PdfReader {
  /// PDF 渲染器（延迟初始化）
  dynamic _pdfDocument;

  /// 页数
  int _pageCount = 0;

  /// 是否已初始化
  bool _initialized = false;

  /// 错误信息
  String? _errorMessage;

  /// PDF 文件路径
  final String filePath;

  PdfReader(this.filePath);

  /// 获取页数
  int get pageCount => _pageCount;

  /// 是否可用
  bool get isAvailable => _initialized && _pdfDocument != null;

  /// 获取错误信息
  String? get errorMessage => _errorMessage;

  /// 初始化 PDF 文档
  Future<bool> initialize() async {
    if (_initialized) return isAvailable;

    try {
      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        _errorMessage = 'PDF 文件不存在';
        return false;
      }

      // 尝试加载 PDF
      // 注意：这里使用条件导入，如果 pdfx 不可用则使用占位实现
      final result = await _loadPdfDocument(file);
      if (result) {
        _initialized = true;
        return true;
      } else {
        _errorMessage = 'PDF 文件加载失败';
        return false;
      }
    } catch (e) {
      _errorMessage = 'PDF 初始化失败: $e';
      AppLog.instance.put('PDF 初始化失败: $e');
      return false;
    }
  }

  /// 加载 PDF 文档
  ///
  /// 注意：这是一个基础实现，实际使用时需要添加 pdfx 依赖
  /// 并使用 PdfDocument.openFile() 方法
  Future<bool> _loadPdfDocument(File file) async {
    try {
      // 基础实现：读取文件并检查 PDF 头部
      final bytes = await file.readAsBytes();
      if (bytes.length < 5) {
        _errorMessage = 'PDF 文件太小';
        return false;
      }

      // 检查 PDF 文件头 %PDF-
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      if (!header.startsWith('%PDF-')) {
        _errorMessage = '不是有效的 PDF 文件';
        return false;
      }

      // 尝试从文件中提取页数信息
      // 简化实现：搜索 /Count 标记来估算页数
      _pageCount = _estimatePageCount(bytes);
      if (_pageCount == 0) {
        // 如果无法获取页数，假设有 1 页
        _pageCount = 1;
      }

      // 存储字节数据用于后续渲染
      _pdfDocument = bytes;
      return true;
    } catch (e) {
      _errorMessage = '加载 PDF 失败: $e';
      return false;
    }
  }

  /// 估算 PDF 页数
  /// 通过搜索 PDF 内容中的 /Count 标记来估算
  int _estimatePageCount(Uint8List bytes) {
    try {
      // 将字节转换为字符串（仅用于搜索）
      final content = String.fromCharCodes(bytes);

      // 搜索 /Type /Pages 后面的 /Count 值
      // 这是一种简化的实现，可能不适用于所有 PDF
      final pagesPattern = RegExp(r'/Type\s*/Pages[^>]*?/Count\s*(\d+)');
      final match = pagesPattern.firstMatch(content);
      if (match != null) {
        final count = int.tryParse(match.group(1) ?? '');
        if (count != null && count > 0) {
          return count;
        }
      }

      // 备选方案：计算 /Type /Page 出现的次数
      final pagePattern = RegExp(r'/Type\s*/Page[^s]');
      final matches = pagePattern.allMatches(content);
      if (matches.isNotEmpty) {
        return matches.length;
      }

      return 1;
    } catch (e) {
      return 1;
    }
  }

  /// 获取章节列表
  List<BookChapter> getChapterList(Book book) {
    final chapters = <BookChapter>[];

    if (!isAvailable) {
      return chapters;
    }

    if (_pageCount > 0) {
      // 计算章节数（每 pdfPageSize 页一章）
      final chapterCount = (_pageCount / pdfPageSize).ceil();

      for (int i = 0; i < chapterCount; i++) {
        final startPage = i * pdfPageSize + 1;
        final endPage = ((i + 1) * pdfPageSize).clamp(1, _pageCount);

        chapters.add(BookChapter(
          url: 'pdf_$i',
          bookUrl: book.bookUrl,
          title: '第${i + 1}章 (第$startPage-$endPage页)',
          index: i,
        ));
      }
    }

    return chapters;
  }

  /// 获取章节内容
  /// 返回 HTML 格式的图片标签
  String? getContent(BookChapter chapter) {
    if (!isAvailable) {
      return null;
    }

    final buffer = StringBuffer();

    // 计算起始和结束页
    final start = chapter.index * pdfPageSize;
    final end = ((chapter.index + 1) * pdfPageSize).clamp(0, _pageCount);

    // 生成图片标签
    for (int pageIndex = start; pageIndex < end; pageIndex++) {
      buffer.write('<img src="$pageIndex" >\n');
    }

    return buffer.toString();
  }

  /// 获取页面图片
  ///
  /// 注意：当前基础实现不支持实际的图片渲染
  /// 需要添加 pdfx 依赖并实现真正的渲染逻辑
  Future<Uint8List?> getPageImage(int pageIndex) async {
    if (!isAvailable) {
      return null;
    }

    if (pageIndex < 0 || pageIndex >= _pageCount) {
      return null;
    }

    try {
      // 基础实现：返回占位图片
      // 实际使用时，应该使用 pdfx 库渲染 PDF 页面
      return _createPlaceholderImage(pageIndex);
    } catch (e) {
      AppLog.instance.put('渲染 PDF 页面失败: $e');
      return null;
    }
  }

  /// 创建占位图片
  /// 返回一个简单的灰色图片表示页面
  Uint8List _createPlaceholderImage(int pageIndex) {
    // 创建一个简单的 1x1 像素灰色 PNG
    // 实际应该渲染真正的 PDF 页面
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG 签名
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR 块头
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 像素
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, // 其他 IHDR 数据
      0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, // IDAT 块头
      0x08, 0xD7, 0x63, 0x78, 0x78, 0x78, 0x00, 0x00, // 灰色像素数据
      0x00, 0x05, 0x00, 0x01, 0x0A, 0x9D, 0x7A, 0x6A, // CRC
      0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND 块
      0xAE, 0x42, 0x60, 0x82, // IEND CRC
    ]);
  }

  /// 获取封面图片（第一页）
  Future<Uint8List?> getCoverImage() async {
    return await getPageImage(0);
  }

  /// 更新书籍信息
  void updateBookInfo(Book book) {
    if (book.name.isEmpty) {
      // 从文件名提取书名
      final fileName = filePath.split(Platform.pathSeparator).last;
      book.name =
          fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    }

    if (!isAvailable) {
      book.intro = 'PDF 书籍导入异常: ${_errorMessage ?? "未知错误"}';
    }
  }

  /// 关闭并释放资源
  void close() {
    _pdfDocument = null;
    _initialized = false;
  }
}

/// 检查是否支持 PDF
///
/// 注意：完整的 PDF 渲染需要添加 pdfx 依赖
/// 当前基础实现只支持读取 PDF 结构，不支持渲染
bool get isPdfSupported => true;

/// PDF 支持说明
const String pdfSupportNote = '''
PDF 支持说明：
当前实现为基础版本，仅支持读取 PDF 结构信息。
要获得完整的 PDF 渲染支持，请执行以下步骤：

1. 在 pubspec.yaml 中添加依赖：
   dependencies:
     pdfx: ^2.6.0

2. 运行 flutter pub get

3. iOS 需要在 Info.plist 中添加：
   <key>io.flutter.embedded_views_preview</key>
   <true/>

4. 然后重新编译应用
''';
