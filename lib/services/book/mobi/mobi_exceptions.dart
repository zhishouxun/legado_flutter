/// MOBI解析异常类
library;

/// MOBI文件格式异常
class MobiFormatException implements Exception {
  final String message;
  final String? details;

  MobiFormatException(this.message, [this.details]);

  @override
  String toString() {
    if (details != null) {
      return 'MobiFormatException: $message\nDetails: $details';
    }
    return 'MobiFormatException: $message';
  }
}

/// MOBI压缩格式不支持异常
class MobiCompressionException implements Exception {
  final int compressionType;
  final String message;

  MobiCompressionException(this.compressionType, [String? message])
      : message =
            message ?? '不支持的压缩格式: $compressionType. 支持的格式: Plain(1), LZ77(2)';

  @override
  String toString() => 'MobiCompressionException: $message';
}

/// MOBI编码格式不支持异常
class MobiEncodingException implements Exception {
  final int encoding;
  final String message;

  MobiEncodingException(this.encoding, [String? message])
      : message = message ??
            '不支持的编码格式: $encoding. 支持的格式: UTF-8(65001), Windows-1252(1252)';

  @override
  String toString() => 'MobiEncodingException: $message';
}

/// MOBI文件损坏异常
class MobiCorruptedException implements Exception {
  final String message;
  final String? location;

  MobiCorruptedException(this.message, [this.location]);

  @override
  String toString() {
    if (location != null) {
      return 'MobiCorruptedException: $message\nLocation: $location';
    }
    return 'MobiCorruptedException: $message';
  }
}

/// MOBI记录索引越界异常
class MobiIndexOutOfBoundsException implements Exception {
  final int index;
  final int maxIndex;
  final String recordType;

  MobiIndexOutOfBoundsException(this.index, this.maxIndex, this.recordType);

  @override
  String toString() =>
      'MobiIndexOutOfBoundsException: $recordType index $index is out of bounds (0..${maxIndex - 1})';
}
