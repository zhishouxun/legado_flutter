import 'package:html/dom.dart' as html_dom;

/// 元素索引选择器（参考项目：AnalyzeByJSoup.ElementsSingle）
/// 支持：
/// 1. 负数索引：tag.div.-1 表示最后一个元素
/// 2. 区间选择：tag.div.0:10 表示索引0到10的元素
/// 3. 步长选择：tag.div.0:10:2 表示索引0到10，步长为2
/// 4. 排除模式：tag.div!0:3 表示排除索引0到3的元素
/// 5. 数组索引：tag.div[-1, 3:-2:-10, 2] 表示多个索引或区间的组合
/// 6. 反向选择：tag.div[-1:0] 可以反转列表顺序
class ElementsSingle {
  /// 分隔符：'.' 表示选择，'!' 表示排除
  String split = '.';

  /// 前置规则（索引之前的选择器部分）
  String beforeRule = '';

  /// 默认索引列表（旧格式：tag.div.0:3:2）
  final List<int> indexDefault = [];

  /// 索引列表（新格式：tag.div[-1, 3:-2:-10, 2]）
  /// 每个元素可以是 int（单个索引）或 Triple<int?, int?, int>（区间）
  final List<dynamic> indexes = [];

  /// 获取元素（按照一个规则和索引）
  /// 参考项目：AnalyzeByJSoup.ElementsSingle.getElementsSingle
  static List<html_dom.Element> getElementsSingle(
    html_dom.Element temp,
    String rule,
  ) {
    final single = ElementsSingle();
    single._findIndexSet(rule);

    // 获取所有元素
    List<html_dom.Element> elements;
    if (single.beforeRule.isEmpty) {
      // 允许索引直接作为根元素，此时前置规则为空，效果与children相同
      elements = temp.children;
    } else {
      // 解析前置规则
      final rules = single.beforeRule.split('.');
      switch (rules[0]) {
        case 'children':
          elements = temp.children;
          break;
        case 'class':
          if (rules.length > 1) {
            elements = temp.getElementsByClassName(rules[1]);
          } else {
            elements = [];
          }
          break;
        case 'tag':
          if (rules.length > 1) {
            final tagName = rules[1];
            
            // 使用 querySelectorAll 查找，因为它会递归查找所有子元素
            // getElementsByTagName 也应该递归查找，但如果它不工作，使用 querySelectorAll
            final allChildren = temp.querySelectorAll(tagName);
            if (allChildren.isNotEmpty) {
              elements = allChildren.toList();
            } else {
              // 如果 querySelectorAll 也找不到，尝试 getElementsByTagName
              elements = temp.getElementsByTagName(tagName);
            }
          } else {
            elements = [];
          }
          break;
        case 'id':
          final idElement = temp.querySelector('#${rules[1]}');
          elements = idElement != null ? [idElement] : [];
          break;
        case 'text':
          if (rules.length > 1) {
            // 查找包含指定文本的元素
            elements = temp.querySelectorAll('*').where((e) {
              return e.text.contains(rules[1]);
            }).toList();
          } else {
            elements = [];
          }
          break;
        default:
          // 使用CSS选择器
          elements = temp.querySelectorAll(single.beforeRule);
          break;
      }
    }

    final len = elements.length;
    if (len == 0) return [];

    // 获取索引集合
    final indexSet = single._getIndexSet(len);

    // 根据分隔符筛选元素
    if (single.split == '!') {
      // 排除模式：移除指定索引的元素
      final result = <html_dom.Element>[];
      for (int i = 0; i < len; i++) {
        if (!indexSet.contains(i)) {
          result.add(elements[i]);
        }
      }
      return result;
    } else {
      // 选择模式：只保留指定索引的元素
      final result = <html_dom.Element>[];
      for (final index in indexSet) {
        if (index >= 0 && index < len) {
          result.add(elements[index]);
        }
      }
      return result;
    }
  }

  /// 获取索引集合
  /// 参考项目：AnalyzeByJSoup.ElementsSingle.getElementsSingle 中的索引处理逻辑
  Set<int> _getIndexSet(int len) {
    final indexSet = <int>{};
    final lastIndexes =
        indexes.isNotEmpty ? indexes.length - 1 : indexDefault.length - 1;

    if (indexes.isEmpty) {
      // 使用默认索引列表（旧格式）
      for (int i = lastIndexes; i >= 0; i--) {
        final it = indexDefault[i];
        if (it >= 0 && it < len) {
          indexSet.add(it);
        } else if (it < 0 && len >= -it) {
          indexSet.add(it + len);
        }
      }
    } else {
      // 使用新格式索引列表
      for (int i = lastIndexes; i >= 0; i--) {
        final item = indexes[i];
        if (item is int) {
          // 单个索引
          final it = item;
          if (it >= 0 && it < len) {
            indexSet.add(it);
          } else if (it < 0 && len >= -it) {
            indexSet.add(it + len);
          }
        } else if (item is _IndexRange) {
          // 区间
          final range = item;
          var start = range.start ?? 0;
          if (start < 0) start += len;

          var end = range.end ?? (len - 1);
          if (end < 0) end += len;

          final step = range.step;

          // 边界检查
          if ((start < 0 && end < 0) || (start >= len && end >= len)) {
            continue;
          }

          if (start >= len) {
            start = len - 1;
          } else if (start < 0) start = 0;

          if (end >= len) {
            end = len - 1;
          } else if (end < 0) end = 0;

          if (start == end) {
            indexSet.add(start);
            continue;
          }

          // 生成区间内的索引
          if (end > start) {
            for (int j = start; j <= end; j += step) {
              indexSet.add(j);
            }
          } else {
            // 反向区间
            for (int j = start; j >= end; j -= step) {
              indexSet.add(j);
            }
          }
        }
      }
    }

    return indexSet;
  }

  /// 解析索引规则
  /// 参考项目：AnalyzeByJSoup.ElementsSingle.findIndexSet
  void _findIndexSet(String rule) {
    final rus = rule.trim();
    var len = rus.length;

    // 检查是否是数组格式 [index...]
    final head = rus.endsWith(']');

    if (head) {
      // 数组格式：tag.div[-1, 3:-2:-10, 2]
      len--; // 跳过尾部 ']'

      var curInt = 0;
      var curMinus = false;
      final curList = <int?>[];
      var l = '';

      while (len >= 0) {
        if (len >= rus.length) break;
        final rl = rus[len];
        if (rl == ' ') {
          len--;
          continue;
        }

        if (rl.compareTo('0') >= 0 && rl.compareTo('9') <= 0) {
          l = rl + l;
        } else if (rl == '-') {
          curMinus = true;
        } else {
          curInt = l.isEmpty ? 0 : (curMinus ? -int.parse(l) : int.parse(l));

          if (rl == ':') {
            curList.add(curInt);
          } else if (rl == '[') {
            // 遇到索引边界，提取前置规则
            beforeRule = rus.substring(0, len).trim();
            return;
          } else if (rl == ',') {
            // 处理当前项
            if (curList.isEmpty) {
              indexes.add(curInt);
            } else {
              // 区间
              final start = curList.isNotEmpty ? curList[0] : null;
              final end =
                  curList.length > 1 ? curList[curList.length - 1] : null;
              final step = curList.length > 2 ? (curList[0] ?? 1) : 1;
              indexes.add(_IndexRange(start: start, end: end, step: step));
              curList.clear();
            }
          } else if (rl == '!') {
            split = '!';
            while (len > 0 && rus[--len] == ' ') {}
            continue;
          } else {
            break;
          }

          l = '';
          curMinus = false;
        }
        len--;
      }
    } else {
      // 旧格式：tag.div.0:3:2 或 tag.div!0:3
      var l = '';
      var curMinus = false;

      while (len >= 0) {
        if (len >= rus.length) break;
        final rl = rus[len];
        if (rl == ' ') {
          len--;
          continue;
        }

        if (rl.compareTo('0') >= 0 && rl.compareTo('9') <= 0) {
          l = rl + l;
        } else if (rl == '-') {
          curMinus = true;
        } else if (rl == '!' || rl == '.' || rl == ':') {
          if (l.isNotEmpty) {
            indexDefault.add(curMinus ? -int.parse(l) : int.parse(l));
          }

          if (rl != ':') {
            split = rl;
            beforeRule = rus.substring(0, len).trim();
            return;
          }

          l = '';
          curMinus = false;
        } else {
          break;
        }
        len--;
      }
    }

    split = ' ';
    beforeRule = rus;
  }
}

/// 索引区间（用于表示 start:end:step）
class _IndexRange {
  final int? start;
  final int? end;
  final int step;

  _IndexRange({
    required this.start,
    required this.end,
    required this.step,
  });
}
