import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import '../../utils/app_log.dart';
import '../../data/models/book.dart';

/// EPUB 解析器
/// 使用 archive 包手动解析 EPUB 文件（EPUB 本质上是 ZIP 文件）
class EpubParser {
  /// 解析 EPUB 文件
  static Map<String, dynamic> parseEpub(Archive archive) {
    try {
      // 1. 读取 container.xml 找到 OPF 文件路径
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile == null) {
        throw Exception('EPUB 文件格式错误：找不到 container.xml');
      }

      final containerXml = utf8.decode(containerFile.content as List<int>);
      final containerDoc = xml.XmlDocument.parse(containerXml);
      final rootfile = containerDoc.findAllElements('rootfile').first;
      final opfPath = rootfile.getAttribute('full-path') ?? 'OEBPS/content.opf';

      // 2. 读取 OPF 文件
      final opfFile = archive.findFile(opfPath);
      if (opfFile == null) {
        throw Exception('EPUB 文件格式错误：找不到 OPF 文件');
      }

      final opfContent = utf8.decode(opfFile.content as List<int>);
      final opfDoc = xml.XmlDocument.parse(opfContent);

      // 3. 提取书籍信息
      final metadata = opfDoc.findAllElements('metadata').first;
      final title = metadata.findAllElements('title').firstOrNull?.innerText ?? '';
      final creator = metadata.findAllElements('creator').firstOrNull?.innerText ?? '';
      final description = metadata.findAllElements('description').firstOrNull?.innerText ?? '';

      // 4. 提取封面
      String? coverImagePath;
      final coverMeta = metadata.findAllElements('meta').where((e) => 
        e.getAttribute('name') == 'cover'
      ).firstOrNull;
      if (coverMeta != null) {
        final coverId = coverMeta.getAttribute('content');
        if (coverId != null) {
          final manifest = opfDoc.findAllElements('manifest').first;
          final coverItem = manifest.findAllElements('item').where((e) => 
            e.getAttribute('id') == coverId
          ).firstOrNull;
          if (coverItem != null) {
            coverImagePath = coverItem.getAttribute('href');
          }
        }
      }

      // 5. 提取章节列表
      final manifest = opfDoc.findAllElements('manifest').first;
      final spine = opfDoc.findAllElements('spine').first;
      
      final items = <String, String>{}; // id -> href
      for (final item in manifest.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) {
          items[id] = href;
        }
      }

      final chapters = <Map<String, String>>[];
      for (final itemref in spine.findAllElements('itemref')) {
        final idref = itemref.getAttribute('idref');
        if (idref != null && items.containsKey(idref)) {
          final href = items[idref]!;
          // 只处理 HTML/XHTML 文件
          if (href.toLowerCase().endsWith('.html') || 
              href.toLowerCase().endsWith('.xhtml') ||
              href.toLowerCase().endsWith('.htm')) {
            chapters.add({
              'id': idref,
              'href': href,
            });
          }
        }
      }

      // 6. 提取封面图片
      List<int>? coverImage;
      if (coverImagePath != null) {
        // 处理相对路径
        final opfDir = opfPath.substring(0, opfPath.lastIndexOf('/'));
        final fullCoverPath = coverImagePath.startsWith('/') 
            ? coverImagePath.substring(1)
            : '$opfDir/$coverImagePath';
        
        final coverFile = archive.findFile(fullCoverPath);
        if (coverFile != null) {
          coverImage = coverFile.content as List<int>;
        }
      }

      return {
        'title': title,
        'author': creator,
        'description': description,
        'chapters': chapters,
        'coverImage': coverImage,
        'opfPath': opfPath,
      };
    } catch (e) {
      AppLog.instance.put('解析 EPUB 文件失败', error: e);
      rethrow;
    }
  }

  /// 读取章节内容
  static String? getChapterContent(Archive archive, String opfPath, String chapterHref) {
    try {
      // 处理相对路径
      final opfDir = opfPath.substring(0, opfPath.lastIndexOf('/'));
      final fullPath = chapterHref.startsWith('/') 
          ? chapterHref.substring(1)
          : '$opfDir/$chapterHref';
      
      final chapterFile = archive.findFile(fullPath);
      if (chapterFile == null) {
        return null;
      }

      return utf8.decode(chapterFile.content as List<int>);
    } catch (e) {
      AppLog.instance.put('读取 EPUB 章节内容失败: $chapterHref', error: e);
      return null;
    }
  }

  /// 获取图片字节数组
  /// [book] 书籍对象
  /// [imagePath] 图片路径（相对于EPUB根目录）
  /// 返回图片字节数组，如果获取失败返回null
  static Future<Uint8List?> getImageBytes(Book book, String imagePath) async {
    try {
      final file = File(book.bookUrl);
      if (!await file.exists()) {
        return null;
      }

      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      
      // 处理相对路径
      final normalizedPath = imagePath.startsWith('/') 
          ? imagePath.substring(1)
          : imagePath;
      
      final imageFile = archive.findFile(normalizedPath);
      if (imageFile == null) {
        return null;
      }

      return Uint8List.fromList(imageFile.content as List<int>);
    } catch (e) {
      AppLog.instance.put('获取EPUB图片失败: $imagePath', error: e);
      return null;
    }
  }
}

