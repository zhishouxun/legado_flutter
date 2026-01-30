import 'package:permission_handler/permission_handler.dart';
import '../../utils/app_log.dart';
import '../exceptions/app_exceptions.dart' show ServiceException;

/// 服务基类
/// 所有服务类都应该继承此类，提供统一的生命周期管理
/// 参考项目：BaseService.kt
abstract class BaseService {
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isInitializing = false; // 防止递归初始化

  /// 初始化服务
  /// 子类应该重写此方法来实现具体的初始化逻辑
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    // 如果正在初始化，等待完成（防止递归调用）
    if (_isInitializing) {
      // 等待初始化完成，最多等待5秒
      var waitCount = 0;
      while (_isInitializing && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      return;
    }

    _isInitializing = true;
    try {
      await onInit();
      _isInitialized = true;
    } catch (e) {
      AppLog.instance.put('服务初始化失败: $runtimeType', error: e);
      throw ServiceException('服务初始化失败: $runtimeType', originalError: e);
    } finally {
      _isInitializing = false;
    }
  }

  /// 子类实现具体的初始化逻辑
  Future<void> onInit() async {}

  /// 销毁服务
  /// 子类应该重写此方法来实现具体的清理逻辑
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    try {
      await onDispose();
      _isDisposed = true;
      _isInitialized = false;
    } catch (e) {
      AppLog.instance.put('服务销毁失败: $runtimeType', error: e);
    }
  }

  /// 子类实现具体的清理逻辑
  Future<void> onDispose() async {}

  /// 检查服务是否已初始化
  bool get isInitialized => _isInitialized;

  /// 检查服务是否已销毁
  bool get isDisposed => _isDisposed;

  /// 确保服务已初始化
  void ensureInitialized() {
    if (!_isInitialized) {
      throw ServiceException('服务未初始化: $runtimeType');
    }
  }

  /// 执行异步操作，自动处理错误和日志
  Future<T> execute<T>({
    required Future<T> Function() action,
    String? operationName,
    bool logError = true,
    T? defaultValue,
  }) async {
    try {
      // 如果正在初始化，等待初始化完成（防止在 onInit 中调用 execute 导致递归）
      if (_isInitializing) {
        var waitCount = 0;
        while (_isInitializing && waitCount < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }
      }

      // 如果未初始化且不在初始化中，才调用 init
      if (!_isInitialized && !_isInitializing) {
        await init();
      }

      final result = await action();
      return result;
    } catch (e) {
      final errorMsg =
          operationName != null ? '操作失败: $operationName' : '操作失败: $runtimeType';

      if (logError) {
        AppLog.instance.put(errorMsg, error: e);
      }

      if (defaultValue != null) {
        return defaultValue;
      }

      rethrow;
    }
  }

  /// 检查权限
  /// 返回 true 表示有权限，false 表示无权限
  Future<bool> checkPermission(Permission permission) async {
    try {
      final status = await permission.status;
      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final result = await permission.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        AppLog.instance.put('权限被永久拒绝: ${permission.toString()}');
        return false;
      }

      return false;
    } catch (e) {
      AppLog.instance.put('检查权限失败: ${permission.toString()}', error: e);
      return false;
    }
  }

  /// 检查多个权限
  /// 返回所有权限的检查结果
  Future<Map<Permission, bool>> checkPermissions(
      List<Permission> permissions) async {
    final results = <Permission, bool>{};
    for (final permission in permissions) {
      results[permission] = await checkPermission(permission);
    }
    return results;
  }

  /// 请求权限（如果未授予）
  Future<bool> requestPermission(Permission permission) async {
    return await checkPermission(permission);
  }

  /// 请求多个权限
  Future<Map<Permission, bool>> requestPermissions(
      List<Permission> permissions) async {
    return await checkPermissions(permissions);
  }
}
