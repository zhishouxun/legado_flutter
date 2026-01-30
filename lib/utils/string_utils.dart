import 'dart:convert';
import 'package:archive/archive.dart';

/// 字符串工具类
/// 参考项目：StringUtils.kt
class StringUtils {
  // 中文数字映射
  static final Map<String, int> _chnMap = {
    '零': 0,
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10,
    '〇': 0,
    '壹': 1,
    '贰': 2,
    '叁': 3,
    '肆': 4,
    '伍': 5,
    '陆': 6,
    '柒': 7,
    '捌': 8,
    '玖': 9,
    '拾': 10,
    '两': 2,
    '百': 100,
    '佰': 100,
    '千': 1000,
    '仟': 1000,
    '万': 10000,
    '亿': 100000000,
  };

  /// 将日期转换成昨天、今天、明天
  /// 参考项目：StringUtils.dateConvert
  static String dateConvert(String source, String pattern) {
    try {
      // 解析日期
      final date = _parseDate(source, pattern);
      if (date == null) return '';

      final now = DateTime.now();
      final diff = now.difference(date).abs();
      final diffSeconds = diff.inSeconds;
      final diffMinutes = diff.inMinutes;
      final diffHours = diff.inHours;
      final diffDays = diff.inDays;

      // 判断是否有时间部分（小时不为0）
      final hasTime = date.hour != 0 || date.minute != 0 || date.second != 0;

      if (!hasTime) {
        // 只有日期，比较日期
        if (diffDays == 0) {
          return '今天';
        } else if (diffDays == 1) {
          return '昨天';
        } else {
          return '${date.year}-${_padZero(date.month)}-${_padZero(date.day)}';
        }
      }

      // 有时间部分
      if (diffSeconds < 60) {
        return '$diffSeconds秒前';
      } else if (diffMinutes < 60) {
        return '$diffMinutes分钟前';
      } else if (diffHours < 24) {
        return '$diffHours小时前';
      } else if (diffDays == 1) {
        return '昨天';
      } else {
        return '${date.year}-${_padZero(date.month)}-${_padZero(date.day)}';
      }
    } catch (e) {
      return '';
    }
  }

  /// 解析日期字符串
  static DateTime? _parseDate(String source, String pattern) {
    try {
      // 简化版日期解析，支持常见格式
      // 实际应该使用更完善的日期解析库
      if (pattern.contains('yyyy') || pattern.contains('YYYY')) {
        // 尝试解析常见格式
        final patterns = [
          'yyyy-MM-dd HH:mm:ss',
          'yyyy-MM-dd',
          'yyyy/MM/dd HH:mm:ss',
          'yyyy/MM/dd',
          'yyyy年MM月dd日 HH:mm:ss',
          'yyyy年MM月dd日',
        ];
        for (final p in patterns) {
          try {
            return _parseDateWithPattern(source, p);
          } catch (_) {
            continue;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 使用指定格式解析日期
  static DateTime? _parseDateWithPattern(String source, String pattern) {
    try {
      // 简化实现，实际应该使用更完善的日期解析
      // 这里使用正则表达式提取年月日时分秒
      final yearMatch = RegExp(r'(\d{4})').firstMatch(source);
      final monthMatch = RegExp(r'[/-](\d{1,2})[/-]').firstMatch(source);
      final dayMatch = RegExp(r'[/-](\d{1,2})(?:\s|$)').firstMatch(source);
      final timeMatch =
          RegExp(r'(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?').firstMatch(source);

      if (yearMatch == null || monthMatch == null || dayMatch == null) {
        return null;
      }

      final year = int.parse(yearMatch.group(1)!);
      final month = int.parse(monthMatch.group(1)!);
      final day = int.parse(dayMatch.group(1)!);
      final hour = timeMatch != null ? int.parse(timeMatch.group(1)!) : 0;
      final minute = timeMatch != null ? int.parse(timeMatch.group(2)!) : 0;
      final second = timeMatch != null && timeMatch.group(3) != null
          ? int.parse(timeMatch.group(3)!)
          : 0;

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      return null;
    }
  }

  /// 补零
  static String _padZero(int value) {
    return value.toString().padLeft(2, '0');
  }

  /// 首字母大写
  /// 参考项目：StringUtils.toFirstCapital
  static String toFirstCapital(String str) {
    if (str.isEmpty) return str;
    return str[0].toUpperCase() + str.substring(1);
  }

  /// 将文本中的半角字符，转换成全角字符
  /// 参考项目：StringUtils.halfToFull
  static String halfToFull(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if (code == 32) {
        // 半角空格 -> 全角空格
        buffer.writeCharCode(12288);
      } else if (code >= 33 && code <= 126) {
        // 其他符号转换为全角
        buffer.writeCharCode(code + 65248);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// 字符串全角转换为半角
  /// 参考项目：StringUtils.fullToHalf
  static String fullToHalf(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if (code == 12288) {
        // 全角空格 -> 半角空格
        buffer.writeCharCode(32);
      } else if (code >= 65281 && code <= 65374) {
        // 全角符号转换为半角
        buffer.writeCharCode(code - 65248);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// 中文大写数字转数字
  /// 参考项目：StringUtils.chineseNumToInt
  static int chineseNumToInt(String chNum) {
    try {
      final chars = chNum.split('');
      var result = 0;
      var tmp = 0;
      var billion = 0;

      // "一零二五" 形式（纯数字）
      if (chars.length > 1 &&
          RegExp(r'^[〇零一二三四五六七八九壹贰叁肆伍陆柒捌玖]+$').hasMatch(chNum)) {
        final buffer = StringBuffer();
        for (final char in chars) {
          final num = _chnMap[char];
          if (num != null && num < 10) {
            buffer.write(num);
          }
        }
        return int.tryParse(buffer.toString()) ?? -1;
      }

      // "一千零二十五", "一千二" 形式
      for (int i = 0; i < chars.length; i++) {
        final tmpNum = _chnMap[chars[i]];
        if (tmpNum == null) continue;

        if (tmpNum == 100000000) {
          // 亿
          result += tmp;
          result *= tmpNum;
          billion = billion * 100000000 + result;
          result = 0;
          tmp = 0;
        } else if (tmpNum == 10000) {
          // 万
          result += tmp;
          result *= tmpNum;
          tmp = 0;
        } else if (tmpNum >= 10) {
          // 十、百、千
          if (tmp == 0) tmp = 1;
          result += tmpNum * tmp;
          tmp = 0;
        } else {
          // 个位数
          if (i >= 2 &&
              i == chars.length - 1 &&
              _chnMap[chars[i - 1]] != null &&
              _chnMap[chars[i - 1]]! > 10) {
            // 如 "一千二" 中的 "二"
            tmp = tmpNum * _chnMap[chars[i - 1]]! ~/ 10;
          } else {
            tmp = tmp * 10 + tmpNum;
          }
        }
      }
      result += tmp + billion;
      return result;
    } catch (e) {
      return -1;
    }
  }

  /// 字符串转数字
  /// 参考项目：StringUtils.stringToInt
  static int stringToInt(String? str) {
    if (str == null) return -1;
    final num = fullToHalf(str).replaceAll(RegExp(r'\s+'), '');
    try {
      return int.parse(num);
    } catch (e) {
      return chineseNumToInt(num);
    }
  }

  /// 是否包含数字
  /// 参考项目：StringUtils.isContainNumber
  static bool isContainNumber(String company) {
    return RegExp(r'[0-9]+').hasMatch(company);
  }

  /// 是否数字
  /// 参考项目：StringUtils.isNumeric
  static bool isNumeric(String str) {
    return RegExp(r'^-?[0-9]+$').hasMatch(str);
  }

  /// 字数格式化
  /// 参考项目：StringUtils.wordCountFormat
  static String wordCountFormat(int words) {
    if (words <= 0) return '';
    if (words > 10000) {
      final df = (words / 10000.0).toStringAsFixed(1);
      return '$df万字';
    } else {
      return '$words字';
    }
  }

  /// 字数格式化（字符串版本）
  static String wordCountFormatString(String? wc) {
    if (wc == null || wc.isEmpty) return '';
    if (isNumeric(wc)) {
      final words = int.tryParse(wc) ?? 0;
      return wordCountFormat(words);
    } else {
      return wc;
    }
  }

  /// 移除字符串首尾空字符的高效方法(利用ASCII值判断,包括全角空格)
  /// 参考项目：StringUtils.trim
  static String trim(String s) {
    if (s.isEmpty) return '';
    var start = 0;
    final len = s.length;
    var end = len - 1;

    // 找到第一个非空白字符
    while (start < end && (s.codeUnitAt(start) <= 0x20 || s[start] == '　')) {
      start++;
    }

    // 找到最后一个非空白字符
    while (start < end && (s.codeUnitAt(end) <= 0x20 || s[end] == '　')) {
      end--;
    }

    end++;
    if (start > 0 || end < len) {
      return s.substring(start, end);
    }
    return s;
  }

  /// 重复字符串
  /// 参考项目：StringUtils.repeat
  static String repeat(String str, int n) {
    return str * n;
  }

  /// 移除UTF字符
  /// 参考项目：StringUtils.removeUTFCharacters
  static String? removeUTFCharacters(String? data) {
    if (data == null) return null;
    return data.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) {
        final code = int.parse(match.group(1)!, radix: 16);
        return String.fromCharCode(code);
      },
    );
  }

  /// 压缩字符串（GZIP + Base64）
  /// 参考项目：StringUtils.compress
  static String? compress(String str) {
    try {
      if (str.isEmpty) return str;
      final bytes = utf8.encode(str);
      final compressed = GZipEncoder().encode(bytes);
      if (compressed == null) return null;
      return base64Encode(compressed);
    } catch (e) {
      return null;
    }
  }

  /// 解压字符串
  /// 参考项目：StringUtils.unCompress
  static String? unCompress(String str) {
    try {
      final compressed = base64Decode(str);
      final decompressed = GZipDecoder().decodeBytes(compressed);
      return utf8.decode(decompressed);
    } catch (e) {
      return null;
    }
  }
}
