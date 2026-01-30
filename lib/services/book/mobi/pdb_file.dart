/// PDB文件解析器
/// 参考项目：io.legado.app.lib.mobi.PDBFile
library;

import 'dart:io';
import 'dart:typed_data';
import 'mobi_utils.dart';

/// PDB文件类
class PDBFile {
  final RandomAccessFile _file;
  final List<int> _offsets;
  final String name;
  final String type;
  final String creator;
  final int recordCount;

  PDBFile._(
    this._file,
    this._offsets,
    this.name,
    this.type,
    this.creator,
    this.recordCount,
  );

  /// 从文件创建PDBFile
  static Future<PDBFile> fromFile(File file) async {
    final raf = await file.open();
    try {
      // 读取PDB头（79字节）
      final headerBytes = await raf.read(79);
      if (headerBytes.length < 79) {
        throw Exception('PDB文件头不完整');
      }

      final name = _readString(headerBytes, 0, 32);
      final type = _readString(headerBytes, 60, 4);
      final creator = _readString(headerBytes, 64, 4);
      final recordCount = headerBytes.readUInt16(76);

      // 读取记录偏移表
      final offsetTableBytes = await raf.read(recordCount * 8);
      if (offsetTableBytes.length < recordCount * 8) {
        throw Exception('PDB记录偏移表不完整');
      }

      final offsets = <int>[];
      for (int i = 0; i < recordCount; i++) {
        offsets.add(offsetTableBytes.readUInt32(i * 8));
      }

      return PDBFile._(raf, offsets, name, type, creator, recordCount);
    } catch (e) {
      await raf.close();
      rethrow;
    }
  }

  /// 读取记录数据
  Future<Uint8List> getRecordData(int index) async {
    if (index < 0 || index >= recordCount) {
      throw RangeError('Record index out of bounds: $index');
    }

    final startOffset = _offsets[index];
    final endOffset = index + 1 < _offsets.length
        ? _offsets[index + 1]
        : await _file.length();

    final length = endOffset - startOffset;
    await _file.setPosition(startOffset);
    final data = await _file.read(length);

    return data;
  }

  /// 获取文件大小
  Future<int> getFileSize() async {
    return await _file.length();
  }

  /// 关闭文件
  Future<void> close() async {
    await _file.close();
  }

  /// 读取字符串（移除null终止符）
  static String _readString(Uint8List bytes, int offset, int length) {
    final strBytes = bytes.readBytes(offset, length);
    final nullIndex = strBytes.indexOf(0);
    if (nullIndex >= 0) {
      return String.fromCharCodes(strBytes.sublist(0, nullIndex));
    }
    return String.fromCharCodes(strBytes);
  }
}
