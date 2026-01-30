/// MOBI解析工具类
/// 参考项目：io.legado.app.lib.mobi.utils
library;

import 'dart:typed_data';

/// ByteBuffer扩展方法
extension ByteBufferExtensions on Uint8List {
  /// 读取无符号8位整数
  int readUInt8(int offset) {
    if (offset >= length) return 0;
    return this[offset] & 0xFF;
  }

  /// 读取无符号16位整数（小端序）
  int readUInt16(int offset) {
    if (offset + 1 >= length) return 0;
    return (this[offset] & 0xFF) | ((this[offset + 1] & 0xFF) << 8);
  }

  /// 读取无符号32位整数（小端序）
  int readUInt32(int offset) {
    if (offset + 3 >= length) return 0;
    return (this[offset] & 0xFF) |
        ((this[offset + 1] & 0xFF) << 8) |
        ((this[offset + 2] & 0xFF) << 16) |
        ((this[offset + 3] & 0xFF) << 24);
  }

  /// 读取字符串
  String readString(int offset, int length, {String encoding = 'utf-8'}) {
    if (offset + length > this.length) {
      length = this.length - offset;
    }
    if (length <= 0) return '';

    var bytes = sublist(offset, offset + length);

    // 移除null终止符
    int nullIndex = bytes.indexOf(0);
    if (nullIndex >= 0) {
      bytes = bytes.sublist(0, nullIndex);
    }

    try {
      if (encoding == 'utf-8') {
        return String.fromCharCodes(bytes);
      } else if (encoding == 'windows-1252') {
        // 简化处理，使用latin1
        return String.fromCharCodes(bytes);
      }
      return String.fromCharCodes(bytes);
    } catch (e) {
      return '';
    }
  }

  /// 读取字节数组
  Uint8List readBytes(int offset, int length) {
    if (offset + length > this.length) {
      length = this.length - offset;
    }
    if (length <= 0) return Uint8List(0);
    return sublist(offset, offset + length);
  }

  /// 读取无符号16位整数数组
  List<int> readUInt16Array(int offset, int count) {
    final result = <int>[];
    for (int i = 0; i < count; i++) {
      result.add(readUInt16(offset + i * 2));
    }
    return result;
  }
}

/// 位操作扩展
extension BitwiseExtensions on int {
  /// 检查位是否设置
  bool hasBit(int bit) {
    return (this & bit) != 0;
  }

  /// 设置位
  int setBit(int bit) {
    return this | bit;
  }

  /// 清除位
  int clearBit(int bit) {
    return this & ~bit;
  }

  /// 计算设置位的数量
  int get bitCount {
    int count = 0;
    int n = this;
    while (n != 0) {
      count++;
      n &= n - 1;
    }
    return count;
  }
}
