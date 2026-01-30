import 'coroutine.dart';

/// 协程容器接口
/// 参考项目：io.legado.app.help.coroutine.CoroutineContainer
abstract class CoroutineContainer {
  /// 添加协程
  bool add<T>(Coroutine<T> coroutine);

  /// 批量添加协程
  bool addAll<T>(List<Coroutine<T>> coroutines);

  /// 移除协程（会自动取消）
  bool remove<T>(Coroutine<T> coroutine);

  /// 删除协程（不取消）
  bool delete<T>(Coroutine<T> coroutine);

  /// 清空所有协程（会自动取消所有）
  void clear();
}

