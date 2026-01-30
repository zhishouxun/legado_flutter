/// 时间工具类
/// 参考项目：TimeUtils.kt
class TimeUtils {
  /// 将时间戳转换为相对时间显示
  /// 参考项目：Long.toTimeAgo()
  static String toTimeAgo(int timestamp) {
    final curTime = DateTime.now().millisecondsSinceEpoch;
    final time = timestamp;
    final diff = (curTime - time).abs();
    final seconds = diff / 1000.0;
    final end = time < curTime ? '前' : '后';

    String start;
    if (seconds < 60) {
      start = '${seconds.toInt()}秒';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).floor();
      start = '$minutes分钟';
    } else if (seconds < 86400) {
      final hours = (seconds / 3600).floor();
      start = '$hours小时';
    } else if (seconds < 604800) {
      final days = (seconds / 86400).floor();
      start = '$days天';
    } else if (seconds < 2628000) {
      final weeks = (seconds / 604800).floor();
      start = '$weeks周';
    } else if (seconds < 31536000) {
      final months = (seconds / 2628000).floor();
      start = '$months月';
    } else {
      final years = (seconds / 31536000).floor();
      start = '$years年';
    }

    return start + end;
  }
}

/// 时间戳扩展方法
extension TimeStampExtension on int {
  /// 转换为相对时间显示
  String toTimeAgo() {
    return TimeUtils.toTimeAgo(this);
  }
}
