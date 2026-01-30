import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import '../../core/base/base_service.dart';
import '../../utils/app_log.dart';

/// 时间和电池监听器
/// 参考项目：io.legado.app.receiver.TimeBatteryReceiver
class TimeBatteryListener extends BaseService {
  static final TimeBatteryListener instance = TimeBatteryListener._init();
  TimeBatteryListener._init();

  Timer? _timeTimer;
  StreamSubscription<BatteryState>? _batterySubscription;
  final Battery _battery = Battery();
  
  int _currentBatteryLevel = 100;
  BatteryState _currentBatteryState = BatteryState.unknown;

  /// 时间变化回调（每分钟触发）
  /// 参考项目：TimeBatteryReceiver发送EventBus.TIME_CHANGED事件
  Function()? onTimeChanged;
  
  /// 电池变化回调
  /// [level] 电池电量（0-100）
  /// 参考项目：TimeBatteryReceiver发送EventBus.BATTERY_CHANGED事件
  Function(int level)? onBatteryChanged;

  int get batteryLevel => _currentBatteryLevel;
  BatteryState get batteryState => _currentBatteryState;

  /// 初始化监听
  /// 参考项目：TimeBatteryReceiver注册
  @override
  Future<void> onInit() async {
    try {
      // 初始化电池状态
      await _initBattery();
      
      // 监听电池变化
      _batterySubscription = _battery.onBatteryStateChanged.listen(
        (BatteryState state) async {
          _currentBatteryState = state;
          await _updateBatteryLevel();
        },
        onError: (error) {
          AppLog.instance.put('电池状态监听错误: $error', error: error);
        },
      );

      // 启动时间监听（每分钟触发）
      _timeTimer = Timer.periodic(
        const Duration(minutes: 1),
        (timer) {
          onTimeChanged?.call();
        },
      );
    } catch (e) {
      AppLog.instance.put('初始化时间和电池监听失败: $e', error: e);
    }
  }

  /// 初始化电池状态
  Future<void> _initBattery() async {
    try {
      _currentBatteryLevel = await _battery.batteryLevel;
      _currentBatteryState = await _battery.batteryState;
      onBatteryChanged?.call(_currentBatteryLevel);
    } catch (e) {
      AppLog.instance.put('获取电池状态失败: $e', error: e);
    }
  }

  /// 更新电池电量
  Future<void> _updateBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (level != _currentBatteryLevel) {
        _currentBatteryLevel = level;
        onBatteryChanged?.call(level);
      }
    } catch (e) {
      AppLog.instance.put('更新电池电量失败: $e', error: e);
    }
  }

  /// 取消监听
  @override
  Future<void> onDispose() async {
    _timeTimer?.cancel();
    _timeTimer = null;
    await _batterySubscription?.cancel();
    _batterySubscription = null;
  }

  /// 获取当前电池电量
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      AppLog.instance.put('获取电池电量失败: $e', error: e);
      return _currentBatteryLevel;
    }
  }

  /// 获取当前电池状态
  Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (e) {
      AppLog.instance.put('获取电池状态失败: $e', error: e);
      return _currentBatteryState;
    }
  }
}

