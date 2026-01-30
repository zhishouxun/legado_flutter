/// 应用基础异常类
class AppException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(this.message, {this.originalError, this.stackTrace});

  @override
  String toString() => message;
}

/// 不记录错误堆栈的异常基类
/// 参考项目：io.legado.app.exception.NoStackTraceException
/// 
/// 用于不需要堆栈信息的业务逻辑异常
/// 注意：Dart 中无法完全阻止堆栈跟踪的生成，但可以通过不传递 stackTrace 来减少开销
class NoStackTraceException implements Exception {
  final String message;

  NoStackTraceException(this.message);

  @override
  String toString() => message;
}

/// 网络异常
class NetworkException extends AppException {
  NetworkException(super.message, {super.originalError, super.stackTrace});
}

/// 解析异常
class ParseException extends AppException {
  ParseException(super.message, {super.originalError, super.stackTrace});
}

/// 数据异常
class DataException extends AppException {
  DataException(super.message, {super.originalError, super.stackTrace});
}

/// 业务异常
class BusinessException extends AppException {
  BusinessException(super.message, {super.originalError, super.stackTrace});
}

/// 文件异常
class FileException extends AppException {
  FileException(super.message, {super.originalError, super.stackTrace});
}

/// 权限异常
class PermissionException extends AppException {
  PermissionException(super.message, {super.originalError, super.stackTrace});
}

/// 配置异常
class ConfigException extends AppException {
  ConfigException(super.message, {super.originalError, super.stackTrace});
}

/// 并发异常
/// 参考项目：io.legado.app.exception.ConcurrentException
class ConcurrentException extends NoStackTraceException {
  /// 等待时间（毫秒）
  final int waitTime;

  ConcurrentException(super.message, {required this.waitTime});
}

/// 内容为空异常
/// 参考项目：io.legado.app.exception.ContentEmptyException
class ContentEmptyException extends NoStackTraceException {
  ContentEmptyException(super.message);
}

/// 文件为空异常
/// 参考项目：io.legado.app.exception.EmptyFileException
class EmptyFileException extends NoStackTraceException {
  EmptyFileException(super.message);
}

/// 无效书籍目录异常
/// 参考项目：io.legado.app.exception.InvalidBooksDirException
class InvalidBooksDirException extends NoStackTraceException {
  InvalidBooksDirException(super.message);
}

/// 无书籍目录异常
/// 参考项目：io.legado.app.exception.NoBooksDirException
class NoBooksDirException extends NoStackTraceException {
  NoBooksDirException([String? message])
      : super(message ?? '未找到书籍目录');
}

/// 正则超时异常
/// 参考项目：io.legado.app.exception.RegexTimeoutException
class RegexTimeoutException extends NoStackTraceException {
  RegexTimeoutException(super.message);
}

/// 目录为空异常
/// 参考项目：io.legado.app.exception.TocEmptyException
class TocEmptyException extends NoStackTraceException {
  TocEmptyException(super.message);
}

/// 服务异常
class ServiceException extends AppException {
  ServiceException(super.message, {super.originalError, super.stackTrace});
}

