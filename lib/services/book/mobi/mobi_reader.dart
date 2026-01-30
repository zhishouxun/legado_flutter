/// MOBI文件读取器
/// 参考项目：io.legado.app.lib.mobi.MobiReader
///
/// 使用示例：
/// ```dart
/// // 验证文件
/// final isValid = await MobiReader.isValidMobiFile(file);
/// if (!isValid) {
///   print('文件不是有效的MOBI文件');
///   return;
/// }
///
/// // 读取文件
/// final mobiBook = await MobiReader.readMobi(file);
/// try {
///   // 使用mobiBook...
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
import 'pdb_file.dart';
import 'mobi_book.dart';

/// MOBI读取器
class MobiReader {
  /// 验证MOBI文件
  /// 快速检查文件是否是有效的MOBI文件
  static Future<bool> isValidMobiFile(File file) async {
    try {
      if (!await file.exists()) return false;

      final pdbFile = await PDBFile.fromFile(file);
      try {
        // 检查记录0是否存在
        if (pdbFile.recordCount == 0) return false;

        // 读取记录0并检查MOBI标识
        final record0 = await pdbFile.getRecordData(0);
        if (record0.length < 20) return false;

        // 检查MOBI标识（偏移16）
        final identifier = record0.readString(16, 4);
        return identifier == 'MOBI';
      } finally {
        await pdbFile.close();
      }
    } catch (e) {
      return false;
    }
  }

  /// 读取MOBI文件
  static Future<SimpleMobiBook> readMobi(File file) async {
    if (!await file.exists()) {
      throw MobiFormatException('文件不存在: ${file.path}');
    }

    final pdbFile = await PDBFile.fromFile(file);
    try {
      // 读取记录0（MOBI头）
      if (pdbFile.recordCount == 0) {
        throw MobiFormatException('PDB文件没有记录', 'recordCount is 0');
      }

      final record0 = await pdbFile.getRecordData(0);
      if (record0.length < 20) {
        throw MobiFormatException(
            '记录0太短，无法读取MOBI头', 'record0.length: ${record0.length}');
      }

      final headers = _readMobiEntryHeaders(record0);

      final mobi = headers.mobi;
      final resourceStart = mobi.resourceStart;

      // 检查是否是KF8格式
      bool isKF8 = mobi.version >= 8;
      int kf8BoundaryOffset = 0;

      if (!isKF8) {
        // 检查是否有KF8边界记录
        final exth = headers.exth;
        final boundary = exth['boundary'] as int?;
        if (boundary != null && boundary != -1) {
          try {
            final boundaryRecord = await pdbFile.getRecordData(boundary);
            final boundaryHeaders = _readMobiEntryHeaders(boundaryRecord);
            if (boundaryHeaders.mobi.version >= 8) {
              kf8BoundaryOffset = boundary;
              isKF8 = true;
              // 使用边界记录的headers
              // headers = boundaryHeaders; // 注意：这里需要更新headers
            }
          } catch (e) {
            // 忽略错误，继续使用KF6
          }
        }
      }

      // 创建MOBI书籍对象
      return SimpleMobiBook(
        pdbFile: pdbFile,
        headers: headers,
        kf8BoundaryOffset: kf8BoundaryOffset,
        resourceStart: resourceStart,
        isKF8: isKF8,
      );
    } catch (e) {
      await pdbFile.close();
      rethrow;
    }
  }

  /// 读取MOBI入口头
  static MobiEntryHeaders _readMobiEntryHeaders(Uint8List record0) {
    // 读取PalmDoc头（16字节）
    final compression = record0.readUInt16(0);
    final numTextRecords = record0.readUInt16(8);
    final recordSize = record0.readUInt32(10);
    final encryption = record0.readUInt16(14);

    final palmdoc = PalmDocHeader(
      compression: compression,
      numTextRecords: numTextRecords,
      recordSize: recordSize,
      encryption: encryption,
    );

    // 读取MOBI头
    final mobi = _readMobiHeader(record0);

    // 读取EXTH头（如果存在）
    Map<String, dynamic> exth = {};
    if (mobi.exthFlag & 0x40 != 0) {
      final exthOffset = mobi.length + 16;
      if (exthOffset < record0.length) {
        exth = _readExth(record0.sublist(exthOffset));
      }
    }

    return MobiEntryHeaders(
      palmdoc: palmdoc,
      mobi: mobi,
      exth: exth,
    );
  }

  /// 读取MOBI头
  static MobiHeader _readMobiHeader(Uint8List buffer) {
    if (buffer.length < 260) {
      throw MobiFormatException(
          'MOBI头数据不完整', 'buffer.length: ${buffer.length}, required: >= 260');
    }

    // MOBI头从偏移16开始
    final identifier = buffer.readString(16, 4);
    if (identifier != 'MOBI') {
      throw MobiFormatException(
          '无效的MOBI标识符', 'expected: MOBI, got: $identifier');
    }

    final length = buffer.readUInt32(20);
    final type = buffer.readUInt32(24);
    final encoding = buffer.readUInt32(28);
    final uid = buffer.readUInt32(32);
    final version = buffer.readUInt32(36);
    final titleOffset = buffer.readUInt32(84);
    final titleLength = buffer.readUInt32(88);
    final localeRegion = buffer.readUInt32(92);
    final localeLanguage = buffer.readUInt32(96);
    final resourceStart = buffer.readUInt32(108);
    final huffcdic = buffer.readUInt32(112);
    final numHuffcdic = buffer.readUInt32(116);
    final exthFlag = buffer.readUInt32(128);
    final trailingFlags = buffer.readUInt32(236);
    final indx = buffer.readUInt32(244);

    // 读取标题
    final title = buffer.readString(titleOffset, titleLength);

    // 读取语言代码
    final language = _getLanguageCode(localeLanguage);

    return MobiHeader(
      identifier: identifier,
      length: length,
      type: type,
      encoding: encoding,
      uid: uid,
      version: version,
      titleOffset: titleOffset,
      titleLength: titleLength,
      localeRegion: localeRegion,
      localeLanguage: localeLanguage,
      resourceStart: resourceStart,
      huffcdic: huffcdic,
      numHuffcdic: numHuffcdic,
      exthFlag: exthFlag,
      trailingFlags: trailingFlags,
      indx: indx,
      title: title,
      language: language,
    );
  }

  /// 读取EXTH头
  static Map<String, dynamic> _readExth(Uint8List buffer) {
    final exth = <String, dynamic>{};

    if (buffer.length < 12) return exth;

    final magic = buffer.readString(0, 4);
    if (magic != 'EXTH') return exth;

    final count = buffer.readUInt32(8);
    int offset = 12;

    for (int i = 0; i < count && offset + 8 < buffer.length; i++) {
      final type = buffer.readUInt32(offset);
      final length = buffer.readUInt32(offset + 4);

      if (length < 8 || offset + length > buffer.length) break;

      final dataOffset = offset + 8;
      final dataLength = length - 8;

      // 根据类型解析数据
      final recordType = ExthRecordType.fromValue(type);
      if (recordType != ExthRecordType.unknown) {
        final data = buffer.readString(dataOffset, dataLength);
        if (recordType == ExthRecordType.author ||
            recordType == ExthRecordType.subject ||
            recordType == ExthRecordType.contributor) {
          // 多个值
          if (!exth.containsKey(recordType.name)) {
            exth[recordType.name] = <String>[];
          }
          (exth[recordType.name] as List<String>).add(data);
        } else if (recordType == ExthRecordType.kf8BoundaryOffset) {
          // 整数
          exth[recordType.name] = buffer.readUInt32(dataOffset);
        } else if (type == 201) {
          // coverOffset
          exth['coverOffset'] = buffer.readUInt32(dataOffset);
        } else if (type == 202) {
          // thumbnailOffset
          exth['thumbnailOffset'] = buffer.readUInt32(dataOffset);
        } else {
          // 字符串
          exth[recordType.name] = data;
        }
      }

      offset += length;
    }

    return exth;
  }

  /// 获取语言代码
  static String _getLanguageCode(int code) {
    // 简化实现，返回语言代码的字符串表示
    // 实际应该使用完整的语言代码映射表
    return 'en'; // 默认英语
  }
}
