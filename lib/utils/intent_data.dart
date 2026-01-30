/// Intent 数据管理器
/// 参考项目：io.legado.app.help.IntentData
///
/// 用于存储和传递大对象数据（通过 key 传递，避免 Intent 大小限制）
class IntentData {
  IntentData._();

  /// 大数据存储映射
  static final Map<String, dynamic> _bigData = {};

  /// 存储数据并返回 key
  /// 参考项目：IntentData.put(key: String, data: Any?)
  static String put(String key, dynamic data) {
    if (data != null) {
      _bigData[key] = data;
    }
    return key;
  }

  /// 存储数据并返回自动生成的 key
  /// 参考项目：IntentData.put(data: Any?)
  static String putAuto(dynamic data) {
    if (data == null) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    _bigData[key] = data;
    return key;
  }

  /// 获取数据并移除（一次性使用）
  /// 参考项目：IntentData.get<T>(key: String?)
  static T? get<T>(String? key) {
    if (key == null) return null;
    final data = _bigData.remove(key);
    return data is T ? data : null;
  }

  /// 获取数据但不移除
  static T? peek<T>(String? key) {
    if (key == null) return null;
    final data = _bigData[key];
    return data is T ? data : null;
  }

  /// 移除数据
  static void remove(String key) {
    _bigData.remove(key);
  }

  /// 清空所有数据
  static void clear() {
    _bigData.clear();
  }
}

