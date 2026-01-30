/// MOBI解压缩器
/// 参考项目：io.legado.app.lib.mobi.decompress
library;

import 'dart:typed_data';

/// 解压缩器接口
abstract class Decompressor {
  Uint8List decompress(Uint8List data);
}

/// 无压缩解压缩器
class PlainDecompressor implements Decompressor {
  @override
  Uint8List decompress(Uint8List data) {
    return data;
  }
}

/// LZ77解压缩器
class Lz77Decompressor implements Decompressor {
  final int textRecordSize;

  Lz77Decompressor(this.textRecordSize);

  @override
  Uint8List decompress(Uint8List data) {
    final out = Uint8List(textRecordSize);
    int i = 0;
    int o = 0;

    while (i < data.length) {
      int c = data[i++] & 0xFF;

      if (c >= 0x01 && c <= 0x08) {
        // 直接复制字节
        int j = 0;
        while (j < c && i + j < data.length && o < out.length) {
          out[o++] = data[i + j];
          j++;
        }
        i += c;
      } else if (c <= 0x7F) {
        // 单个字符
        if (o < out.length) {
          out[o++] = c;
        }
      } else if (c >= 0xC0) {
        // 空格 + 字符
        if (o + 1 < out.length) {
          out[o++] = 0x20; // 空格
          out[o++] = (c ^ 0x80);
        }
      } else {
        // LZ77压缩
        if (i < data.length) {
          c = (c << 8) | (data[i++] & 0xFF);
          final length = (c & 0x0007) + 3;
          final location = (c >> 3) & 0x7FF;

          if (location >= 1 && location <= o) {
            for (int j = 0; j < length && o < out.length; j++) {
              final idx = o - location;
              if (idx >= 0 && idx < o) {
                out[o++] = out[idx];
              } else {
                break;
              }
            }
          }
        }
      }
    }

    return out.sublist(0, o);
  }
}

/// CDIC条目
class CDICEntry {
  Uint8List data;
  bool decompressed;

  CDICEntry(this.data, this.decompressed);
}

/// Huffcdic解压缩器
/// 注意：这是一个基础实现，可能无法处理所有Huffcdic压缩的文件
class HuffcdicDecompressor implements Decompressor {
  final Uint8List huffRecord;
  final int offset1;
  final int offset2;
  final List<int> table1;
  final List<int> mincodeTable;
  final List<int> maxcodeTable;
  final List<CDICEntry> dictionary;

  HuffcdicDecompressor({
    required this.huffRecord,
    required this.offset1,
    required this.offset2,
    required this.table1,
    required this.mincodeTable,
    required this.maxcodeTable,
    required this.dictionary,
  });

  @override
  Uint8List decompress(Uint8List data) {
    // Huffcdic解压缩非常复杂，这里提供一个基础框架
    // 完整实现需要处理位操作、Huffman树等
    // 对于大多数MOBI文件，Huffcdic压缩并不常用

    // 简化实现：尝试直接返回数据（某些情况下可能有效）
    // 如果失败，会抛出异常，调用者可以处理
    throw UnimplementedError(
        'Huffcdic decompression requires full implementation. '
        'This format is rarely used in MOBI files. '
        'Please use Plain or LZ77 compressed MOBI files instead.');
  }
}
