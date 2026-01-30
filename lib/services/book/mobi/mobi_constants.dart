/// MOBI常量定义
library;

/// MOBI压缩格式常量
class MobiCompression {
  MobiCompression._();

  /// 无压缩
  static const int plain = 1;

  /// LZ77压缩
  static const int lz77 = 2;

  /// Huffcdic压缩
  static const int huffcdic = 17480;

  /// 获取压缩格式名称
  static String getName(int compression) {
    switch (compression) {
      case plain:
        return 'Plain';
      case lz77:
        return 'LZ77';
      case huffcdic:
        return 'Huffcdic';
      default:
        return 'Unknown';
    }
  }

  /// 检查是否支持
  static bool isSupported(int compression) {
    return compression == plain || compression == lz77;
  }
}

/// MOBI编码格式常量
class MobiEncoding {
  MobiEncoding._();

  /// UTF-8编码
  static const int utf8 = 65001;

  /// Windows-1252编码
  static const int windows1252 = 1252;

  /// 获取编码名称
  static String getName(int encoding) {
    switch (encoding) {
      case utf8:
        return 'UTF-8';
      case windows1252:
        return 'Windows-1252';
      default:
        return 'Unknown';
    }
  }

  /// 检查是否支持
  static bool isSupported(int encoding) {
    return encoding == utf8 || encoding == windows1252;
  }
}

/// MOBI文件类型常量
class MobiFileType {
  MobiFileType._();

  /// MOBI文件扩展名
  static const String mobi = '.mobi';

  /// AZW文件扩展名（旧版Kindle格式）
  static const String azw = '.azw';

  /// AZW3文件扩展名（新版Kindle格式）
  static const String azw3 = '.azw3';

  /// 所有支持的MOBI文件扩展名
  static const List<String> supportedExtensions = [mobi, azw, azw3];

  /// 检查文件扩展名是否支持
  static bool isSupported(String extension) {
    final lower = extension.toLowerCase();
    return supportedExtensions.contains(lower);
  }
}

/// MOBI格式版本常量
class MobiVersion {
  MobiVersion._();

  /// KF6（旧格式）
  static const int kf6 = 6;

  /// KF7（过渡格式）
  static const int kf7 = 7;

  /// KF8（新格式）
  static const int kf8 = 8;

  /// 获取版本名称
  static String getName(int version) {
    if (version >= kf8) {
      return 'KF8';
    } else if (version >= kf7) {
      return 'KF7';
    } else {
      return 'KF6';
    }
  }
}

/// MOBI记录类型常量
class MobiRecordType {
  MobiRecordType._();

  /// MOBI标识符
  static const String mobi = 'MOBI';

  /// EXTH标识符
  static const String exth = 'EXTH';

  /// INDX标识符
  static const String indx = 'INDX';

  /// TAGX标识符
  static const String tagx = 'TAGX';

  /// HUFF标识符
  static const String huff = 'HUFF';

  /// CDIC标识符
  static const String cdic = 'CDIC';
}

/// MOBI默认值常量
class MobiDefaults {
  MobiDefaults._();

  /// 默认预览长度（字符数）
  static const int previewLength = 500;

  /// 默认搜索最大结果数
  static const int maxSearchResults = 100;

  /// 默认章节预览长度
  static const int chapterPreviewLength = 300;
}
