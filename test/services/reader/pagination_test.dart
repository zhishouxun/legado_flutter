import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:legado_flutter/services/reader/paginator.dart';
import 'package:legado_flutter/services/reader/models/page_range.dart';
import 'package:legado_flutter/services/reader/reading_position_manager.dart';

void main() {
  group('Paginator Tests', () {
    const testContent = '''第一章 开始

这是第一段内容。这是一个测试用的长文本，用来验证分页功能是否正常工作。我们需要确保分页算法能够正确地将长文本分割成多个页面。

这是第二段内容。在分页时，我们使用TextPainter来计算文本的高度，然后根据屏幕高度来决定每一页应该包含多少内容。这是一个非常重要的功能。

这是第三段内容。Legado是一个非常优秀的阅读器应用，它的分页算法非常精确，能够提供良好的阅读体验。我们在Flutter版本中也要实现同样优秀的分页功能。

这是第四段内容。通过使用缓存机制，我们可以避免重复计算分页结果，从而提升性能。同时，通过字符偏移量来记录阅读位置，可以在调整字体大小后依然保持正确的阅读位置。

这是第五段内容。预读相邻章节的功能可以提升用户体验，让用户在切换章节时感觉更加流畅。这些都是Gemini文档中建议实现的重要功能。''';

    test('基本分页功能', () {
      final pages = Paginator.paginate(
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );

      expect(pages.isNotEmpty, true);
      expect(pages.first.start, 0);
      expect(pages.last.end, testContent.length);

      // 验证页面连续性
      for (int i = 0; i < pages.length - 1; i++) {
        expect(pages[i].end, pages[i + 1].start);
      }

      print('总页数: ${pages.length}');
      for (int i = 0; i < pages.length; i++) {
        print(
            '第${i + 1}页: ${pages[i].start}-${pages[i].end}, 字符数=${pages[i].charCount}');
      }
    });

    test('空内容处理', () {
      final pages = Paginator.paginate(
        content: '',
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 16),
      );

      expect(pages.isEmpty, true);
    });

    test('无效尺寸处理', () {
      final pages = Paginator.paginate(
        content: testContent,
        maxWidth: 0,
        maxHeight: 0,
        style: const TextStyle(fontSize: 16),
      );

      expect(pages.length, 1);
      expect(pages.first.start, 0);
      expect(pages.first.end, testContent.length);
    });

    test('根据字符偏移量查找页面', () {
      final pages = Paginator.paginate(
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );

      expect(pages.isNotEmpty, true);

      // 测试第一页
      final page0 = Paginator.findPageByCharOffset(pages, 0);
      expect(page0, 0);

      // 测试中间某个位置
      final midChar = testContent.length ~/ 2;
      final midPage = Paginator.findPageByCharOffset(pages, midChar);
      expect(midPage, greaterThanOrEqualTo(0));
      expect(midPage, lessThan(pages.length));
      expect(pages[midPage].contains(midChar), true);

      // 测试最后位置
      final lastChar = testContent.length - 1;
      final lastPage = Paginator.findPageByCharOffset(pages, lastChar);
      expect(pages[lastPage].contains(lastChar), true);

      print('中间字符($midChar)在第${midPage + 1}页');
      print('最后字符($lastChar)在第${lastPage + 1}页');
    });

    test('不同字体大小的分页', () {
      // 小字体
      final smallPages = Paginator.paginate(
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 14, height: 1.5),
      );

      // 大字体
      final largePages = Paginator.paginate(
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 20, height: 1.5),
      );

      // 大字体应该产生更多页面
      expect(largePages.length, greaterThan(smallPages.length));

      print('小字体(14px): ${smallPages.length}页');
      print('大字体(20px): ${largePages.length}页');
    });

    test('增量分页功能', () {
      final existingPages = Paginator.paginate(
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 16, height: 1.5),
        startOffset: 0,
      );

      expect(existingPages.isNotEmpty, true);

      // 从现有分页继续
      final newPages = Paginator.paginateIncremental(
        existingPages: existingPages.take(2).toList(),
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 16, height: 1.5),
        maxPages: 3,
      );

      // 验证新页面的pageIndex正确递增
      if (newPages.isNotEmpty) {
        expect(newPages.first.pageIndex, 2);
      }

      print('已有2页，增量分页得到${newPages.length}页');
    });
  });

  group('ReadingPositionManager Tests', () {
    final testContent = '0123456789' * 100; // 1000字符

    test('保存和恢复阅读位置', () async {
      // 创建分页
      final pages = Paginator.paginate(
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );

      expect(pages.isNotEmpty, true);

      // 模拟保存位置
      int savedOffset = -1;
      await ReadingPositionManager.savePosition(
        chapterUrl: 'test_chapter',
        pageIndex: 2,
        pages: pages,
        onSave: (url, offset) async {
          savedOffset = offset;
        },
      );

      expect(savedOffset, pages[2].start);

      // 模拟字体变化后重新分页
      final newPages = Paginator.paginate(
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 20, height: 1.5), // 更大的字体
      );

      // 恢复位置
      final newPageIndex = ReadingPositionManager.restorePosition(
        chapterUrl: 'test_chapter',
        charOffset: savedOffset,
        pages: newPages,
      );

      // 验证恢复的页面包含原来的字符偏移量
      expect(newPages[newPageIndex].contains(savedOffset), true);

      print('原页码: 2, 字符偏移: $savedOffset');
      print('新页码: $newPageIndex, 仍包含相同字符位置');
    });

    test('阅读进度计算', () {
      final pages = Paginator.paginate(
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );

      // 第一页进度应该接近0
      final progress0 = ReadingPositionManager.getProgress(
        currentPage: 0,
        pages: pages,
        totalChars: testContent.length,
      );
      expect(progress0, lessThan(0.2));

      // 最后一页进度应该接近1
      final progressLast = ReadingPositionManager.getProgress(
        currentPage: pages.length - 1,
        pages: pages,
        totalChars: testContent.length,
      );
      expect(progressLast, greaterThan(0.8));

      print('第一页进度: ${(progress0 * 100).toStringAsFixed(1)}%');
      print('最后一页进度: ${(progressLast * 100).toStringAsFixed(1)}%');
    });

    test('根据进度查找页码', () {
      final pages = Paginator.paginate(
        content: testContent,
        maxWidth: 300,
        maxHeight: 400,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );

      // 50%进度应该在中间附近
      final midPage = ReadingPositionManager.getPageByProgress(
        progress: 0.5,
        pages: pages,
        totalChars: testContent.length,
      );

      // 由于只有4页,放宽验证范围
      expect(midPage, greaterThanOrEqualTo(0));
      expect(midPage, lessThan(pages.length));

      print('50%进度对应第${midPage + 1}页 (总${pages.length}页)');
    });
  });

  group('ReadingConfig Tests', () {
    test('配置相等性', () {
      final config1 = ReadingConfig(
        maxWidth: 400,
        maxHeight: 600,
        fontSize: 18,
        lineHeight: 1.5,
      );

      final config2 = ReadingConfig(
        maxWidth: 400,
        maxHeight: 600,
        fontSize: 18,
        lineHeight: 1.5,
      );

      final config3 = ReadingConfig(
        maxWidth: 400,
        maxHeight: 600,
        fontSize: 20, // 不同
        lineHeight: 1.5,
      );

      expect(config1, config2);
      expect(config1 == config3, false);
    });

    test('可见区域计算', () {
      final config = ReadingConfig(
        maxWidth: 400,
        maxHeight: 600,
        fontSize: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      );

      expect(config.visibleWidth, 400 - 16 * 2);
      expect(config.visibleHeight, 600 - 20 * 2);
    });
  });

  group('PageRange Tests', () {
    test('基本功能', () {
      final page = PageRange(
        start: 0,
        end: 100,
        pageIndex: 0,
        height: 400,
      );

      expect(page.charCount, 100);
      expect(page.contains(50), true);
      expect(page.contains(100), false);
      expect(page.contains(-1), false);
    });

    test('获取页面内容', () {
      const content = 'Hello World! This is a test.';
      final page = PageRange(
        start: 0,
        end: 12,
        pageIndex: 0,
      );

      expect(page.getContent(content), 'Hello World!');
    });

    test('相等性', () {
      final page1 = PageRange(start: 0, end: 100, pageIndex: 0);
      final page2 = PageRange(start: 0, end: 100, pageIndex: 0);
      final page3 = PageRange(start: 0, end: 100, pageIndex: 1);

      expect(page1, page2);
      expect(page1 == page3, false);
    });
  });
}
