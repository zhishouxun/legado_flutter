/// 阅读提示配置工具类
/// 参考项目：io.legado.app.help.config.ReadTipConfig
/// 
/// 提供阅读界面页眉页脚提示信息的配置选项和名称
class ReadTipConfig {
  ReadTipConfig._();

  // ========== 提示类型常量 ==========
  /// 无提示
  static const int none = 0;
  
  /// 章节标题
  static const int chapterTitle = 1;
  
  /// 时间
  static const int time = 2;
  
  /// 电量
  static const int battery = 3;
  
  /// 电量百分比
  static const int batteryPercentage = 10;
  
  /// 页数
  static const int page = 4;
  
  /// 总进度
  static const int totalProgress = 5;
  
  /// 页数和总进度
  static const int pageAndTotal = 6;
  
  /// 书籍名称
  static const int bookName = 7;
  
  /// 时间和电量
  static const int timeBattery = 8;
  
  /// 时间和电量百分比
  static const int timeBatteryPercentage = 9;
  
  /// 总进度（格式1）
  static const int totalProgress1 = 11;

  /// 提示值数组
  /// 参考项目：ReadTipConfig.tipValues
  static const List<int> tipValues = [
    none,
    bookName,
    chapterTitle,
    time,
    battery,
    batteryPercentage,
    page,
    totalProgress,
    totalProgress1,
    pageAndTotal,
    timeBattery,
    timeBatteryPercentage,
  ];

  /// 提示名称数组
  /// 参考项目：ReadTipConfig.tipNames
  static const List<String> tipNames = [
    '无',
    '书籍名称',
    '章节标题',
    '时间',
    '电量',
    '电量百分比',
    '页数',
    '总进度',
    '总进度（格式1）',
    '页数及进度',
    '时间+电量',
    '时间+电量百分比',
  ];

  /// 提示颜色名称数组
  /// 参考项目：ReadTipConfig.tipColorNames
  static const List<String> tipColorNames = [
    '跟随正文',
    '自定义',
  ];

  /// 分隔线颜色名称数组
  /// 参考项目：ReadTipConfig.tipDividerColorNames
  static const List<String> tipDividerColorNames = [
    '默认',
    '跟随内容',
    '自定义',
  ];

  /// 获取页眉模式选项
  /// 参考项目：ReadTipConfig.getHeaderModes()
  /// 
  /// 返回页眉显示模式的选项映射
  /// 0: 状态栏显示时隐藏, 1: 显示, 2: 隐藏
  static Map<int, String> getHeaderModes() {
    return {
      0: '状态栏显示时隐藏',
      1: '显示',
      2: '隐藏',
    };
  }

  /// 获取页脚模式选项
  /// 参考项目：ReadTipConfig.getFooterModes()
  /// 
  /// 返回页脚显示模式的选项映射
  /// 0: 显示, 1: 隐藏
  static Map<int, String> getFooterModes() {
    return {
      0: '显示',
      1: '隐藏',
    };
  }

  /// 根据提示类型值获取名称
  /// [tipValue] 提示类型值
  /// 返回对应的名称，如果不存在则返回 '未知'
  static String getTipName(int tipValue) {
    final index = tipValues.indexOf(tipValue);
    if (index >= 0 && index < tipNames.length) {
      return tipNames[index];
    }
    return '未知';
  }

  /// 根据提示名称获取值
  /// [tipName] 提示名称
  /// 返回对应的值，如果不存在则返回 none (0)
  static int getTipValue(String tipName) {
    final index = tipNames.indexOf(tipName);
    if (index >= 0 && index < tipValues.length) {
      return tipValues[index];
    }
    return none;
  }
}

