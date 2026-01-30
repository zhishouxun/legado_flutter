/// 规则分析器
/// 参考项目：RuleAnalyzer.kt
/// 用于拆分和解析规则字符串，支持规则组合（&&/||/%%）
class RuleAnalyzer {
  final String _queue; // 被处理字符串
  int _pos = 0; // 当前处理到的位置
  int _start = 0; // 当前处理字段的开始
  int _startX = 0; // 当前规则的开始

  List<String> _rule = []; // 分割出的规则列表
  int _step = 0; // 分割字符的长度
  String _elementsType = ""; // 当前分割字符串

  RuleAnalyzer(this._queue);

  /// 修剪当前规则之前的"@"或者空白符
  void _trim() {
    if (_pos >= _queue.length) return;

    if (_queue[_pos] == '@' || _queue[_pos].codeUnitAt(0) < 33) {
      _pos++;
      while (_pos < _queue.length &&
          (_queue[_pos] == '@' || _queue[_pos].codeUnitAt(0) < 33)) {
        _pos++;
      }
      _start = _pos; // 开始点推移
      _startX = _pos; // 规则起始点推移
    }
  }

  /// 将pos重置为0，方便复用
  void resetPos() {
    _pos = 0;
    _startX = 0;
  }

  /// 从剩余字串中拉出一个字符串，直到但不包括匹配序列
  /// [seq] 查找的字符串 **区分大小写**
  /// 返回是否找到相应字段
  bool _consumeTo(String seq) {
    _start = _pos; // 将处理到的位置设置为规则起点
    final offset = _queue.indexOf(seq, _pos);
    if (offset != -1) {
      _pos = offset;
      return true;
    }
    return false;
  }

  /// 从剩余字串中拉出一个字符串，直到但不包括匹配序列（匹配参数列表中一项即为匹配），或剩余字串用完
  /// [seq] 匹配字符串序列
  /// 返回成功返回true并设置间隔，失败则直接返回false
  bool _consumeToAny(List<String> seq) {
    var pos = _pos; // 声明新变量记录匹配位置，不更改类本身的位置

    while (pos < _queue.length) {
      for (final s in seq) {
        if (_queue.length - pos >= s.length &&
            _queue.substring(pos, pos + s.length) == s) {
          _step = s.length; // 间隔数
          _pos = pos; // 匹配成功, 同步处理位置到类
          return true; // 匹配就返回 true
        }
      }
      pos++; // 逐个试探
    }
    return false;
  }

  /// 从剩余字串中拉出一个字符串，直到但不包括匹配序列（匹配参数列表中一项即为匹配），或剩余字串用完
  /// [seq] 匹配字符序列
  /// 返回匹配位置
  int _findToAny(List<String> seq) {
    var pos = _pos; // 声明新变量记录匹配位置，不更改类本身的位置

    while (pos < _queue.length) {
      for (final s in seq) {
        if (_queue[pos] == s) return pos; // 匹配则返回位置
      }
      pos++; // 逐个试探
    }
    return -1;
  }

  /// 拉出一个规则平衡组，经过仔细测试xpath和jsoup中，引号内转义字符无效
  bool _chompRuleBalanced(String open, String close) {
    var pos = _pos; // 声明临时变量记录匹配位置，匹配成功后才同步到类的pos
    var depth = 0; // 嵌套深度
    var inSingleQuote = false; // 单引号
    var inDoubleQuote = false; // 双引号

    do {
      if (pos >= _queue.length) break;
      final c = _queue[pos];
      pos++;

      if (c == '\'' && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote; // 匹配具有语法功能的单引号
      } else if (c == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote; // 匹配具有语法功能的双引号
      }

      if (inSingleQuote || inDoubleQuote) continue; // 语法单元未匹配结束，直接进入下个循环

      if (c == '\\') {
        // 不在引号中的转义字符才将下个字符转义
        if (pos < _queue.length) pos++;
        continue;
      }

      if (c == open) {
        depth++; // 开始嵌套一层
      } else if (c == close) {
        depth--; // 闭合一层嵌套
      }
    } while (depth > 0); // 拉出一个平衡字串

    if (depth > 0) {
      return false;
    } else {
      _pos = pos; // 同步位置
      return true;
    }
  }

  /// 不用正则,不到最后不切片也不用中间变量存储,只在序列中标记当前查找字段的开头结尾,到返回时才切片,高效快速准确切割规则
  /// 解决jsonPath自带的"&&"和"||"与阅读的规则冲突,以及规则正则或字符串中包含"&&"、"||"、"%%"、"@"导致的冲突
  List<String> splitRule(List<String> split) {
    _trim();
    _rule.clear();
    _elementsType = "";

    if (split.isEmpty) {
      if (_startX < _queue.length) {
        _rule.add(_queue.substring(_startX));
      }
      return _rule;
    }

    if (split.length == 1) {
      _elementsType = split[0]; // 设置分割字串
      return _splitRuleSingle(split[0]);
    } else {
      return _splitRuleMultiple(split);
    }
  }

  /// 单分隔符分割
  List<String> _splitRuleSingle(String separator) {
    if (!_consumeTo(separator)) {
      if (_startX < _queue.length) {
        _rule.add(_queue.substring(_startX));
      }
      return _rule;
    }

    final end = _pos; // 记录分隔位置
    _pos = _start; // 重回开始，启动另一种查找

    do {
      final st = _findToAny(['[', '(']); // 查找筛选器位置

      if (st == -1) {
        // 没有筛选器，直接分割
        _rule = [_queue.substring(_startX, end)]; // 压入分隔的首段规则到数组
        _elementsType = _queue.substring(end, end + _step); // 设置组合类型
        _pos = end + _step; // 跳过分隔符

        while (_consumeTo(_elementsType)) {
          // 循环切分规则压入数组
          _rule.add(_queue.substring(_start, _pos));
          _pos += _step; // 跳过分隔符
        }

        _rule.add(_queue.substring(_pos)); // 将剩余字段压入数组末尾
        return _rule;
      }

      if (st > end) {
        // 先匹配到分隔符，表明分隔字串不在选择器中
        _rule = [_queue.substring(_startX, end)]; // 压入分隔的首段规则到数组
        _elementsType = _queue.substring(end, end + _step); // 设置组合类型
        _pos = end + _step; // 跳过分隔符

        while (_consumeTo(_elementsType) && _pos < st) {
          // 循环切分规则压入数组
          _rule.add(_queue.substring(_start, _pos));
          _pos += _step; // 跳过分隔符
        }

        if (_pos > st) {
          _startX = _start;
          return _splitRuleSingle(_elementsType); // 首段已匹配,但当前段匹配未完成,调用二段匹配
        } else {
          // 执行到此，证明后面再无分隔字符
          _rule.add(_queue.substring(_pos)); // 将剩余字段压入数组末尾
          return _rule;
        }
      }

      _pos = st; // 位置推移到筛选器处
      final next = _queue[_pos] == '[' ? ']' : ')'; // 平衡组末尾字符

      if (!_chompRuleBalanced(_queue[_pos], next)) {
        throw Exception('${_queue.substring(0, _start)}后未平衡');
      } // 拉出一个筛选器,不平衡则报错
    } while (end > _pos);

    _start = _pos; // 设置开始查找筛选器位置的起始位置
    return _splitRuleSingle(separator); // 递归调用首段匹配
  }

  /// 多分隔符分割
  List<String> _splitRuleMultiple(List<String> split) {
    if (!_consumeToAny(split)) {
      // 未找到分隔符
      if (_startX < _queue.length) {
        _rule.add(_queue.substring(_startX));
      }
      return _rule;
    }

    final end = _pos; // 记录分隔位置
    _pos = _start; // 重回开始，启动另一种查找

    do {
      final st = _findToAny(['[', '(']); // 查找筛选器位置

      if (st == -1) {
        // 没有筛选器，直接分割
        _rule = [_queue.substring(_startX, end)]; // 压入分隔的首段规则到数组
        _elementsType = _queue.substring(end, end + _step); // 设置组合类型
        _pos = end + _step; // 跳过分隔符

        while (_consumeTo(_elementsType)) {
          // 循环切分规则压入数组
          _rule.add(_queue.substring(_start, _pos));
          _pos += _step; // 跳过分隔符
        }

        _rule.add(_queue.substring(_pos)); // 将剩余字段压入数组末尾
        return _rule;
      }

      if (st > end) {
        // 先匹配到分隔符，表明分隔字串不在选择器中
        _rule = [_queue.substring(_startX, end)]; // 压入分隔的首段规则到数组
        _elementsType = _queue.substring(end, end + _step); // 设置组合类型
        _pos = end + _step; // 跳过分隔符

        while (_consumeTo(_elementsType) && _pos < st) {
          // 循环切分规则压入数组
          _rule.add(_queue.substring(_start, _pos));
          _pos += _step; // 跳过分隔符
        }

        if (_pos > st) {
          _startX = _start;
          return _splitRuleMultiple(split); // 首段已匹配,但当前段匹配未完成,调用二段匹配
        } else {
          // 执行到此，证明后面再无分隔字符
          _rule.add(_queue.substring(_pos)); // 将剩余字段压入数组末尾
          return _rule;
        }
      }

      _pos = st; // 位置推移到筛选器处
      final next = _queue[_pos] == '[' ? ']' : ')'; // 平衡组末尾字符

      if (!_chompRuleBalanced(_queue[_pos], next)) {
        throw Exception('${_queue.substring(0, _start)}后未平衡');
      } // 拉出一个筛选器,不平衡则报错
    } while (end > _pos);

    _start = _pos; // 设置开始查找筛选器位置的起始位置
    return _splitRuleMultiple(split); // 递归调用首段匹配
  }

  /// 获取分割类型（&&/||/%%）
  String get elementsType => _elementsType;
}
