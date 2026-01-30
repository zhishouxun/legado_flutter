import '../app_log.dart';

/// 正则表达式解析器（参考项目：AnalyzeByRegex）
/// 支持链式正则匹配：regex1&&regex2&&regex3
/// 每个正则的结果作为下一个正则的输入
class AnalyzeByRegex {
  /// 获取单个元素（返回第一个匹配的所有分组）
  /// 参考项目：AnalyzeByRegex.getElement
  /// 
  /// [res] 要匹配的字符串
  /// [regs] 正则表达式数组（链式匹配）
  /// [index] 当前正则表达式的索引（递归使用）
  /// 
  /// 返回：最后一个正则的所有分组（$0, $1, $2等），如果没有匹配返回null
  static List<String>? getElement(
    String res,
    List<String> regs, {
    int index = 0,
  }) {
    if (regs.isEmpty || index >= regs.length) {
      return null;
    }

    try {
      final regex = RegExp(regs[index], multiLine: true);
      final match = regex.firstMatch(res);

      if (match == null) {
        return null;
      }

      // 判断是否是最后一个正则表达式
      if (index + 1 == regs.length) {
        // 最后一个正则，返回所有分组
        final info = <String>[];
        for (int groupIndex = 0; groupIndex <= match.groupCount; groupIndex++) {
          final group = match.group(groupIndex);
          info.add(group ?? '');
        }
        return info;
      } else {
        // 不是最后一个，收集所有匹配结果，作为下一个正则的输入
        final result = StringBuffer();
        final allMatches = regex.allMatches(res);
        for (final m in allMatches) {
          result.write(m.group(0) ?? '');
        }

        // 递归调用下一个正则
        return getElement(result.toString(), regs, index: index + 1);
      }
    } catch (e) {
      AppLog.instance.put(
        'AnalyzeByRegex.getElement: 正则表达式错误: ${regs[index]}, 错误: $e',
      );
      return null;
    }
  }

  /// 获取所有元素（返回所有匹配的所有分组）
  /// 参考项目：AnalyzeByRegex.getElements
  /// 
  /// [res] 要匹配的字符串
  /// [regs] 正则表达式数组（链式匹配）
  /// [index] 当前正则表达式的索引（递归使用）
  /// 
  /// 返回：所有匹配的结果列表，每个结果包含所有分组（List<List<String>>）
  static List<List<String>> getElements(
    String res,
    List<String> regs, {
    int index = 0,
  }) {
    if (regs.isEmpty || index >= regs.length) {
      return [];
    }

    try {
      final regex = RegExp(regs[index], multiLine: true);
      final firstMatch = regex.firstMatch(res);

      if (firstMatch == null) {
        return [];
      }

      // 判断是否是最后一个正则表达式
      if (index + 1 == regs.length) {
        // 最后一个正则，返回所有匹配的所有分组
        final books = <List<String>>[];
        final allMatches = regex.allMatches(res);
        for (final currentMatch in allMatches) {
          final info = <String>[];
          for (int groupIndex = 0; groupIndex <= currentMatch.groupCount; groupIndex++) {
            final group = currentMatch.group(groupIndex);
            info.add(group ?? '');
          }
          books.add(info);
        }

        return books;
      } else {
        // 不是最后一个，收集所有匹配结果，作为下一个正则的输入
        final result = StringBuffer();
        final allMatches = regex.allMatches(res);
        for (final m in allMatches) {
          result.write(m.group(0) ?? '');
        }

        // 递归调用下一个正则
        return getElements(result.toString(), regs, index: index + 1);
      }
    } catch (e) {
      AppLog.instance.put(
        'AnalyzeByRegex.getElements: 正则表达式错误: ${regs[index]}, 错误: $e',
      );
      return [];
    }
  }
}

