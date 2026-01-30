import 'dart:collection';
import 'coroutine.dart';
import 'coroutine_container.dart';

/// 复合协程容器
/// 参考项目：io.legado.app.help.coroutine.CompositeCoroutine
class CompositeCoroutine implements CoroutineContainer {
  final Set<Coroutine<dynamic>> _coroutines = HashSet<Coroutine<dynamic>>();

  /// 容器大小
  int get size => _coroutines.length;

  /// 是否为空
  bool get isEmpty => _coroutines.isEmpty;

  /// 构造函数
  CompositeCoroutine();

  /// 从多个协程创建
  CompositeCoroutine.fromList(List<Coroutine<dynamic>> coroutines) {
    _coroutines.addAll(coroutines);
  }

  /// 从多个协程创建（可变参数）
  CompositeCoroutine.fromCoroutines(Coroutine<dynamic> coroutine, [Coroutine<dynamic>? coroutine2, Coroutine<dynamic>? coroutine3, Coroutine<dynamic>? coroutine4, Coroutine<dynamic>? coroutine5]) {
    _coroutines.add(coroutine);
    if (coroutine2 != null) _coroutines.add(coroutine2);
    if (coroutine3 != null) _coroutines.add(coroutine3);
    if (coroutine4 != null) _coroutines.add(coroutine4);
    if (coroutine5 != null) _coroutines.add(coroutine5);
  }

  @override
  bool add<T>(Coroutine<T> coroutine) {
    return _coroutines.add(coroutine as Coroutine<dynamic>);
  }

  @override
  bool addAll<T>(List<Coroutine<T>> coroutines) {
    bool allAdded = true;
    for (final coroutine in coroutines) {
      if (!_coroutines.add(coroutine as Coroutine<dynamic>)) {
        allAdded = false;
      }
    }
    return allAdded;
  }

  @override
  bool remove<T>(Coroutine<T> coroutine) {
    if (delete(coroutine)) {
      coroutine.cancel();
      return true;
    }
    return false;
  }

  @override
  bool delete<T>(Coroutine<T> coroutine) {
    return _coroutines.remove(coroutine as Coroutine<dynamic>);
  }

  @override
  void clear() {
    final coroutines = List<Coroutine<dynamic>>.from(_coroutines);
    _coroutines.clear();
    for (final coroutine in coroutines) {
      coroutine.cancel();
    }
  }
}

