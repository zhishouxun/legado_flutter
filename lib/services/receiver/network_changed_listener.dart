import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/base/base_service.dart';
import '../../utils/app_log.dart';

/// 网络变化监听器
/// 参考项目：io.legado.app.receiver.NetworkChangedListener
class NetworkChangedListener extends BaseService {
  static final NetworkChangedListener instance = NetworkChangedListener._init();
  NetworkChangedListener._init();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final Connectivity _connectivity = Connectivity();
  List<ConnectivityResult> _currentConnectivity = [ConnectivityResult.none];
  
  /// 网络变化回调
  /// [results] 当前网络连接状态列表
  Function(List<ConnectivityResult> results)? onNetworkChanged;
  
  /// 获取当前网络状态
  List<ConnectivityResult> get currentConnectivity => List.unmodifiable(_currentConnectivity);

  /// 注册监听
  /// 参考项目：NetworkChangedListener.register()
  @override
  Future<void> onInit() async {
    try {
      // 获取初始网络状态
      _currentConnectivity = await _connectivity.checkConnectivity();
      
      // 监听网络变化
      _subscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final hasChanged = !_listsEqual(_currentConnectivity, results);
          _currentConnectivity = results;
          
          if (hasChanged) {
            AppLog.instance.put('网络状态变化: $results');
            onNetworkChanged?.call(results);
          }
        },
        onError: (error) {
          AppLog.instance.put('网络变化监听错误: $error', error: error);
        },
      );
    } catch (e) {
      AppLog.instance.put('注册网络变化监听失败: $e', error: e);
    }
  }
  
  /// 比较两个ConnectivityResult列表是否相等
  bool _listsEqual(List<ConnectivityResult> a, List<ConnectivityResult> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.every((item) => setB.contains(item));
  }

  /// 取消注册
  /// 参考项目：NetworkChangedListener.unRegister()
  @override
  Future<void> onDispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// 获取当前网络状态
  /// 参考项目：NetworkChangedListener.getConnectivity()
  Future<List<ConnectivityResult>> getCurrentConnectivity() async {
    try {
      _currentConnectivity = await _connectivity.checkConnectivity();
      return List.unmodifiable(_currentConnectivity);
    } catch (e) {
      AppLog.instance.put('获取网络状态失败: $e', error: e);
      return [ConnectivityResult.none];
    }
  }

  /// 检查是否有网络连接
  /// 参考项目：NetworkChangedListener.isAvailable()
  Future<bool> hasConnection() async {
    final results = await getCurrentConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
  
  /// 检查当前是否有网络连接（同步方法，使用缓存的网络状态）
  bool get isAvailable {
    return _currentConnectivity.any((result) => result != ConnectivityResult.none);
  }
  
  /// 检查是否是WiFi连接
  bool get isWifi {
    return _currentConnectivity.contains(ConnectivityResult.wifi);
  }
  
  /// 检查是否是移动数据连接
  bool get isMobile {
    return _currentConnectivity.contains(ConnectivityResult.mobile);
  }
}

