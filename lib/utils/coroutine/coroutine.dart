import 'dart:async';
import '../../core/exceptions/actively_cancel_exception.dart';

/// 链式协程
/// 参考项目：io.legado.app.help.coroutine.Coroutine
///
/// 注意：如果协程太快完成，回调可能会不执行
class Coroutine<T> {
  /// 静态工厂方法，创建协程实例
  /// 参考项目：Coroutine.async()
  static Coroutine<R> async<R>(Future<R> Function() block) {
    return Coroutine<R>._internal(block);
  }

  final Future<T> Function() _block;
  final Completer<T> _completer = Completer<T>();
  Timer? _timeoutTimer;
  bool _isCancelled = false;
  bool _isCompleted = false;
  bool _isActive = true;

  // 回调函数
  Future<void> Function()? _onStart;
  Future<void> Function(T)? _onSuccess;
  Future<void> Function(dynamic)? _onError;
  Future<void> Function()? _onFinally;
  Future<void> Function()? _onCancel;

  // 超时和错误返回值
  Duration? _timeout;
  T? _errorReturnValue;

  Coroutine._internal(Future<T> Function() block)
      : _block = block {
    _execute();
  }

  /// 是否已取消
  bool get isCancelled => _isCancelled;

  /// 是否活跃
  bool get isActive => _isActive && !_isCancelled && !_isCompleted;

  /// 是否已完成
  bool get isCompleted => _isCompleted;

  /// 设置超时时间
  /// 参考项目：Coroutine.timeout()
  Coroutine<T> timeout(Duration duration) {
    _timeout = duration;
    return this;
  }

  /// 设置超时时间（毫秒）
  Coroutine<T> timeoutMillis(int milliseconds) {
    return timeout(Duration(milliseconds: milliseconds));
  }

  /// 错误时返回默认值
  /// 参考项目：Coroutine.onErrorReturn()
  Coroutine<T> onErrorReturn(T? value) {
    _errorReturnValue = value;
    return this;
  }

  /// 错误时返回默认值（通过函数）
  Coroutine<T> onErrorReturnValue(T? Function() valueProvider) {
    _errorReturnValue = valueProvider();
    return this;
  }

  /// 开始执行时的回调
  /// 参考项目：Coroutine.onStart()
  Coroutine<T> onStart(Future<void> Function() callback) {
    _onStart = callback;
    return this;
  }

  /// 成功时的回调
  /// 参考项目：Coroutine.onSuccess()
  Coroutine<T> onSuccess(Future<void> Function(T) callback) {
    _onSuccess = callback;
    return this;
  }

  /// 错误时的回调
  /// 参考项目：Coroutine.onError()
  Coroutine<T> onError(Future<void> Function(dynamic) callback) {
    _onError = callback;
    return this;
  }

  /// 最终执行的回调（如果协程被取消，不执行）
  /// 参考项目：Coroutine.onFinally()
  Coroutine<T> onFinally(Future<void> Function() callback) {
    _onFinally = callback;
    return this;
  }

  /// 取消时的回调
  /// 参考项目：Coroutine.onCancel()
  Coroutine<T> onCancel(Future<void> Function() callback) {
    _onCancel = callback;
    return this;
  }

  /// 取消当前任务
  /// 参考项目：Coroutine.cancel()
  void cancel([ActivelyCancelException? cause]) {
    if (_isCancelled || _isCompleted) return;

    _isCancelled = true;
    _isActive = false;

    // 取消超时定时器
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    // 完成 Future（如果还未完成）
    if (!_completer.isCompleted) {
      _completer.completeError(
        cause ?? ActivelyCancelException(),
      );
    }

    // 执行取消回调
    _onCancel?.call().catchError((e) {
      // 忽略取消回调中的错误
    });
  }

  /// 设置完成处理器
  /// 参考项目：Coroutine.invokeOnCompletion()
  void invokeOnCompletion(Future<void> Function(dynamic)? handler) {
    _completer.future.then((value) {
      handler?.call(null);
    }).catchError((error) {
      handler?.call(error);
    });
  }

  /// 启动协程（如果还未启动）
  /// 参考项目：Coroutine.start()
  void start() {
    if (!_isActive && !_isCancelled && !_isCompleted) {
      _execute();
    }
  }

  /// 执行协程
  Future<void> _execute() async {
    if (_isCancelled || _isCompleted) return;

    try {
      // 执行开始回调
      if (_onStart != null) {
        await _onStart!();
      }

      if (_isCancelled) return;

      // 创建带超时的 Future
      Future<T> future = _block();

      if (_timeout != null) {
        future = future.timeout(
          _timeout!,
          onTimeout: () {
            throw TimeoutException('协程执行超时', _timeout!);
          },
        );
      }

      // 设置超时定时器（用于取消）
      if (_timeout != null) {
        _timeoutTimer = Timer(_timeout!, () {
          if (!_isCompleted && !_isCancelled) {
            cancel(ActivelyCancelException('协程执行超时'));
          }
        });
      }

      // 执行主逻辑
      final result = await future;

      // 取消超时定时器
      _timeoutTimer?.cancel();
      _timeoutTimer = null;

      if (_isCancelled) return;

      _isCompleted = true;
      _isActive = false;

      // 完成 Future
      if (!_completer.isCompleted) {
        _completer.complete(result);
      }

      // 执行成功回调
      if (_onSuccess != null) {
        await _onSuccess!(result);
      }

      // 执行最终回调
      if (_onFinally != null && !_isCancelled) {
        await _onFinally!();
      }
    } catch (e) {
      // 取消超时定时器
      _timeoutTimer?.cancel();
      _timeoutTimer = null;

      if (_isCancelled) return;

      _isCompleted = true;
      _isActive = false;

      // 检查是否有错误返回值
      if (_errorReturnValue != null) {
        if (!_completer.isCompleted) {
          _completer.complete(_errorReturnValue as T);
        }
        if (_onSuccess != null) {
          await _onSuccess!(_errorReturnValue as T);
        }
        if (_onFinally != null && !_isCancelled) {
          await _onFinally!();
        }
        return;
      }

      // 完成 Future（带错误）
      if (!_completer.isCompleted) {
        _completer.completeError(e);
      }

      // 执行错误回调
      if (_onError != null) {
        await _onError!(e);
      }

      // 执行最终回调（如果未被取消）
      if (_onFinally != null && !_isCancelled) {
        await _onFinally!();
      }
    }
  }

  /// 获取 Future（用于等待结果）
  Future<T> get future => _completer.future;
}

