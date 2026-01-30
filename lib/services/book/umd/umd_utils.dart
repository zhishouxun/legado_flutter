/// UMD工具类
library;

import 'dart:typed_data';

/// UMD字节数组扩展方法
extension UmdByteListExtension on Uint8List {
  /// 读取字符串（GBK编码）
  String readStringGBK(int offset, int length) {
    final end = (offset + length).clamp(0, this.length);
    final bytes = sublist(offset, end);
    // 简化实现：使用UTF-8解码，实际UMD文件可能使用GBK编码
    // 如果需要完整支持，需要使用GBK解码库
    try {
      return String.fromCharCodes(bytes);
    } catch (e) {
      // 如果UTF-8解码失败，尝试其他方式
      return String.fromCharCodes(
          bytes.map((b) => b < 128 ? b : 63)); // 替换非ASCII字符为?
    }
  }

  /// 读取UInt16（小端序）
  int readUInt16LE(int offset) {
    if (offset + 2 > length) return 0;
    return this[offset] | (this[offset + 1] << 8);
  }

  /// 读取UInt32（小端序）
  int readUInt32LE(int offset) {
    if (offset + 4 > length) return 0;
    return this[offset] |
        (this[offset + 1] << 8) |
        (this[offset + 2] << 16) |
        (this[offset + 3] << 24);
  }

  /// 查找字节序列
  int indexOfBytes(List<int> pattern, [int start = 0]) {
    if (pattern.isEmpty) return start;
    if (start >= length) return -1;

    for (int i = start; i <= length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (this[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}
