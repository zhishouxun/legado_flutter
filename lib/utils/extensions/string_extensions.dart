
/// 字符串扩展方法
/// 参考项目：StringExtensions.kt
extension StringExtensions on String? {
  /// 安全trim（null安全）
  /// 参考项目：StringExtensions.safeTrim
  String? safeTrim() {
    if (this == null || this!.trim().isEmpty) return null;
    return this!.trim();
  }

  /// 判断是否为content://
  /// 参考项目：StringExtensions.isContentScheme
  bool isContentScheme() {
    return this?.startsWith('content://') ?? false;
  }

  /// 判断是否为URI
  /// 参考项目：StringExtensions.isUri
  bool isUri() {
    if (this == null) return false;
    return this!.toLowerCase().startsWith('file://') || isContentScheme();
  }

  /// 判断是否为绝对URL
  /// 参考项目：StringExtensions.isAbsUrl
  bool isAbsUrl() {
    if (this == null) return false;
    final lower = this!.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// 判断是否为data: URL
  /// 参考项目：StringExtensions.isDataUrl
  bool isDataUrl() {
    if (this == null) return false;
    return RegExp(r'^data:').hasMatch(this!);
  }

  /// 判断是否为JSON
  /// 参考项目：StringExtensions.isJson
  bool isJson() {
    if (this == null) return false;
    final str = this!.trim();
    return (str.startsWith('{') && str.endsWith('}')) ||
        (str.startsWith('[') && str.endsWith(']'));
  }

  /// 判断是否为JSON对象
  /// 参考项目：StringExtensions.isJsonObject
  bool isJsonObject() {
    if (this == null) return false;
    final str = this!.trim();
    return str.startsWith('{') && str.endsWith('}');
  }

  /// 判断是否为JSON数组
  /// 参考项目：StringExtensions.isJsonArray
  bool isJsonArray() {
    if (this == null) return false;
    final str = this!.trim();
    return str.startsWith('[') && str.endsWith(']');
  }

  /// 判断是否为XML
  /// 参考项目：StringExtensions.isXml
  bool isXml() {
    if (this == null) return false;
    final str = this!.trim();
    return str.startsWith('<') && str.endsWith('>');
  }

  /// 判断字符串是否为true
  /// 参考项目：StringExtensions.isTrue
  bool isTrue({bool nullIsTrue = false}) {
    if (this == null || this!.trim().isEmpty || this == 'null') {
      return nullIsTrue;
    }
    return !RegExp(r'(?i)^(false|no|not|0)$').hasMatch(this!.trim());
  }

  /// 判断是否为十六进制
  /// 参考项目：StringExtensions.isHex
  bool isHex() {
    if (this == null) return false;
    return RegExp(r'^[0-9A-Fa-f]+$').hasMatch(this!);
  }

  /// 分割并过滤空白
  /// 参考项目：StringExtensions.splitNotBlank
  List<String> splitNotBlank(String delimiter, {int limit = 0}) {
    if (this == null) return [];
    return this!
        .split(delimiter)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 分割并过滤空白（正则表达式）
  List<String> splitNotBlankRegex(RegExp regex, {int limit = 0}) {
    if (this == null) return [];
    return this!
        .split(regex)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 中文排序比较
  /// 参考项目：StringExtensions.cnCompare
  int cnCompare(String other) {
    if (this == null) {
      return other.isEmpty ? 0 : -1;
    }
    if (other.isEmpty) {
      return this!.isEmpty ? 0 : 1;
    }
    
    // 使用 Dart 的字符串比较（支持中文）
    // 简化实现：使用默认比较，实际应该使用更完善的中文排序算法
    return this!.compareTo(other);
  }
}

/// 非空字符串扩展方法
extension NonNullStringExtensions on String {
  /// 转换为可编辑文本
  /// 参考项目：StringExtensions.toEditable
  /// 注意：Flutter 中不需要 Editable，直接返回 String
  String toEditable() => this;

  /// 解析为URI
  /// 参考项目：StringExtensions.parseToUri
  Uri parseToUri() {
    if (isUri()) {
      return Uri.parse(this);
    } else {
      // 文件路径
      return Uri.file(this);
    }
  }
}

