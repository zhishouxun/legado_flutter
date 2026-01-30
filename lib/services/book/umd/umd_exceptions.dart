/// UMD解析异常
class UmdFormatException implements Exception {
  final String message;
  final String? details;

  UmdFormatException(this.message, [this.details]);

  @override
  String toString() {
    if (details != null) {
      return 'UmdFormatException: $message ($details)';
    }
    return 'UmdFormatException: $message';
  }
}

class UmdCorruptedException implements Exception {
  final String message;

  UmdCorruptedException(this.message);

  @override
  String toString() => 'UmdCorruptedException: $message';
}

class UmdIndexOutOfBoundsException implements Exception {
  final int index;
  final int size;
  final String type;

  UmdIndexOutOfBoundsException(this.index, this.size, this.type);

  @override
  String toString() =>
      'UmdIndexOutOfBoundsException: Index $index out of bounds for $type (size: $size)';
}

