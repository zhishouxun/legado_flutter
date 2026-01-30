/// MOBI书籍类
/// 参考项目：io.legado.app.lib.mobi.MobiBook
///
/// 使用示例：
/// ```dart
/// // 读取MOBI文件
/// final mobiBook = await MobiReader.readMobi(file);
///
/// try {
///   // 获取元数据
///   final metadata = mobiBook.metadata;
///   print('标题: ${metadata.title}');
///   print('作者: ${metadata.creators.join(', ')}');
///
///   // 获取章节列表
///   final chapters = await mobiBook.getChapters();
///   print('章节数: ${chapters.length}');
///
///   // 获取章节内容
///   final content = await mobiBook.getChapterContent(chapters[0]);
///   print('第一章内容: ${content?.substring(0, 100)}...');
/// } finally {
///   await mobiBook.close();
/// }
/// ```
library;

import 'dart:io';
import 'dart:typed_data';
import 'mobi_entities.dart';
import 'mobi_utils.dart';
import 'mobi_exceptions.dart';
import 'mobi_constants.dart';
import 'pdb_file.dart';
import 'decompressor.dart';
import '../../../utils/app_log.dart';

/// MOBI书籍类
class SimpleMobiBook {
  final PDBFile pdbFile;
  final MobiEntryHeaders headers;
  final int kf8BoundaryOffset;
  final int resourceStart;
  final bool isKF8;

  // 缓存文本记录以提高性能
  final Map<int, Uint8List> _textRecordCache = {};

  // 缓存章节列表
  List<MobiChapter>? _chaptersCache;

  // 缓存NCX列表
  List<NCX>? _ncxCache;

  SimpleMobiBook({
    required this.pdbFile,
    required this.headers,
    required this.kf8BoundaryOffset,
    required this.resourceStart,
    required this.isKF8,
  });

  MobiHeader get mobi => headers.mobi;
  PalmDocHeader get palmdoc => headers.palmdoc;
  Map<String, dynamic> get exth => headers.exth;

  /// 获取字符集
  ///
  /// 支持的编码：
  /// - UTF-8 (65001)
  /// - Windows-1252 (1252)
  String get charset {
    switch (mobi.encoding) {
      case MobiEncoding.utf8:
        return 'utf-8';
      case MobiEncoding.windows1252:
        return 'windows-1252';
      default:
        AppLog.instance.put('未知的编码格式: ${mobi.encoding}，使用UTF-8');
        return 'utf-8';
    }
  }

  /// 获取解压缩器
  ///
  /// 支持的压缩格式：
  /// - Plain (1) - 无压缩
  /// - LZ77 (2) - LZ77压缩
  /// - Huffcdic (17480) - 不支持
  Decompressor get decompressor {
    switch (palmdoc.compression) {
      case MobiCompression.plain:
        return PlainDecompressor();
      case MobiCompression.lz77:
        return Lz77Decompressor(palmdoc.recordSize);
      case MobiCompression.huffcdic:
        // Huffcdic需要特殊处理
        throw MobiCompressionException(
          palmdoc.compression,
          'Huffcdic压缩格式当前不支持。请使用Plain或LZ77压缩的MOBI文件。',
        );
      default:
        AppLog.instance.put('未知的压缩格式: ${palmdoc.compression}，使用Plain解压缩器');
        return PlainDecompressor();
    }
  }

  /// 获取元数据
  MobiMetadata get metadata {
    final creators = exth['author'] is List
        ? (exth['author'] as List).cast<String>()
        : exth['author'] != null
            ? [exth['author'] as String]
            : <String>[];

    final subjects = exth['subject'] is List
        ? (exth['subject'] as List).cast<String>()
        : exth['subject'] != null
            ? [exth['subject'] as String]
            : <String>[];

    return MobiMetadata(
      uid: mobi.uid.toString(),
      title: exth['title'] as String? ?? mobi.title,
      creators: creators,
      publisher: exth['publisher'] as String? ?? '',
      language: exth['language'] as String? ?? mobi.language,
      date: exth['publishingDate'] as String? ?? '',
      description: exth['description'] as String? ?? '',
      subjects: subjects,
      rights: exth['rights'] as String? ?? '',
    );
  }

  /// 获取记录
  Future<Uint8List> getRecord(int index) async {
    try {
      return await pdbFile.getRecordData(kf8BoundaryOffset + index);
    } catch (e) {
      if (e is RangeError) {
        throw MobiIndexOutOfBoundsException(
          index,
          pdbFile.recordCount,
          'Record',
        );
      }
      rethrow;
    }
  }

  /// 获取文本记录（带缓存）
  Future<Uint8List> getTextRecord(int index) async {
    if (index < 0 || index >= palmdoc.numTextRecords) {
      throw MobiIndexOutOfBoundsException(
        index,
        palmdoc.numTextRecords,
        'TextRecord',
      );
    }

    // 检查缓存
    if (_textRecordCache.containsKey(index)) {
      return _textRecordCache[index]!;
    }

    var content = await getRecord(index + 1);
    content = _removeTrailingEntries(content);
    final decompressed = decompressor.decompress(content);

    // 缓存结果
    _textRecordCache[index] = decompressed;
    return decompressed;
  }

  /// 获取文本记录输入流（用于流式读取）
  /// 返回一个可以按需读取文本记录的迭代器
  Stream<Uint8List> getTextRecordStream() async* {
    for (int i = 0; i < palmdoc.numTextRecords; i++) {
      yield await getTextRecord(i);
    }
  }

  /// 获取文本总长度（字节数）
  ///
  /// [useCache] 是否使用缓存，默认true
  /// 如果useCache为false，会重新读取所有记录（较慢但准确）
  Future<int> getTotalTextLength({bool useCache = true}) async {
    int total = 0;

    if (useCache) {
      // 使用缓存快速计算
      for (int i = 0; i < palmdoc.numTextRecords; i++) {
        if (_textRecordCache.containsKey(i)) {
          total += _textRecordCache[i]!.length;
        } else {
          // 如果未缓存，需要读取
          final record = await getTextRecord(i);
          total += record.length;
        }
      }
    } else {
      // 不使用缓存，重新读取
      for (int i = 0; i < palmdoc.numTextRecords; i++) {
        final record = await getTextRecord(i);
        total += record.length;
      }
    }

    return total;
  }

  /// 移除尾部条目
  Uint8List _removeTrailingEntries(Uint8List byteArray) {
    final trailingFlags = mobi.trailingFlags;
    if (trailingFlags == 0) return byteArray;

    final multibyte = (trailingFlags & 1) != 0;
    final numTrailingEntries = trailingFlags.bitCount - 1; // 减去multibyte位

    int extraSize = 0;
    int lastIndex = byteArray.length - 1;

    for (int i = 0; i < numTrailingEntries; i++) {
      int value = 0;
      int startPos = (lastIndex - 4 - extraSize).clamp(0, lastIndex);
      for (int j = startPos;
          j <= (lastIndex - extraSize).clamp(0, lastIndex);
          j++) {
        final byte = byteArray[j];
        if ((byte & 0x80) != 0) {
          value = 0;
        }
        value = (value << 7) | (byte & 0x7F);
      }
      extraSize += value;
    }

    if (multibyte) {
      if (lastIndex - extraSize >= 0) {
        final byte = byteArray[lastIndex - extraSize];
        extraSize += (byte & 0x03) + 1;
      }
    }

    if (extraSize > 0 && extraSize < byteArray.length) {
      return byteArray.sublist(0, byteArray.length - extraSize);
    }

    return byteArray;
  }

  /// 获取资源
  Future<Uint8List> getResource(int index) async {
    try {
      return await pdbFile.getRecordData(resourceStart + index);
    } catch (e) {
      if (e is RangeError) {
        throw MobiIndexOutOfBoundsException(
          index,
          pdbFile.recordCount - resourceStart,
          'Resource',
        );
      }
      rethrow;
    }
  }

  /// 获取封面
  Future<Uint8List?> getCover() async {
    final coverOffset = exth['coverOffset'] as int?;
    final thumbnailOffset = exth['thumbnailOffset'] as int?;

    if (coverOffset != null && coverOffset != -1) {
      try {
        return await getResource(coverOffset);
      } catch (e) {
        AppLog.instance.put('获取封面失败', error: e);
      }
    }

    if (thumbnailOffset != null && thumbnailOffset != -1) {
      try {
        return await getResource(thumbnailOffset);
      } catch (e) {
        AppLog.instance.put('获取缩略图失败', error: e);
      }
    }

    return null;
  }

  /// 获取图片字节数组
  /// [src] 图片源（可以是资源索引或路径）
  /// 返回图片字节数组，如果获取失败返回null
  ///
  /// 注意：MOBI文件中的图片通常通过资源索引访问
  /// 如果src是数字字符串，则作为资源索引；否则尝试作为路径查找
  Future<Uint8List?> getImageBytes(String src) async {
    try {
      // 尝试作为资源索引
      final index = int.tryParse(src);
      if (index != null && index >= 0) {
        return await getResource(index);
      }

      // 如果不是数字，可能是路径，尝试查找对应的资源
      // 注意：MOBI文件中的图片资源通常通过索引访问，路径查找需要额外的解析
      // 这里简化处理，只支持索引访问
      AppLog.instance.put('MOBI图片路径查找暂不支持，请使用资源索引: $src');
      return null;
    } catch (e) {
      AppLog.instance.put('获取MOBI图片失败: $src', error: e);
      return null;
    }
  }

  /// 获取所有文本内容
  ///
  /// [onProgress] 进度回调 (current, total)
  /// 注意：对于大文件，建议使用流式读取或分章节读取
  Future<String> getAllText(
      {void Function(int current, int total)? onProgress}) async {
    final buffer = StringBuffer();
    final total = palmdoc.numTextRecords;

    for (int i = 0; i < total; i++) {
      try {
        final record = await getTextRecord(i);
        buffer.write(String.fromCharCodes(record));
        onProgress?.call(i + 1, total);
      } catch (e) {
        AppLog.instance.put('读取文本记录失败: $i', error: e);
      }
    }
    return buffer.toString();
  }

  /// 根据文件位置获取文本内容
  /// [filepos] 文件位置（字节偏移）
  /// [maxLength] 最大读取长度（可选，用于限制读取大小）
  Future<String> getTextByFilepos(int filepos, {int? maxLength}) async {
    if (filepos < 0) return '';

    // 计算在哪个文本记录中
    int currentOffset = 0;
    final buffer = StringBuffer();
    int remaining = maxLength ?? -1;

    for (int i = 0; i < palmdoc.numTextRecords; i++) {
      final record = await getTextRecord(i);
      final recordStart = currentOffset;
      final recordEnd = currentOffset + record.length;

      if (filepos >= recordStart && filepos < recordEnd) {
        // 在这个记录中
        final offsetInRecord = filepos - recordStart;
        final endOffset = remaining > 0
            ? (offsetInRecord + remaining).clamp(0, record.length)
            : record.length;

        final text =
            String.fromCharCodes(record.sublist(offsetInRecord, endOffset));
        buffer.write(text);

        if (remaining > 0) {
          remaining -= (endOffset - offsetInRecord);
          if (remaining <= 0) break;
        }

        // 继续读取后续记录
        for (int j = i + 1;
            j < palmdoc.numTextRecords && (remaining < 0 || remaining > 0);
            j++) {
          final nextRecord = await getTextRecord(j);
          final readLength = remaining > 0
              ? remaining.clamp(0, nextRecord.length)
              : nextRecord.length;

          final nextText =
              String.fromCharCodes(nextRecord.sublist(0, readLength));
          buffer.write(nextText);

          if (remaining > 0) {
            remaining -= readLength;
            if (remaining <= 0) break;
          }
        }
        break;
      }
      currentOffset += record.length;
    }

    return buffer.toString();
  }

  /// 根据起始位置和长度获取文本内容
  /// [start] 起始位置（字节偏移）
  /// [length] 长度（字节数）
  Future<String> getTextByRange(int start, int length) async {
    if (length <= 0) return '';

    // 计算在哪个文本记录中
    int currentOffset = 0;
    final buffer = StringBuffer();
    int remaining = length;
    int currentPos = start;

    for (int i = 0; i < palmdoc.numTextRecords && remaining > 0; i++) {
      final record = await getTextRecord(i);
      final recordStart = currentOffset;
      final recordEnd = currentOffset + record.length;

      if (currentPos < recordEnd && currentPos + remaining > recordStart) {
        // 这个记录有部分内容需要
        final startInRecord =
            (currentPos - recordStart).clamp(0, record.length);
        final endInRecord =
            ((currentPos + remaining) - recordStart).clamp(0, record.length);

        if (startInRecord < endInRecord) {
          final text =
              String.fromCharCodes(record.sublist(startInRecord, endInRecord));
          buffer.write(text);
          remaining -= (endInRecord - startInRecord);
          currentPos += (endInRecord - startInRecord);
        }
      }

      currentOffset += record.length;
    }

    return buffer.toString();
  }

  /// 根据章节href获取章节内容
  /// [href] 章节href，格式：filepos:0000000123 或 recindex:123
  Future<String?> getChapterContentByHref(String href) async {
    try {
      // 解析filepos格式：filepos:0000000123
      if (href.startsWith('filepos:')) {
        final posStr = href.substring(8).trim();
        final filepos = int.tryParse(posStr);
        if (filepos != null) {
          return await getTextByFilepos(filepos);
        }
      }

      // 解析recindex格式：recindex:123
      if (href.startsWith('recindex:')) {
        final indexStr = href.substring(9).trim();
        final index = int.tryParse(indexStr);
        if (index != null && index >= 0 && index < palmdoc.numTextRecords) {
          final record = await getTextRecord(index);
          return String.fromCharCodes(record);
        }
      }

      // 如果无法解析，返回null
      return null;
    } catch (e) {
      AppLog.instance.put('根据href获取章节内容失败: $href', error: e);
      return null;
    }
  }

  /// 根据章节信息获取章节内容
  /// [chapter] 章节信息
  Future<String?> getChapterContent(MobiChapter chapter) async {
    try {
      // 优先使用href
      if (chapter.href != null && chapter.href!.isNotEmpty) {
        final content = await getChapterContentByHref(chapter.href!);
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }

      // 如果href无效，使用start和length
      if (chapter.start >= 0 && chapter.length > 0) {
        return await getTextByRange(chapter.start, chapter.length);
      }

      // 如果都没有，返回null
      return null;
    } catch (e) {
      AppLog.instance.put('获取章节内容失败: ${chapter.title}', error: e);
      return null;
    }
  }

  /// 获取NCX章节列表（带缓存）
  Future<List<NCX>?> getNCX() async {
    // 检查缓存
    if (_ncxCache != null) {
      return _ncxCache;
    }

    final indxIndex = mobi.indx;
    if (indxIndex == -1) {
      return null;
    }

    try {
      final indexData = await getIndexData(indxIndex);
      final items = <NCX>[];

      for (int i = 0; i < indexData.table.length; i++) {
        final indexEntry = indexData.table[i];
        final tagMap = indexEntry.tagMap;

        final offset = tagMap[1]?.tagValues.firstOrNull;
        final size = tagMap[2]?.tagValues.firstOrNull;
        final labelIndex = tagMap[3]?.tagValues.firstOrNull;
        final label = labelIndex != null
            ? indexData.cncx[labelIndex] ?? indexEntry.label
            : indexEntry.label;
        final headingLevel = tagMap[4]?.tagValues.firstOrNull;
        final pos = tagMap[6]?.tagValues;
        final parent = tagMap[21]?.tagValues.firstOrNull;
        final firstChild = tagMap[22]?.tagValues.firstOrNull;
        final lastChild = tagMap[23]?.tagValues.firstOrNull;

        items.add(NCX(
          index: i,
          offset: offset,
          size: size,
          label: label,
          headingLevel: headingLevel,
          pos: pos,
          parent: parent,
          firstChild: firstChild,
          lastChild: lastChild,
        ));
      }

      // 构建父子关系
      final parentItemMap = <int, List<NCX>>{};
      for (final item in items) {
        if (item.parent != null) {
          parentItemMap.putIfAbsent(item.parent!, () => []).add(item);
        }
      }

      // 递归构建子节点
      NCX getChildren(NCX item) {
        if (item.firstChild == null) return item;
        item.children = parentItemMap[item.index]?.map(getChildren).toList();
        return item;
      }

      // 返回顶级节点（headingLevel == 0）
      final result = items
          .where((item) => item.headingLevel == 0 || item.headingLevel == null)
          .map(getChildren)
          .toList();

      // 缓存结果
      _ncxCache = result;
      return result;
    } catch (e) {
      AppLog.instance.put('解析NCX失败', error: e);
      return null;
    }
  }

  /// 获取索引数据
  Future<IndexData> getIndexData(int indxIndex) async {
    final indxRecord = await getRecord(indxIndex);
    final indx = _readIndxHeader(indxRecord);

    final tagxBuffer = indxRecord.sublist(indx.length);
    final tagx = _readTagxHeader(tagxBuffer);
    final tagTable = _readTagxTags(tagx, tagxBuffer);
    final cncx = await _readCncx(indxIndex, indx);

    final table = <IndexEntry>[];

    for (int i = 0; i < indx.numRecords; i++) {
      final indxBuffer = await getRecord(indxIndex + 1 + i);
      final indxHeader = _readIndxHeader(indxBuffer);
      final idxt = _readIdxt(indxBuffer, indxHeader);

      for (int j = 0; j < indxHeader.numRecords; j++) {
        final idxtOffset = idxt[j];
        final entry = _readIndexEntry(indxBuffer, tagx, tagTable, idxtOffset);
        table.add(entry);
      }
    }

    return IndexData(table: table, cncx: cncx);
  }

  /// 读取INDX头
  IndxHeader _readIndxHeader(Uint8List buffer) {
    if (buffer.length < 56) {
      throw MobiFormatException(
          'INDX头数据不完整', 'buffer.length: ${buffer.length}, required: >= 56');
    }

    final magic = buffer.readString(0, 4);
    if (magic != 'INDX') {
      throw MobiFormatException('无效的INDX标识符', 'expected: INDX, got: $magic');
    }

    final length = buffer.readUInt32(4);
    final type = buffer.readUInt32(8);
    final idxt = buffer.readUInt32(20);
    final numRecords = buffer.readUInt32(24);
    final encoding = buffer.readUInt32(28);
    final language = buffer.readUInt32(32);
    final total = buffer.readUInt32(36);
    final ordt = buffer.readUInt32(40);
    final ligt = buffer.readUInt32(44);
    final numLigt = buffer.readUInt32(48);
    final numCncx = buffer.readUInt32(52);

    return IndxHeader(
      magic: magic,
      length: length,
      type: type,
      idxt: idxt,
      numRecords: numRecords,
      encoding: encoding,
      language: language,
      total: total,
      ordt: ordt,
      ligt: ligt,
      numLigt: numLigt,
      numCncx: numCncx,
    );
  }

  /// 读取TAGX头
  TagxHeader _readTagxHeader(Uint8List buffer) {
    if (buffer.length < 12) {
      throw MobiFormatException(
          'TAGX头数据不完整', 'buffer.length: ${buffer.length}, required: >= 12');
    }

    final magic = buffer.readString(0, 4);
    if (magic != 'TAGX') {
      throw MobiFormatException('无效的TAGX标识符', 'expected: TAGX, got: $magic');
    }

    final length = buffer.readUInt32(4);
    final numControlBytes = buffer.readUInt32(8);

    return TagxHeader(
      magic: magic,
      length: length,
      numControlBytes: numControlBytes,
    );
  }

  /// 读取TAGX标签
  List<TagxTag> _readTagxTags(TagxHeader tagx, Uint8List buffer) {
    final numTags = (tagx.length - 12) ~/ 4;
    final tags = <TagxTag>[];

    int pos = 12;
    for (int i = 0; i < numTags && pos + 4 <= buffer.length; i++) {
      final tag = buffer.readUInt8(pos);
      final numValues = buffer.readUInt8(pos + 1);
      final bitmask = buffer.readUInt8(pos + 2);
      final controlByte = buffer.readUInt8(pos + 3);
      tags.add(TagxTag(
        tag: tag,
        numValues: numValues,
        bitmask: bitmask,
        controlByte: controlByte,
      ));
      pos += 4;
    }

    return tags;
  }

  /// 读取CNCX
  Future<Map<int, String>> _readCncx(int indxIndex, IndxHeader indx) async {
    final cncx = <int, String>{};
    int cncxRecordOffset = 0;

    for (int i = 0; i < indx.numCncx; i++) {
      final record = await getRecord(indxIndex + indx.numRecords + i + 1);
      int pos = 0;

      while (pos < record.length) {
        final index = pos;
        int value = 0;
        int length = 0;

        for (int a = pos; a < (pos + 4).clamp(0, record.length); a++) {
          final byte = record[a];
          value = (value << 7) | (byte & 0x7F);
          length++;
          if ((byte & 0x80) != 0) break;
        }

        pos += length;
        if (pos + value > record.length) break;

        final result = record.readString(pos, value, encoding: charset);
        pos += value;
        cncx[cncxRecordOffset + index] = result;
      }

      cncxRecordOffset += 0x10000;
    }

    return cncx;
  }

  /// 读取IDXT
  List<int> _readIdxt(Uint8List buffer, IndxHeader indxHeader) {
    return buffer.readUInt16Array(indxHeader.idxt + 4, indxHeader.numRecords);
  }

  /// 读取索引条目
  IndexEntry _readIndexEntry(Uint8List indxBuffer, TagxHeader tagx,
      List<TagxTag> tagTable, int idxtOffset) {
    final len = indxBuffer.readUInt8(idxtOffset);
    final label = indxBuffer.readString(idxtOffset + 1, len);

    final ptagxs = <Ptagx>[];
    final startPos = idxtOffset + 1 + len;
    int controlByteIndex = 0;
    int pos = startPos + tagx.numControlBytes;

    for (final tag in tagTable) {
      if (tag.controlByte == 1) {
        controlByteIndex++;
        continue;
      }

      final offset = startPos + controlByteIndex;
      int value = indxBuffer.readUInt8(offset) & tag.bitmask;

      if (value == tag.bitmask) {
        if (tag.bitmask.bitCount > 1) {
          int v = 0;
          for (int a = pos; a < (pos + 4).clamp(0, indxBuffer.length); a++) {
            final byte = indxBuffer[a];
            v = (v << 7) | (byte & 0x7F);
            pos++;
            if ((byte & 0x80) != 0) break;
          }
          ptagxs.add(Ptagx(
            tag: tag.tag,
            valueCount: v,
            tagValueCount: tag.numValues,
          ));
        } else {
          ptagxs.add(Ptagx(
            tag: tag.tag,
            valueCount: 1,
            tagValueCount: tag.numValues,
          ));
        }
      } else {
        int mask = tag.bitmask;
        while ((mask & 1) == 0) {
          mask = mask >> 1;
          value = value >> 1;
        }
        ptagxs.add(Ptagx(
          tag: tag.tag,
          valueCount: value,
          tagValueCount: tag.numValues,
        ));
      }
    }

    final tags = <IndexTag>[];
    final tagMap = <int, IndexTag>{};

    for (final ptagx in ptagxs) {
      final values = <int>[];

      if (ptagx.valueCount != null && ptagx.tagValueCount != null) {
        for (int i = 0; i < ptagx.valueCount! * ptagx.tagValueCount!; i++) {
          int v = 0;
          for (int a = pos; a < (pos + 4).clamp(0, indxBuffer.length); a++) {
            final byte = indxBuffer[a];
            v = (v << 7) | (byte & 0x7F);
            pos++;
            if ((byte & 0x80) != 0) break;
          }
          values.add(v);
        }
      } else if (ptagx.valueBytes != null) {
        int count = 0;
        while (count < ptagx.valueBytes! && pos < indxBuffer.length) {
          int v = 0;
          for (int a = pos; a < (pos + 4).clamp(0, indxBuffer.length); a++) {
            final byte = indxBuffer[a];
            v = (v << 7) | (byte & 0x7F);
            pos++;
            count++;
            if ((byte & 0x80) != 0) break;
          }
          values.add(v);
        }
      }

      final tag = IndexTag(tagId: ptagx.tag, tagValues: values);
      tags.add(tag);
      tagMap[tag.tagId] = tag;
    }

    return IndexEntry(label: label, tags: tags, tagMap: tagMap);
  }

  /// 获取章节列表（完整实现，带缓存）
  Future<List<MobiChapter>> getChapters() async {
    // 检查缓存
    if (_chaptersCache != null) {
      return _chaptersCache!;
    }

    // 尝试从NCX获取章节
    final ncxList = await getNCX();
    List<MobiChapter> chapters;

    if (ncxList != null && ncxList.isNotEmpty) {
      chapters = _convertNCXToChapters(ncxList);
    } else {
      // 如果没有NCX，返回整个文本作为一个章节
      final text = await getAllText();
      chapters = [
        MobiChapter(
          title: metadata.title,
          start: 0,
          length: text.length,
        ),
      ];
    }

    // 缓存结果
    _chaptersCache = chapters;
    return chapters;
  }

  /// 将NCX转换为章节列表
  List<MobiChapter> _convertNCXToChapters(List<NCX> ncxList) {
    final chapters = <MobiChapter>[];

    void addChapters(List<NCX> items) {
      for (final item in items) {
        chapters.add(MobiChapter(
          title: item.label,
          start: item.offset ?? 0,
          length: item.size ?? 0,
          href: item.offset != null
              ? 'filepos:${item.offset.toString().padLeft(10, '0')}'
              : null,
        ));

        if (item.children != null && item.children!.isNotEmpty) {
          addChapters(item.children!);
        }
      }
    }

    addChapters(ncxList);
    return chapters;
  }

  /// 清除缓存
  void clearCache() {
    _textRecordCache.clear();
    _chaptersCache = null;
    _ncxCache = null;
  }

  /// 预加载章节内容（用于提升阅读体验）
  /// [chapterIndices] 要预加载的章节索引列表
  /// [onProgress] 进度回调 (current, total)
  Future<void> preloadChapters(
    List<int> chapterIndices, {
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      final chapters = await getChapters();
      final total = chapterIndices.length;
      int current = 0;

      for (final index in chapterIndices) {
        if (index >= 0 && index < chapters.length) {
          final chapter = chapters[index];
          // 预加载章节内容（会利用缓存）
          await getChapterContent(chapter);
          current++;
          onProgress?.call(current, total);
        }
      }
    } catch (e) {
      AppLog.instance.put('预加载章节失败', error: e);
    }
  }

  /// 预加载相邻章节（用于提升翻页体验）
  /// [currentIndex] 当前章节索引
  /// [preloadCount] 前后各预加载的章节数，默认1
  Future<void> preloadAdjacentChapters(
    int currentIndex, {
    int preloadCount = 1,
  }) async {
    try {
      final chapters = await getChapters();
      final indices = <int>[];

      // 添加前面的章节
      for (int i = currentIndex - preloadCount; i < currentIndex; i++) {
        if (i >= 0) {
          indices.add(i);
        }
      }

      // 添加后面的章节
      for (int i = currentIndex + 1; i <= currentIndex + preloadCount; i++) {
        if (i < chapters.length) {
          indices.add(i);
        }
      }

      // 预加载
      await preloadChapters(indices);
    } catch (e) {
      AppLog.instance.put('预加载相邻章节失败', error: e);
    }
  }

  /// 获取章节数量
  Future<int> getChapterCount() async {
    final chapters = await getChapters();
    return chapters.length;
  }

  /// 检查是否有NCX索引
  bool get hasNCX => mobi.indx != -1;

  /// 获取文件信息摘要
  Future<Map<String, dynamic>> getFileInfo() async {
    final totalLength = await getTotalTextLength();
    final chapterCount = await getChapterCount();

    return {
      'title': metadata.title,
      'author': metadata.creators.join(', '),
      'publisher': metadata.publisher,
      'language': metadata.language,
      'description': metadata.description,
      'totalTextLength': totalLength,
      'chapterCount': chapterCount,
      'hasNCX': hasNCX,
      'isKF8': isKF8,
      'compression': MobiCompression.getName(palmdoc.compression),
      'compressionCode': palmdoc.compression,
      'encoding': MobiEncoding.getName(mobi.encoding),
      'encodingCode': mobi.encoding,
      'version': MobiVersion.getName(mobi.version),
      'versionCode': mobi.version,
      'numTextRecords': palmdoc.numTextRecords,
      'recordSize': palmdoc.recordSize,
    };
  }

  /// 验证文件完整性
  /// 检查文件的基本结构和数据完整性
  Future<Map<String, dynamic>> validateFile() async {
    final issues = <String>[];
    final warnings = <String>[];

    try {
      // 检查基本结构
      if (palmdoc.numTextRecords == 0) {
        issues.add('没有文本记录');
      }

      if (palmdoc.compression == 17480) {
        warnings.add('使用Huffcdic压缩，当前不支持');
      }

      // 检查编码
      if (mobi.encoding != 65001 && mobi.encoding != 1252) {
        warnings.add('使用非标准编码: ${mobi.encoding}');
      }

      // 尝试读取第一个文本记录
      try {
        if (palmdoc.numTextRecords > 0) {
          await getTextRecord(0);
        }
      } catch (e) {
        issues.add('无法读取第一个文本记录: $e');
      }

      // 检查NCX
      if (hasNCX) {
        try {
          final ncx = await getNCX();
          if (ncx == null || ncx.isEmpty) {
            warnings.add('NCX索引存在但无法解析');
          }
        } catch (e) {
          warnings.add('NCX索引解析失败: $e');
        }
      }

      return {
        'isValid': issues.isEmpty,
        'issues': issues,
        'warnings': warnings,
      };
    } catch (e) {
      issues.add('验证过程出错: $e');
      return {
        'isValid': false,
        'issues': issues,
        'warnings': warnings,
      };
    }
  }

  /// 批量获取文本记录（性能优化）
  /// [indices] 要获取的记录索引列表
  Future<Map<int, Uint8List>> getTextRecordsBatch(List<int> indices) async {
    final results = <int, Uint8List>{};

    // 去重并排序
    final uniqueIndices = indices.toSet().toList()..sort();

    for (final index in uniqueIndices) {
      if (index >= 0 && index < palmdoc.numTextRecords) {
        results[index] = await getTextRecord(index);
      }
    }

    return results;
  }

  /// 获取章节统计信息
  /// [chapterIndex] 章节索引
  Future<Map<String, dynamic>?> getChapterStatistics(int chapterIndex) async {
    try {
      final chapters = await getChapters();
      if (chapterIndex < 0 || chapterIndex >= chapters.length) {
        return null;
      }

      final chapter = chapters[chapterIndex];
      final content = await getChapterContent(chapter);

      if (content == null) {
        return null;
      }

      // 统计字符数、字数、段落数等
      final charCount = content.length;
      final wordCount =
          content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final paragraphCount =
          content.split('\n').where((p) => p.trim().isNotEmpty).length;
      final lineCount = content.split('\n').length;

      return {
        'chapterIndex': chapterIndex,
        'title': chapter.title,
        'charCount': charCount,
        'wordCount': wordCount,
        'paragraphCount': paragraphCount,
        'lineCount': lineCount,
        'start': chapter.start,
        'length': chapter.length,
        'hasContent': content.isNotEmpty,
      };
    } catch (e) {
      AppLog.instance.put('获取章节统计信息失败: $chapterIndex', error: e);
      return null;
    }
  }

  /// 获取所有章节的统计信息
  Future<List<Map<String, dynamic>>> getAllChaptersStatistics() async {
    final statistics = <Map<String, dynamic>>[];
    try {
      final chapters = await getChapters();
      for (int i = 0; i < chapters.length; i++) {
        final stats = await getChapterStatistics(i);
        if (stats != null) {
          statistics.add(stats);
        }
      }
    } catch (e) {
      AppLog.instance.put('获取所有章节统计信息失败', error: e);
    }
    return statistics;
  }

  /// 获取章节预览（前N个字符）
  ///
  /// [chapterIndex] 章节索引
  /// [previewLength] 预览长度（字符数），默认500
  ///
  /// 返回章节的前N个字符，智能截断在句子结束处
  ///
  /// 示例：
  /// ```dart
  /// final preview = await mobiBook.getChapterPreview(0, previewLength: 300);
  /// print(preview); // 输出前300个字符的预览
  /// ```
  Future<String?> getChapterPreview(int chapterIndex,
      {int previewLength = MobiDefaults.previewLength}) async {
    try {
      final chapters = await getChapters();
      if (chapterIndex < 0 || chapterIndex >= chapters.length) {
        return null;
      }

      final chapter = chapters[chapterIndex];
      final content = await getChapterContent(chapter);

      if (content == null || content.isEmpty) {
        return null;
      }

      if (content.length <= previewLength) {
        return content;
      }

      // 尝试在句号、问号、感叹号处截断
      final truncated = content.substring(0, previewLength);
      final lastSentenceEnd = [
        truncated.lastIndexOf('。'),
        truncated.lastIndexOf('！'),
        truncated.lastIndexOf('？'),
        truncated.lastIndexOf('.'),
        truncated.lastIndexOf('!'),
        truncated.lastIndexOf('?'),
      ].where((i) => i > previewLength * 0.7).fold(-1, (a, b) => a > b ? a : b);

      if (lastSentenceEnd > 0) {
        return '${truncated.substring(0, lastSentenceEnd + 1)}...';
      }

      return '$truncated...';
    } catch (e) {
      AppLog.instance.put('获取章节预览失败: $chapterIndex', error: e);
      return null;
    }
  }

  /// 获取相邻章节
  /// [currentIndex] 当前章节索引
  /// 返回 [上一章索引, 下一章索引]，如果不存在则为null
  Future<List<int?>> getAdjacentChapters(int currentIndex) async {
    try {
      final chapters = await getChapters();
      if (currentIndex < 0 || currentIndex >= chapters.length) {
        return [null, null];
      }

      final prevIndex = currentIndex > 0 ? currentIndex - 1 : null;
      final nextIndex =
          currentIndex < chapters.length - 1 ? currentIndex + 1 : null;

      return [prevIndex, nextIndex];
    } catch (e) {
      AppLog.instance.put('获取相邻章节失败: $currentIndex', error: e);
      return [null, null];
    }
  }

  /// 根据位置查找章节索引
  /// [position] 文本位置（字节偏移）
  Future<int?> findChapterByPosition(int position) async {
    try {
      final chapters = await getChapters();
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        if (chapter.start <= position &&
            (chapter.start + chapter.length) > position) {
          return i;
        }
      }
      return null;
    } catch (e) {
      AppLog.instance.put('根据位置查找章节失败: $position', error: e);
      return null;
    }
  }

  /// 获取章节范围的内容
  /// [startIndex] 起始章节索引
  /// [endIndex] 结束章节索引（包含）
  Future<String> getChaptersRange(int startIndex, int endIndex) async {
    final buffer = StringBuffer();
    try {
      final chapters = await getChapters();
      final start = startIndex.clamp(0, chapters.length - 1);
      final end = endIndex.clamp(0, chapters.length - 1);

      for (int i = start; i <= end; i++) {
        final chapter = chapters[i];
        final content = await getChapterContent(chapter);
        if (content != null && content.isNotEmpty) {
          buffer.writeln('=== ${chapter.title} ===');
          buffer.writeln(content);
          buffer.writeln();
        }
      }
    } catch (e) {
      AppLog.instance.put('获取章节范围内容失败: $startIndex-$endIndex', error: e);
    }
    return buffer.toString();
  }

  /// 导出为纯文本
  /// [outputPath] 输出文件路径
  Future<bool> exportToText(String outputPath) async {
    try {
      final file = File(outputPath);
      final sink = file.openWrite();

      try {
        // 写入元数据
        final meta = metadata;
        sink.writeln('标题: ${meta.title}');
        sink.writeln('作者: ${meta.creators.join(', ')}');
        sink.writeln('出版社: ${meta.publisher}');
        sink.writeln('语言: ${meta.language}');
        if (meta.description.isNotEmpty) {
          sink.writeln('简介: ${meta.description}');
        }
        sink.writeln('');
        sink.writeln('=' * 50);
        sink.writeln('');

        // 写入章节内容
        final chapters = await getChapters();
        for (int i = 0; i < chapters.length; i++) {
          final chapter = chapters[i];
          sink.writeln('第 ${i + 1} 章: ${chapter.title}');
          sink.writeln('-' * 50);

          final content = await getChapterContent(chapter);
          if (content != null && content.isNotEmpty) {
            sink.writeln(content);
          }

          sink.writeln('');
          sink.writeln('=' * 50);
          sink.writeln('');
        }
      } finally {
        await sink.close();
      }

      return true;
    } catch (e) {
      AppLog.instance.put('导出MOBI为文本失败: $outputPath', error: e);
      return false;
    }
  }

  /// 获取章节索引映射（用于快速查找）
  /// 返回一个Map，key是章节href，value是章节索引
  Future<Map<String, int>> getChapterIndexMap() async {
    final map = <String, int>{};
    try {
      final chapters = await getChapters();
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        if (chapter.href != null && chapter.href!.isNotEmpty) {
          map[chapter.href!] = i;
        }
      }
    } catch (e) {
      AppLog.instance.put('获取章节索引映射失败', error: e);
    }
    return map;
  }

  /// 根据章节标题查找章节索引
  /// [title] 章节标题（支持部分匹配）
  /// [exactMatch] 是否精确匹配，默认false
  Future<List<int>> findChaptersByTitle(String title,
      {bool exactMatch = false}) async {
    final indices = <int>[];
    try {
      final chapters = await getChapters();
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        if (exactMatch) {
          if (chapter.title == title) {
            indices.add(i);
          }
        } else {
          if (chapter.title.contains(title)) {
            indices.add(i);
          }
        }
      }
    } catch (e) {
      AppLog.instance.put('根据标题查找章节失败: $title', error: e);
    }
    return indices;
  }

  /// 获取章节摘要（用于目录显示）
  /// [maxChapters] 最大章节数，默认100
  Future<List<Map<String, dynamic>>> getChapterSummary(
      {int maxChapters = 100}) async {
    final summary = <Map<String, dynamic>>[];
    try {
      final chapters = await getChapters();
      final count = chapters.length.clamp(0, maxChapters);

      for (int i = 0; i < count; i++) {
        final chapter = chapters[i];
        summary.add({
          'index': i,
          'title': chapter.title,
          'start': chapter.start,
          'length': chapter.length,
          'href': chapter.href,
        });
      }
    } catch (e) {
      AppLog.instance.put('获取章节摘要失败', error: e);
    }
    return summary;
  }

  /// 检查章节是否存在
  /// [chapterIndex] 章节索引
  Future<bool> hasChapter(int chapterIndex) async {
    try {
      final chapters = await getChapters();
      return chapterIndex >= 0 && chapterIndex < chapters.length;
    } catch (e) {
      return false;
    }
  }

  /// 获取章节数量（快速版本，使用缓存）
  int getChapterCountSync() {
    if (_chaptersCache != null) {
      return _chaptersCache!.length;
    }
    // 如果没有缓存，返回-1表示需要异步获取
    return -1;
  }

  /// 关闭文件
  Future<void> close() async {
    clearCache();
    await pdbFile.close();
  }
}
