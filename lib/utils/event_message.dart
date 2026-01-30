/// 事件消息
/// 参考项目：io.legado.app.help.EventMessage
///
/// 用于组件间的事件消息传递
class EventMessage {
  /// 消息类型（整数）
  int? what;

  /// 消息标签（字符串）
  String? tag;

  /// 消息对象（任意类型）
  dynamic obj;

  EventMessage({
    this.what,
    this.tag,
    this.obj,
  });

  /// 检查是否来自指定标签
  /// 参考项目：EventMessage.isFrom()
  bool isFrom(String tag) {
    return this.tag == tag;
  }

  /// 检查是否可能来自指定标签列表中的任意一个
  /// 参考项目：EventMessage.maybeFrom()
  bool maybeFrom(List<String> tags) {
    if (tag == null) return false;
    return tags.contains(tag);
  }

  /// 创建带标签的消息
  /// 参考项目：EventMessage.obtain(tag: String)
  static EventMessage obtainTag(String tag) {
    return EventMessage(tag: tag);
  }

  /// 创建带类型的消息
  /// 参考项目：EventMessage.obtain(what: Int)
  static EventMessage obtainWhat(int what) {
    return EventMessage(what: what);
  }

  /// 创建带类型和对象的消息
  /// 参考项目：EventMessage.obtain(what: Int, obj: Any)
  static EventMessage obtainWhatObj(int what, dynamic obj) {
    return EventMessage(what: what, obj: obj);
  }

  /// 创建带标签和对象的消息
  /// 参考项目：EventMessage.obtain(tag: String, obj: Any)
  static EventMessage obtainTagObj(String tag, dynamic obj) {
    return EventMessage(tag: tag, obj: obj);
  }
}

