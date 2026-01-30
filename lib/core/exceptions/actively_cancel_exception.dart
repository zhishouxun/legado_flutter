/// 主动取消异常类
/// 参考项目：io.legado.app.help.coroutine.ActivelyCancelException
///
/// 用于区分主动取消和被动取消
/// 注意：Dart 中的异常类没有 fillInStackTrace() 方法，
/// 但可以通过不传递 stackTrace 来实现类似的效果（减少性能开销）
class ActivelyCancelException implements Exception {
  final String message;

  ActivelyCancelException([this.message = '协程被主动取消']);

  @override
  String toString() => message;
}

