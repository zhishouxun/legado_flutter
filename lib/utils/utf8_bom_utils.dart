import 'dart:typed_data';

/// UTF-8 BOM工具类
/// 参考项目：Utf8BomUtils.kt
class Utf8BomUtils {
  static const List<int> _utf8BomBytes = [0xEF, 0xBB, 0xBF];

  /// 移除UTF-8 BOM标记（字符串版本）
  /// 参考项目：Utf8BomUtils.removeUTF8BOM(String)
  static String removeUTF8BOM(String xmlText) {
    final bytes = xmlText.codeUnits;
    final containsBOM = bytes.length >= 3 &&
        bytes[0] == _utf8BomBytes[0] &&
        bytes[1] == _utf8BomBytes[1] &&
        bytes[2] == _utf8BomBytes[2];

    if (containsBOM) {
      // 移除前3个字符（BOM标记）
      return xmlText.substring(3);
    }
    return xmlText;
  }

  /// 移除UTF-8 BOM标记（字节数组版本）
  /// 参考项目：Utf8BomUtils.removeUTF8BOM(ByteArray)
  static Uint8List removeUTF8BOMBytes(Uint8List bytes) {
    final containsBOM = bytes.length >= 3 &&
        bytes[0] == _utf8BomBytes[0] &&
        bytes[1] == _utf8BomBytes[1] &&
        bytes[2] == _utf8BomBytes[2];

    if (containsBOM) {
      // 移除前3个字节（BOM标记）
      return Uint8List.sublistView(bytes, 3);
    }
    return bytes;
  }

  /// 判断是否有BOM
  /// 参考项目：Utf8BomUtils.hasBom
  static bool hasBom(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == _utf8BomBytes[0] &&
        bytes[1] == _utf8BomBytes[1] &&
        bytes[2] == _utf8BomBytes[2];
  }
}

