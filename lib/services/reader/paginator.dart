import 'package:flutter/material.dart';
import 'models/page_range.dart';

/// 分页引擎 (参考Gemini文档的核心算法)
/// 使用TextPainter实现精确的文本分页
class Paginator {
  /// 执行分页 (参考Gemini文档的paginate函数)
  ///
  /// **核心思路：贪心发现法**
  /// 从当前阅读位置开始，尝试放入尽可能多的行，直到超过屏幕高度
  ///
  /// [content] 章节内容
  /// [maxWidth] 最大宽度
  /// [maxHeight] 最大高度
  /// [style] 文本样式
  /// [startOffset] 起始字符偏移量(用于从特定位置开始分页)
  ///
  /// Returns: 分页范围列表
  static List<PageRange> paginate({
    required String content,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
    int startOffset = 0,
  }) {
    final List<PageRange> pages = [];

    if (content.isEmpty) {
      return pages;
    }

    if (maxWidth <= 0 || maxHeight <= 0) {
      // 无效尺寸,返回单页
      pages.add(PageRange(
        start: 0,
        end: content.length,
        pageIndex: 0,
      ));
      return pages;
    }

    int start = startOffset.clamp(0, content.length);
    int pageIndex = 0;

    while (start < content.length) {
      // 1. 创建 TextPainter 模拟排版
      final remainingText = content.substring(start);
      final textPainter = TextPainter(
        text: TextSpan(text: remainingText, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null, // 不限制行数
      );

      // 2. 限制宽度，进行布局
      textPainter.layout(maxWidth: maxWidth);

      // 3. 计算能容纳的字符数
      // 使用 getPositionForOffset 找到 maxHeight 位置对应的字符索引
      final position = textPainter.getPositionForOffset(
        Offset(maxWidth, maxHeight),
      );

      int end = start + position.offset;

      // 4. 边界处理
      // 保证至少向前推进一个字符，防止死循环
      if (end <= start) {
        end = start + 1;
      }

      // 不能超过内容总长度
      if (end > content.length) {
        end = content.length;
      }

      // 5. 优化：尝试在断句位置分页
      // 避免在单词或句子中间断开
      if (end < content.length) {
        end = _findBestBreakPoint(content, start, end);
      }

      // 6. 计算实际页面高度
      final pageContent = content.substring(start, end);
      final pageTextPainter = TextPainter(
        text: TextSpan(text: pageContent, style: style),
        textDirection: TextDirection.ltr,
      );
      pageTextPainter.layout(maxWidth: maxWidth);

      // 7. 创建PageRange
      pages.add(PageRange(
        start: start,
        end: end,
        pageIndex: pageIndex,
        height: pageTextPainter.height,
      ));

      // 8. 移动到下一页
      start = end;
      pageIndex++;

      // 安全检查：防止无限循环
      if (pageIndex > 10000) {
        debugPrint('警告：分页超过10000页，可能存在死循环');
        break;
      }
    }

    return pages;
  }

  /// 找到最佳的断点位置
  /// 优先在换行符、句号、问号、感叹号等位置断开
  static int _findBestBreakPoint(String content, int start, int end) {
    // 如果距离边界很近，不做调整
    if (end - start < 10 || end >= content.length) {
      return end;
    }

    // 向前查找最多50个字符，寻找合适的断点
    final searchStart = (end - 50).clamp(start, end);
    final searchText = content.substring(searchStart, end);

    // 优先级：换行符 > 句号等 > 逗号等 > 空格
    final breakPoints = [
      '\n',
      '。', '！', '？', '；',
      '，', '、',
      ' ', '　', // 空格和全角空格
    ];

    for (final breakPoint in breakPoints) {
      final index = searchText.lastIndexOf(breakPoint);
      if (index > 0) {
        // 找到断点后，移动到断点之后的位置
        return searchStart + index + breakPoint.length;
      }
    }

    // 如果没找到合适的断点，返回原位置
    return end;
  }

  /// 增量分页：在已有分页基础上继续分页
  /// 用于渐进式渲染
  ///
  /// [existingPages] 已有的分页
  /// [content] 完整内容
  /// [maxWidth] 最大宽度
  /// [maxHeight] 最大高度
  /// [style] 文本样式
  /// [maxPages] 最多分多少页（用于控制单次分页数量）
  ///
  /// Returns: 新增的分页列表
  static List<PageRange> paginateIncremental({
    required List<PageRange> existingPages,
    required String content,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
    int maxPages = 10,
  }) {
    if (existingPages.isEmpty) {
      // 如果没有已有分页，从头开始分
      final allPages = paginate(
        content: content,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        style: style,
      );
      return allPages.take(maxPages).toList();
    }

    // 从最后一页的结束位置继续分页
    final lastPage = existingPages.last;
    final startOffset = lastPage.end;

    if (startOffset >= content.length) {
      // 已经分页完成
      return [];
    }

    final newPages = paginate(
      content: content,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      style: style,
      startOffset: startOffset,
    );

    // 修正pageIndex
    final correctedPages = newPages.map((page) {
      return page.copyWith(
        pageIndex: existingPages.length + page.pageIndex,
      );
    }).toList();

    return correctedPages.take(maxPages).toList();
  }

  /// 根据字符偏移量查找对应的页面索引
  ///
  /// 这是实现"阅读位置保持"的关键方法
  /// 当用户调整字体大小后，使用此方法找到包含原字符位置的新页面
  ///
  /// [pages] 分页列表
  /// [charOffset] 字符偏移量
  ///
  /// Returns: 页面索引，如果未找到返回-1
  static int findPageByCharOffset(List<PageRange> pages, int charOffset) {
    if (pages.isEmpty) return -1;
    if (charOffset < 0) return 0;

    // 二分查找
    int left = 0;
    int right = pages.length - 1;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final page = pages[mid];

      if (page.contains(charOffset)) {
        return mid;
      } else if (charOffset < page.start) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    // 如果未找到，返回最接近的页面
    return left.clamp(0, pages.length - 1);
  }

  /// 获取指定页面索引的字符偏移量
  ///
  /// [pages] 分页列表
  /// [pageIndex] 页面索引
  ///
  /// Returns: 字符偏移量
  static int getCharOffsetByPage(List<PageRange> pages, int pageIndex) {
    if (pages.isEmpty) return 0;
    final index = pageIndex.clamp(0, pages.length - 1);
    return pages[index].start;
  }
}
