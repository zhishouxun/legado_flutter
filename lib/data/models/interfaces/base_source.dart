/// 书源基础接口
/// 参考项目：io.legado.app.data.entities.BaseSource
/// 
/// 提供书源相关的通用功能，包括登录、JS扩展等
abstract class BaseSource {
  /// 并发率
  String? get concurrentRate;
  set concurrentRate(String? value);

  /// 登录地址
  String? get loginUrl;
  set loginUrl(String? value);

  /// 登录UI（JSON字符串）
  String? get loginUi;
  set loginUi(String? value);

  /// 请求头
  String? get header;
  set header(String? value);

  /// 启用cookieJar
  bool? get enabledCookieJar;
  set enabledCookieJar(bool? value);

  /// JS库
  String? get jsLib;
  set jsLib(String? value);

  /// 获取标签
  String getTag();

  /// 获取键值
  String getKey();

  /// 获取书源实例
  BaseSource? getSource() {
    return this;
  }

  /// 获取登录UI列表
  /// 返回解析后的登录UI配置
  List<Map<String, dynamic>>? getLoginUiList() {
    if (loginUi == null || loginUi!.isEmpty) {
      return null;
    }
    try {
      // 这里需要根据实际的 RowUi 结构来解析
      // 暂时返回原始JSON解析结果
      return null; // TODO: 实现 RowUi 解析
    } catch (e) {
      return null;
    }
  }

  /// 获取登录JS代码
  /// 从 loginUrl 中提取JS代码
  String? getLoginJs() {
    final loginJs = loginUrl;
    if (loginJs == null || loginJs.isEmpty) {
      return null;
    }

    if (loginJs.startsWith('@js:')) {
      return loginJs.substring(4);
    } else if (loginJs.startsWith('<js>')) {
      final endIndex = loginJs.lastIndexOf('</js>');
      if (endIndex > 0) {
        return loginJs.substring(4, endIndex);
      }
    }

    return loginJs;
  }

  /// 执行登录
  /// 调用 login 函数实现登录请求
  /// 注意：需要在具体的实现类中提供 evalJS 方法
  Future<void> login() async {
    final loginJs = getLoginJs();
    if (loginJs == null || loginJs.isEmpty) {
      return;
    }

    // 构建完整的登录JS代码
    // TODO: 在具体实现中调用 evalJS(js)
    // final js = '''
    // $loginJs
    // if(typeof login === 'function'){
    //     login.apply(this);
    // } else {
    //     throw new Error('Function login not implements!!!');
    // }
    // ''';
    // await evalJS(js);
  }
}

