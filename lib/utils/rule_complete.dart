/// 规则自动补全
/// 参考项目：io.legado.app.help.RuleComplete
///
/// 对简单规则进行补全，简化部分书源规则的编写
/// 对 JSOUP/XPath/CSS 规则生效
class RuleComplete {
  RuleComplete._();

  // 需要补全的正则表达式
  // 匹配：&&、%%、|| 或字符串结尾，但不在 @attr、@text、@href 等之后
  // 注意：Dart 不支持命名组，使用捕获组
  static final RegExp _needComplete = RegExp(
    r'(?<!(@|/|^|[|%&]{2})(attr|text|ownText|textNodes|href|content|html|alt|all|value|src)(\(\))?)(\&{2}|%%|\|{2}|$)',
  );

  // 不能补全的正则表达式（存在 js/json/{{xx}} 的复杂情况）
  static final RegExp _notComplete = RegExp(
    r'^:|^##|\{\{|@js:|<js>|@Json:|\$\.',
  );

  // 修正从图片获取信息
  // 注意：Dart 不支持命名组，使用捕获组
  static final RegExp _fixImgInfo = RegExp(
    r'(?<=(^|tag\.|[\+/@>~| &]))img((\[@?.+\]|\.[-\w]+)?)[@/]+text(\(\))?(\&{2}|%%|\|{2}|$)',
  );

  // 是否为 XPath
  static final RegExp _isXpath = RegExp(r'^//|^@Xpath:');

  /// 对简单规则进行补全
  /// 参考项目：RuleComplete.autoComplete()
  ///
  /// [rules] 需要补全的规则
  /// [preRule] 预处理规则或列表规则
  /// [type] 补全结果的类型，可选的值有:
  ///   1 文字(默认)
  ///   2 链接
  ///   3 图片
  /// 返回补全后的规则 或 原规则
  static String? autoComplete(
    String? rules, {
    String? preRule,
    int type = 1,
  }) {
    if (rules == null || rules.isEmpty) {
      return rules;
    }

    // 检查是否不能补全
    if (_notComplete.hasMatch(rules) ||
        (preRule != null && _notComplete.hasMatch(preRule))) {
      return rules;
    }

    // 分离尾部规则
    String tailStr;

    // 分离尾部规则（## 或 ,{）
    final regexSplit = rules.split(RegExp(r'##|,\{'));
    final cleanedRule = regexSplit[0];
    if (regexSplit.length > 1) {
      final match = RegExp(r'##|,\{').firstMatch(rules);
      final splitStr = match?.group(0) ?? '';
      tailStr = splitStr + regexSplit.sublist(1).join(splitStr);
    } else {
      tailStr = '';
    }

    // 判断是否为 XPath
    final isXpath = _isXpath.hasMatch(cleanedRule);

    // 用于获取文字时添加的规则
    final textRule = isXpath ? r'//text()${seq}' : r'@text${seq}';

    // 用于获取链接时添加的规则
    final linkRule = isXpath ? r'//@href${seq}' : r'@href${seq}';

    // 用于获取图片时添加的规则
    final imgRule = isXpath ? r'//@src${seq}' : r'@src${seq}';

    // 用于获取图片alt属性时添加的规则
    final imgText = isXpath
        ? r'img${at}/@alt${seq}'
        : r'img${at}@alt${seq}';

    // 根据类型补全
    String result;
    switch (type) {
      case 1: // 文字
        result = cleanedRule.replaceAllMapped(_needComplete, (match) {
          // 最后一个捕获组是 seq
          final seq = match.group(match.groupCount) ?? '';
          return textRule.replaceAll(r'${seq}', seq);
        });
        // 修正图片信息
        result = result.replaceAllMapped(_fixImgInfo, (match) {
          // 第2个捕获组是 at，最后一个捕获组是 seq
          final at = match.group(2) ?? '';
          final seq = match.group(match.groupCount) ?? '';
          return imgText.replaceAll(r'${at}', at).replaceAll(r'${seq}', seq);
        });
        break;
      case 2: // 链接
        result = cleanedRule.replaceAllMapped(_needComplete, (match) {
          final seq = match.group(match.groupCount) ?? '';
          return linkRule.replaceAll(r'${seq}', seq);
        });
        break;
      case 3: // 图片
        result = cleanedRule.replaceAllMapped(_needComplete, (match) {
          final seq = match.group(match.groupCount) ?? '';
          return imgRule.replaceAll(r'${seq}', seq);
        });
        break;
      default:
        return rules;
    }

    return result + tailStr;
  }
}

