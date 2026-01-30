import 'package:flutter/material.dart';
import 'reading_position_manager.dart';

/// 阅读器画板 (参考Gemini文档: 渲染组件 ReaderView.md)
///
/// 使用CustomPaint直接在Canvas上绘制文字，避免大量Text组件带来的性能问题
/// 这是Legado阅读器高性能渲染的核心
class ReaderPainter extends CustomPainter {
  final String content;
  final ReadingConfig config;
  final int? currentPageIndex;
  final int? totalPages;

  ReaderPainter({
    required this.content,
    required this.config,
    this.currentPageIndex,
    this.totalPages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制背景色
    final backgroundPaint = Paint()..color = config.backgroundColor;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // 2. 绘制正文内容
    if (content.isNotEmpty) {
      _drawContent(canvas, size);
    }

    // 3. 绘制页码信息
    if (currentPageIndex != null && totalPages != null) {
      _drawPageInfo(canvas, size);
    }
  }

  /// 绘制正文内容
  void _drawContent(Canvas canvas, Size size) {
    final textSpan = TextSpan(
      text: content,
      style: config.textStyle.copyWith(color: config.textColor),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: null, // 不限制行数
    );

    // 计算可用宽度(扣除内边距)
    final availableWidth =
        size.width - config.padding.left - config.padding.right;

    // 布局
    textPainter.layout(maxWidth: availableWidth);

    // 绘制(考虑内边距偏移)
    textPainter.paint(
      canvas,
      Offset(config.padding.left, config.padding.top),
    );
  }

  /// 绘制页码信息
  void _drawPageInfo(Canvas canvas, Size size) {
    // 页码文字
    final pageText = '${currentPageIndex! + 1}/$totalPages';

    // 进度百分比
    final progress = totalPages! > 0
        ? (((currentPageIndex! + 1) / totalPages!) * 100).toStringAsFixed(1)
        : '0.0';
    final progressText = '$progress%';

    // 页码样式
    final pageInfoStyle = TextStyle(
      fontSize: 12,
      color: config.textColor.withOpacity(0.6),
      fontFamily: config.fontFamily,
    );

    // 左侧页码
    final pageTextPainter = TextPainter(
      text: TextSpan(text: pageText, style: pageInfoStyle),
      textDirection: TextDirection.ltr,
    );
    pageTextPainter.layout();
    pageTextPainter.paint(
      canvas,
      Offset(
        config.padding.left,
        size.height - config.padding.bottom + 10,
      ),
    );

    // 右侧进度
    final progressTextPainter = TextPainter(
      text: TextSpan(text: progressText, style: pageInfoStyle),
      textDirection: TextDirection.ltr,
    );
    progressTextPainter.layout();
    progressTextPainter.paint(
      canvas,
      Offset(
        size.width - config.padding.right - progressTextPainter.width,
        size.height - config.padding.bottom + 10,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant ReaderPainter oldDelegate) {
    // 只有当内容、配置或页码改变时才重绘
    return oldDelegate.content != content ||
        oldDelegate.config != config ||
        oldDelegate.currentPageIndex != currentPageIndex ||
        oldDelegate.totalPages != totalPages;
  }
}

/// 高级阅读器画板 (支持更多功能)
///
/// 包含：
/// - 电池和时间显示
/// - 章节标题
/// - 阅读进度条
class AdvancedReaderPainter extends CustomPainter {
  final String content;
  final ReadingConfig config;
  final String? chapterTitle;
  final int? currentPageIndex;
  final int? totalPages;
  final double? batteryLevel; // 0.0-1.0
  final DateTime? currentTime;

  AdvancedReaderPainter({
    required this.content,
    required this.config,
    this.chapterTitle,
    this.currentPageIndex,
    this.totalPages,
    this.batteryLevel,
    this.currentTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制背景色
    final backgroundPaint = Paint()..color = config.backgroundColor;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // 2. 绘制顶部信息(章节标题、时间、电量)
    _drawTopInfo(canvas, size);

    // 3. 绘制正文内容
    if (content.isNotEmpty) {
      _drawContent(canvas, size);
    }

    // 4. 绘制底部信息(页码、进度)
    _drawBottomInfo(canvas, size);
  }

  /// 绘制顶部信息
  void _drawTopInfo(Canvas canvas, Size size) {
    final infoStyle = TextStyle(
      fontSize: 11,
      color: config.textColor.withOpacity(0.5),
      fontFamily: config.fontFamily,
    );

    // 左侧章节标题
    if (chapterTitle != null && chapterTitle!.isNotEmpty) {
      final titlePainter = TextPainter(
        text: TextSpan(text: chapterTitle, style: infoStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      titlePainter.layout(maxWidth: size.width / 2);
      titlePainter.paint(
        canvas,
        Offset(config.padding.left, 10),
      );
    }

    // 右侧时间和电量
    if (currentTime != null) {
      final timeText =
          '${currentTime!.hour.toString().padLeft(2, '0')}:${currentTime!.minute.toString().padLeft(2, '0')}';
      final timePainter = TextPainter(
        text: TextSpan(text: timeText, style: infoStyle),
        textDirection: TextDirection.ltr,
      );
      timePainter.layout();

      double rightX = size.width - config.padding.right - timePainter.width;

      // 如果有电量信息，先绘制电量图标
      if (batteryLevel != null) {
        rightX = _drawBatteryIcon(canvas, rightX - 25, 10, batteryLevel!);
      }

      timePainter.paint(canvas, Offset(rightX, 10));
    }
  }

  /// 绘制电量图标
  double _drawBatteryIcon(Canvas canvas, double x, double y, double level) {
    final paint = Paint()
      ..color = _getBatteryColor(level)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 电池外框
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y + 2, 20, 10),
      const Radius.circular(2),
    );
    canvas.drawRRect(rect, paint);

    // 电池正极
    canvas.drawRect(Rect.fromLTWH(x + 20, y + 5, 2, 4), paint);

    // 电量填充
    final fillPaint = Paint()
      ..color = _getBatteryColor(level)
      ..style = PaintingStyle.fill;
    final fillWidth = 18 * level;
    canvas.drawRect(Rect.fromLTWH(x + 1, y + 3, fillWidth, 8), fillPaint);

    return x;
  }

  /// 获取电量颜色
  Color _getBatteryColor(double level) {
    if (level > 0.2) return config.textColor.withOpacity(0.5);
    return Colors.red.withOpacity(0.7);
  }

  /// 绘制正文内容
  void _drawContent(Canvas canvas, Size size) {
    final textSpan = TextSpan(
      text: content,
      style: config.textStyle.copyWith(color: config.textColor),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final availableWidth =
        size.width - config.padding.left - config.padding.right;
    textPainter.layout(maxWidth: availableWidth);

    // 向下偏移，为顶部信息留出空间
    textPainter.paint(
      canvas,
      Offset(config.padding.left, config.padding.top + 15),
    );
  }

  /// 绘制底部信息
  void _drawBottomInfo(Canvas canvas, Size size) {
    if (currentPageIndex == null || totalPages == null) return;

    final pageInfoStyle = TextStyle(
      fontSize: 11,
      color: config.textColor.withOpacity(0.5),
      fontFamily: config.fontFamily,
    );

    // 页码
    final pageText = '${currentPageIndex! + 1}/$totalPages';
    final pageTextPainter = TextPainter(
      text: TextSpan(text: pageText, style: pageInfoStyle),
      textDirection: TextDirection.ltr,
    );
    pageTextPainter.layout();
    pageTextPainter.paint(
      canvas,
      Offset(
        config.padding.left,
        size.height - config.padding.bottom + 5,
      ),
    );

    // 进度百分比
    final progress = totalPages! > 0
        ? (((currentPageIndex! + 1) / totalPages!) * 100).toStringAsFixed(1)
        : '0.0';
    final progressText = '$progress%';
    final progressTextPainter = TextPainter(
      text: TextSpan(text: progressText, style: pageInfoStyle),
      textDirection: TextDirection.ltr,
    );
    progressTextPainter.layout();
    progressTextPainter.paint(
      canvas,
      Offset(
        size.width - config.padding.right - progressTextPainter.width,
        size.height - config.padding.bottom + 5,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant AdvancedReaderPainter oldDelegate) {
    return oldDelegate.content != content ||
        oldDelegate.config != config ||
        oldDelegate.chapterTitle != chapterTitle ||
        oldDelegate.currentPageIndex != currentPageIndex ||
        oldDelegate.totalPages != totalPages ||
        oldDelegate.batteryLevel != batteryLevel ||
        oldDelegate.currentTime != currentTime;
  }
}
