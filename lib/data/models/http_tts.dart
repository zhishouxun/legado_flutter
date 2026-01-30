/// HTTP TTS（文本转语音）数据模型
/// 参考项目：io.legado.app.data.entities.HttpTTS
class HttpTTS {
  /// TTS ID（主键）
  final int id;

  /// TTS名称
  String name;

  /// TTS URL
  String url;

  /// 内容类型
  String? contentType;

  /// 并发率
  String? concurrentRate;

  /// 登录URL
  String? loginUrl;

  /// 登录UI
  String? loginUi;

  /// 请求头
  String? header;

  /// JS库
  String? jsLib;

  /// 启用CookieJar
  bool enabledCookieJar;

  /// 登录检测JS
  String? loginCheckJs;

  /// 最后更新时间
  int lastUpdateTime;

  HttpTTS({
    int? id,
    this.name = '',
    this.url = '',
    this.contentType,
    this.concurrentRate = '0',
    this.loginUrl,
    this.loginUi,
    this.header,
    this.jsLib,
    this.enabledCookieJar = false,
    this.loginCheckJs,
    int? lastUpdateTime,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch,
        lastUpdateTime = lastUpdateTime ?? DateTime.now().millisecondsSinceEpoch;

  /// 从JSON创建
  factory HttpTTS.fromJson(Map<String, dynamic> json) {
    return HttpTTS(
      id: json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      contentType: json['contentType'] as String?,
      concurrentRate: json['concurrentRate'] as String? ?? '0',
      loginUrl: json['loginUrl'] as String?,
      loginUi: json['loginUi'] as String?,
      header: json['header'] as String?,
      jsLib: json['jsLib'] as String?,
      enabledCookieJar: json['enabledCookieJar'] == 1 || json['enabledCookieJar'] == true,
      loginCheckJs: json['loginCheckJs'] as String?,
      lastUpdateTime: json['lastUpdateTime'] as int?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'contentType': contentType,
      'concurrentRate': concurrentRate,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'header': header,
      'jsLib': jsLib,
      'enabledCookieJar': enabledCookieJar ? 1 : 0,
      'loginCheckJs': loginCheckJs,
      'lastUpdateTime': lastUpdateTime,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HttpTTS && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

