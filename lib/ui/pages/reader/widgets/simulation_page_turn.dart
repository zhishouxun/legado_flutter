import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 仿真翻页效果组件
/// 参考项目：io.legado.app.ui.book.read.page.delegate.SimulationPageDelegate
///
/// 实现纸张翻折效果，使用贝塞尔曲线计算页面边缘
class SimulationPageTurn extends StatefulWidget {
  final Widget currentPage;
  final Widget? prevPage;
  final Widget? nextPage;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final bool enabled;

  const SimulationPageTurn({
    super.key,
    required this.currentPage,
    this.prevPage,
    this.nextPage,
    this.onPrevPage,
    this.onNextPage,
    this.onTap,
    this.backgroundColor = Colors.white,
    this.enabled = true,
  });

  @override
  State<SimulationPageTurn> createState() => _SimulationPageTurnState();
}

class _SimulationPageTurnState extends State<SimulationPageTurn>
    with SingleTickerProviderStateMixin {
  // 触摸点
  Offset _touchPoint = Offset.zero;
  Offset _startPoint = Offset.zero;

  // 角点位置（页脚）
  int _cornerX = 1;
  int _cornerY = 1;

  // 翻页方向
  PageTurnDirection _direction = PageTurnDirection.none;

  // 是否正在拖动
  bool _isDragging = false;

  // 是否取消翻页
  bool _isCancel = false;

  // 缓存是否为右上/左下角（避免在build时访问context.size）
  bool _cachedIsRtOrLb = false;

  // 动画控制器
  late AnimationController _animationController;
  Animation<Offset>? _animation;

  // 页面截图
  ui.Image? _currentPageImage;
  ui.Image? _prevPageImage;
  ui.Image? _nextPageImage;

  // 截图 key
  final GlobalKey _currentPageKey = GlobalKey();
  final GlobalKey _prevPageKey = GlobalKey();
  final GlobalKey _nextPageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.addListener(_onAnimationUpdate);
    _animationController.addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _currentPageImage?.dispose();
    _prevPageImage?.dispose();
    _nextPageImage?.dispose();
    super.dispose();
  }

  void _onAnimationUpdate() {
    if (_animation != null) {
      setState(() {
        _touchPoint = _animation!.value;
      });
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (!_isCancel) {
        // 翻页完成
        if (_direction == PageTurnDirection.next) {
          widget.onNextPage?.call();
        } else if (_direction == PageTurnDirection.prev) {
          widget.onPrevPage?.call();
        }
      }
      setState(() {
        _isDragging = false;
        _direction = PageTurnDirection.none;
      });
    }
  }

  /// 计算角点位置
  void _calcCornerXY(Offset point, Size size) {
    _cornerX = point.dx <= size.width / 2 ? 0 : size.width.toInt();
    _cornerY = point.dy <= size.height / 2 ? 0 : size.height.toInt();
  }

  /// 判断是否为右上/左下角
  /// 使用缓存值避免在build时访问context.size
  bool get _isRtOrLb => _cachedIsRtOrLb;

  /// 更新是否为右上/左下角的缓存值
  void _updateIsRtOrLb(Size size) {
    _cachedIsRtOrLb = (_cornerX == 0 && _cornerY == size.height.toInt()) ||
        (_cornerY == 0 && _cornerX == size.width.toInt());
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.enabled) return;

    final size = context.size ?? Size.zero;
    _startPoint = details.localPosition;
    _touchPoint = details.localPosition;
    _calcCornerXY(details.localPosition, size);
    _updateIsRtOrLb(size); // 更新缓存值
    _isDragging = true;
    _direction = PageTurnDirection.none;
    _isCancel = false;
    _animationController.stop();

    // 捕获页面截图
    _capturePageImages();

    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.enabled || !_isDragging) return;

    final size = context.size ?? Size.zero;
    _touchPoint = details.localPosition;

    // 确定翻页方向
    if (_direction == PageTurnDirection.none) {
      final dx = _touchPoint.dx - _startPoint.dx;
      if (dx.abs() > 10) {
        if (dx > 0) {
          // 向右滑动 - 上一页
          if (widget.prevPage != null) {
            _direction = PageTurnDirection.prev;
            // 上一页滑动时，从右下角开始
            if (_startPoint.dx > size.width / 2) {
              _calcCornerXY(Offset(_startPoint.dx, size.height), size);
            } else {
              _calcCornerXY(
                  Offset(size.width - _startPoint.dx, size.height), size);
            }
            _updateIsRtOrLb(size); // 更新缓存值
          }
        } else {
          // 向左滑动 - 下一页
          if (widget.nextPage != null) {
            _direction = PageTurnDirection.next;
            if (size.width / 2 > _startPoint.dx) {
              _calcCornerXY(
                  Offset(size.width - _startPoint.dx, _startPoint.dy), size);
            }
            _updateIsRtOrLb(size); // 更新缓存值
          }
        }
      }
    }

    // 调整触摸点（仿真效果：中间区域拖动时固定Y坐标）
    if (_startPoint.dy > size.height / 3 &&
        _startPoint.dy < size.height * 2 / 3) {
      if (_direction == PageTurnDirection.prev) {
        _touchPoint = Offset(_touchPoint.dx, size.height);
      }
    }
    if (_startPoint.dy > size.height / 3 && _startPoint.dy < size.height / 2) {
      if (_direction == PageTurnDirection.next) {
        _touchPoint = Offset(_touchPoint.dx, 1);
      }
    }

    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.enabled || !_isDragging) return;

    final size = context.size ?? Size.zero;

    // 判断是否取消翻页
    if (_direction == PageTurnDirection.next) {
      _isCancel = _touchPoint.dx > _startPoint.dx;
    } else if (_direction == PageTurnDirection.prev) {
      _isCancel = _touchPoint.dx < _startPoint.dx;
    } else {
      _isCancel = true;
    }

    // 计算动画终点
    Offset endPoint;
    if (_isCancel) {
      // 取消：返回原位
      if (_cornerX > 0 && _direction == PageTurnDirection.next) {
        endPoint = Offset(size.width, _cornerY == 0 ? 0 : size.height);
      } else {
        endPoint = Offset(0, _cornerY == 0 ? 0 : size.height);
      }
    } else {
      // 完成翻页：滑到对面
      if (_cornerX > 0 && _direction == PageTurnDirection.next) {
        endPoint = Offset(-size.width, _cornerY == 0 ? 0 : size.height);
      } else {
        endPoint = Offset(size.width * 2, _cornerY == 0 ? 0 : size.height);
      }
    }

    // 启动动画
    _animation = Tween<Offset>(
      begin: _touchPoint,
      end: endPoint,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.reset();
    _animationController.forward();
  }

  void _onTap() {
    if (!_isDragging && _direction == PageTurnDirection.none) {
      widget.onTap?.call();
    }
  }

  /// 捕获页面截图（简化实现：直接使用 Widget）
  Future<void> _capturePageImages() async {
    // 在实际使用中，这里可以用 RenderRepaintBoundary 来捕获截图
    // 为简化实现，我们直接在 CustomPainter 中使用 Widget
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: _onTap,
      child: Stack(
        children: [
          // 下一页/上一页（背景）
          if (_isDragging &&
              _direction == PageTurnDirection.next &&
              widget.nextPage != null)
            Positioned.fill(
              key: _nextPageKey,
              child: widget.nextPage!,
            ),
          if (_isDragging &&
              _direction == PageTurnDirection.prev &&
              widget.prevPage != null)
            Positioned.fill(
              key: _prevPageKey,
              child: widget.currentPage,
            ),

          // 当前页（使用 CustomPaint 绘制翻页效果）
          Positioned.fill(
            key: _currentPageKey,
            child: _isDragging && _direction != PageTurnDirection.none
                ? CustomPaint(
                    painter: SimulationPagePainter(
                      touchPoint: _touchPoint,
                      cornerX: _cornerX,
                      cornerY: _cornerY,
                      direction: _direction,
                      backgroundColor: widget.backgroundColor,
                      isRtOrLb: _isRtOrLb,
                    ),
                    child: ClipPath(
                      clipper: SimulationPageClipper(
                        touchPoint: _touchPoint,
                        cornerX: _cornerX,
                        cornerY: _cornerY,
                        isRtOrLb: _isRtOrLb,
                      ),
                      child: _direction == PageTurnDirection.prev
                          ? widget.prevPage ?? widget.currentPage
                          : widget.currentPage,
                    ),
                  )
                : widget.currentPage,
          ),

          // 翻起的页面背面
          if (_isDragging && _direction != PageTurnDirection.none)
            Positioned.fill(
              child: CustomPaint(
                painter: SimulationBackPagePainter(
                  touchPoint: _touchPoint,
                  cornerX: _cornerX,
                  cornerY: _cornerY,
                  direction: _direction,
                  backgroundColor: widget.backgroundColor,
                  isRtOrLb: _isRtOrLb,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 翻页方向
enum PageTurnDirection { none, prev, next }

/// 仿真翻页绘制器
class SimulationPagePainter extends CustomPainter {
  final Offset touchPoint;
  final int cornerX;
  final int cornerY;
  final PageTurnDirection direction;
  final Color backgroundColor;
  final bool isRtOrLb;

  SimulationPagePainter({
    required this.touchPoint,
    required this.cornerX,
    required this.cornerY,
    required this.direction,
    required this.backgroundColor,
    required this.isRtOrLb,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (direction == PageTurnDirection.none) return;

    final points = _calcBezierPoints(size);

    // 绘制阴影
    _drawShadow(canvas, size, points);
  }

  /// 计算贝塞尔曲线控制点
  BezierPoints _calcBezierPoints(Size size) {
    final mTouchX = touchPoint.dx.clamp(0.1, size.width - 0.1);
    final mTouchY = touchPoint.dy.clamp(0.1, size.height - 0.1);

    final mMiddleX = (mTouchX + cornerX) / 2;
    final mMiddleY = (mTouchY + cornerY) / 2;

    // 贝塞尔曲线控制点1
    double bezierControl1X;
    if ((cornerX - mMiddleX).abs() < 0.01) {
      bezierControl1X = mMiddleX;
    } else {
      bezierControl1X = mMiddleX -
          (cornerY - mMiddleY) * (cornerY - mMiddleY) / (cornerX - mMiddleX);
    }
    final bezierControl1Y = cornerY.toDouble();

    // 贝塞尔曲线控制点2
    final bezierControl2X = cornerX.toDouble();
    double bezierControl2Y;
    if ((cornerY - mMiddleY).abs() < 0.01) {
      bezierControl2Y =
          mMiddleY - (cornerX - mMiddleX) * (cornerX - mMiddleX) / 0.1;
    } else {
      bezierControl2Y = mMiddleY -
          (cornerX - mMiddleX) * (cornerX - mMiddleX) / (cornerY - mMiddleY);
    }

    // 贝塞尔曲线起点
    var bezierStart1X = bezierControl1X - (cornerX - bezierControl1X) / 2;
    final bezierStart1Y = cornerY.toDouble();

    // 边界修正
    if (mTouchX > 0 && mTouchX < size.width) {
      if (bezierStart1X < 0 || bezierStart1X > size.width) {
        if (bezierStart1X < 0) {
          bezierStart1X = size.width - bezierStart1X;
        }
      }
    }

    final bezierStart2X = cornerX.toDouble();
    final bezierStart2Y = bezierControl2Y - (cornerY - bezierControl2Y) / 2;

    // 计算交点
    final bezierEnd1 = _getCross(
      Offset(mTouchX, mTouchY),
      Offset(bezierControl1X, bezierControl1Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    final bezierEnd2 = _getCross(
      Offset(mTouchX, mTouchY),
      Offset(bezierControl2X, bezierControl2Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    // 贝塞尔曲线顶点
    final bezierVertex1X =
        (bezierStart1X + 2 * bezierControl1X + bezierEnd1.dx) / 4;
    final bezierVertex1Y =
        (2 * bezierControl1Y + bezierStart1Y + bezierEnd1.dy) / 4;
    final bezierVertex2X =
        (bezierStart2X + 2 * bezierControl2X + bezierEnd2.dx) / 4;
    final bezierVertex2Y =
        (2 * bezierControl2Y + bezierStart2Y + bezierEnd2.dy) / 4;

    return BezierPoints(
      touch: Offset(mTouchX, mTouchY),
      control1: Offset(bezierControl1X, bezierControl1Y),
      control2: Offset(bezierControl2X, bezierControl2Y),
      start1: Offset(bezierStart1X, bezierStart1Y),
      start2: Offset(bezierStart2X, bezierStart2Y),
      end1: bezierEnd1,
      end2: bezierEnd2,
      vertex1: Offset(bezierVertex1X, bezierVertex1Y),
      vertex2: Offset(bezierVertex2X, bezierVertex2Y),
    );
  }

  /// 求两直线交点
  Offset _getCross(Offset p1, Offset p2, Offset p3, Offset p4) {
    final a1 = (p2.dy - p1.dy) / (p2.dx - p1.dx + 0.0001);
    final b1 = (p1.dx * p2.dy - p2.dx * p1.dy) / (p1.dx - p2.dx + 0.0001);
    final a2 = (p4.dy - p3.dy) / (p4.dx - p3.dx + 0.0001);
    final b2 = (p3.dx * p4.dy - p4.dx * p3.dy) / (p3.dx - p4.dx + 0.0001);
    final x = (b2 - b1) / (a1 - a2 + 0.0001);
    final y = a1 * x + b1;
    return Offset(x, y);
  }

  /// 绘制阴影
  void _drawShadow(Canvas canvas, Size size, BezierPoints points) {
    // 计算阴影角度
    final degree = atan2(
      (points.control1.dx - cornerX).abs(),
      (points.control2.dy - cornerY).abs(),
    );

    // 阴影宽度
    final shadowWidth = 25.0;

    // 绘制翻起页阴影
    final shadowPath = Path();
    final d1 = shadowWidth * 1.414 * cos(pi / 4 - degree);
    final d2 = shadowWidth * 1.414 * sin(pi / 4 - degree);

    final shadowX = points.touch.dx + d1;
    final shadowY = isRtOrLb ? points.touch.dy + d2 : points.touch.dy - d2;

    shadowPath.moveTo(shadowX, shadowY);
    shadowPath.lineTo(points.touch.dx, points.touch.dy);
    shadowPath.lineTo(points.control1.dx, points.control1.dy);
    shadowPath.lineTo(points.start1.dx, points.start1.dy);
    shadowPath.close();

    // 创建阴影渐变
    final shadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(points.control1.dx, points.control1.dy),
        Offset(points.control1.dx + (isRtOrLb ? shadowWidth : -shadowWidth),
            points.control1.dy),
        [Colors.black.withOpacity(0.3), Colors.transparent],
      );

    canvas.drawPath(shadowPath, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant SimulationPagePainter oldDelegate) {
    return touchPoint != oldDelegate.touchPoint ||
        cornerX != oldDelegate.cornerX ||
        cornerY != oldDelegate.cornerY;
  }
}

/// 仿真翻页裁剪器
class SimulationPageClipper extends CustomClipper<Path> {
  final Offset touchPoint;
  final int cornerX;
  final int cornerY;
  final bool isRtOrLb;

  SimulationPageClipper({
    required this.touchPoint,
    required this.cornerX,
    required this.cornerY,
    required this.isRtOrLb,
  });

  @override
  Path getClip(Size size) {
    final mTouchX = touchPoint.dx.clamp(0.1, size.width - 0.1);
    final mTouchY = touchPoint.dy.clamp(0.1, size.height - 0.1);

    final mMiddleX = (mTouchX + cornerX) / 2;
    final mMiddleY = (mTouchY + cornerY) / 2;

    // 计算贝塞尔曲线控制点
    double bezierControl1X;
    if ((cornerX - mMiddleX).abs() < 0.01) {
      bezierControl1X = mMiddleX;
    } else {
      bezierControl1X = mMiddleX -
          (cornerY - mMiddleY) * (cornerY - mMiddleY) / (cornerX - mMiddleX);
    }
    final bezierControl1Y = cornerY.toDouble();

    final bezierControl2X = cornerX.toDouble();
    double bezierControl2Y;
    if ((cornerY - mMiddleY).abs() < 0.01) {
      bezierControl2Y =
          mMiddleY - (cornerX - mMiddleX) * (cornerX - mMiddleX) / 0.1;
    } else {
      bezierControl2Y = mMiddleY -
          (cornerX - mMiddleX) * (cornerX - mMiddleX) / (cornerY - mMiddleY);
    }

    var bezierStart1X = bezierControl1X - (cornerX - bezierControl1X) / 2;
    final bezierStart1Y = cornerY.toDouble();

    if (mTouchX > 0 && mTouchX < size.width) {
      if (bezierStart1X < 0 || bezierStart1X > size.width) {
        if (bezierStart1X < 0) {
          bezierStart1X = size.width - bezierStart1X;
        }
      }
    }

    final bezierStart2X = cornerX.toDouble();
    final bezierStart2Y = bezierControl2Y - (cornerY - bezierControl2Y) / 2;

    final bezierEnd1 = _getCross(
      Offset(mTouchX, mTouchY),
      Offset(bezierControl1X, bezierControl1Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    final bezierEnd2 = _getCross(
      Offset(mTouchX, mTouchY),
      Offset(bezierControl2X, bezierControl2Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    // 创建裁剪路径
    final path = Path();
    path.moveTo(bezierStart1X, bezierStart1Y);
    path.quadraticBezierTo(
        bezierControl1X, bezierControl1Y, bezierEnd1.dx, bezierEnd1.dy);
    path.lineTo(mTouchX, mTouchY);
    path.lineTo(bezierEnd2.dx, bezierEnd2.dy);
    path.quadraticBezierTo(
        bezierControl2X, bezierControl2Y, bezierStart2X, bezierStart2Y);
    path.lineTo(cornerX.toDouble(), cornerY.toDouble());
    path.close();

    // 使用差集：整个页面减去翻起的部分
    final fullPath = Path()..addRect(Offset.zero & size);
    return Path.combine(PathOperation.difference, fullPath, path);
  }

  Offset _getCross(Offset p1, Offset p2, Offset p3, Offset p4) {
    final a1 = (p2.dy - p1.dy) / (p2.dx - p1.dx + 0.0001);
    final b1 = (p1.dx * p2.dy - p2.dx * p1.dy) / (p1.dx - p2.dx + 0.0001);
    final a2 = (p4.dy - p3.dy) / (p4.dx - p3.dx + 0.0001);
    final b2 = (p3.dx * p4.dy - p4.dx * p3.dy) / (p3.dx - p4.dx + 0.0001);
    final x = (b2 - b1) / (a1 - a2 + 0.0001);
    final y = a1 * x + b1;
    return Offset(x, y);
  }

  @override
  bool shouldReclip(covariant SimulationPageClipper oldClipper) {
    return touchPoint != oldClipper.touchPoint ||
        cornerX != oldClipper.cornerX ||
        cornerY != oldClipper.cornerY;
  }
}

/// 翻起页背面绘制器
class SimulationBackPagePainter extends CustomPainter {
  final Offset touchPoint;
  final int cornerX;
  final int cornerY;
  final PageTurnDirection direction;
  final Color backgroundColor;
  final bool isRtOrLb;

  SimulationBackPagePainter({
    required this.touchPoint,
    required this.cornerX,
    required this.cornerY,
    required this.direction,
    required this.backgroundColor,
    required this.isRtOrLb,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (direction == PageTurnDirection.none) return;

    final mTouchX = touchPoint.dx.clamp(0.1, size.width - 0.1);
    final mTouchY = touchPoint.dy.clamp(0.1, size.height - 0.1);

    final mMiddleX = (mTouchX + cornerX) / 2;
    final mMiddleY = (mTouchY + cornerY) / 2;

    // 计算贝塞尔曲线控制点
    double bezierControl1X;
    if ((cornerX - mMiddleX).abs() < 0.01) {
      bezierControl1X = mMiddleX;
    } else {
      bezierControl1X = mMiddleX -
          (cornerY - mMiddleY) * (cornerY - mMiddleY) / (cornerX - mMiddleX);
    }
    final bezierControl1Y = cornerY.toDouble();

    final bezierControl2X = cornerX.toDouble();
    double bezierControl2Y;
    if ((cornerY - mMiddleY).abs() < 0.01) {
      bezierControl2Y =
          mMiddleY - (cornerX - mMiddleX) * (cornerX - mMiddleX) / 0.1;
    } else {
      bezierControl2Y = mMiddleY -
          (cornerX - mMiddleX) * (cornerX - mMiddleX) / (cornerY - mMiddleY);
    }

    var bezierStart1X = bezierControl1X - (cornerX - bezierControl1X) / 2;
    final bezierStart1Y = cornerY.toDouble();

    if (mTouchX > 0 && mTouchX < size.width) {
      if (bezierStart1X < 0 || bezierStart1X > size.width) {
        if (bezierStart1X < 0) {
          bezierStart1X = size.width - bezierStart1X;
        }
      }
    }

    final bezierStart2X = cornerX.toDouble();
    final bezierStart2Y = bezierControl2Y - (cornerY - bezierControl2Y) / 2;

    final bezierEnd1 = _getCross(
      Offset(mTouchX, mTouchY),
      Offset(bezierControl1X, bezierControl1Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    final bezierEnd2 = _getCross(
      Offset(mTouchX, mTouchY),
      Offset(bezierControl2X, bezierControl2Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    final bezierVertex1X =
        (bezierStart1X + 2 * bezierControl1X + bezierEnd1.dx) / 4;
    final bezierVertex1Y =
        (2 * bezierControl1Y + bezierStart1Y + bezierEnd1.dy) / 4;
    final bezierVertex2X =
        (bezierStart2X + 2 * bezierControl2X + bezierEnd2.dx) / 4;
    final bezierVertex2Y =
        (2 * bezierControl2Y + bezierStart2Y + bezierEnd2.dy) / 4;

    // 绘制翻起页的背面（灰色渐变）
    final backPath = Path();
    backPath.moveTo(bezierVertex2X, bezierVertex2Y);
    backPath.lineTo(bezierVertex1X, bezierVertex1Y);
    backPath.lineTo(bezierEnd1.dx, bezierEnd1.dy);
    backPath.lineTo(mTouchX, mTouchY);
    backPath.lineTo(bezierEnd2.dx, bezierEnd2.dy);
    backPath.close();

    // 计算背面颜色（根据翻折程度调整明度）
    final foldRatio = (size.width - mTouchX.abs()) / size.width;
    final backColor = Color.lerp(
      backgroundColor.withOpacity(0.8),
      backgroundColor.withOpacity(0.4),
      foldRatio,
    )!;

    final backPaint = Paint()
      ..color = backColor
      ..style = PaintingStyle.fill;

    // 先绘制第一层路径（排除当前页显示区域）
    final firstPath = Path();
    firstPath.moveTo(bezierStart1X, bezierStart1Y);
    firstPath.quadraticBezierTo(
        bezierControl1X, bezierControl1Y, bezierEnd1.dx, bezierEnd1.dy);
    firstPath.lineTo(mTouchX, mTouchY);
    firstPath.lineTo(bezierEnd2.dx, bezierEnd2.dy);
    firstPath.quadraticBezierTo(
        bezierControl2X, bezierControl2Y, bezierStart2X, bezierStart2Y);
    firstPath.lineTo(cornerX.toDouble(), cornerY.toDouble());
    firstPath.close();

    canvas.save();
    canvas.clipPath(firstPath);
    canvas.clipPath(backPath);
    canvas.drawRect(Offset.zero & size, backPaint);

    // 绘制折叠阴影
    final shadowWidth = ((bezierStart1X - bezierControl1X).abs() +
            (bezierStart2Y - bezierControl2Y).abs()) /
        4;

    final shadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(bezierStart1X, bezierStart1Y),
        Offset(bezierStart1X + (isRtOrLb ? shadowWidth : -shadowWidth),
            bezierStart1Y),
        [Colors.black.withOpacity(0.2), Colors.transparent],
      );

    final shadowRect = Rect.fromLTRB(
      isRtOrLb ? bezierStart1X - 1 : bezierStart1X - shadowWidth - 1,
      bezierStart1Y,
      isRtOrLb ? bezierStart1X + shadowWidth + 1 : bezierStart1X + 1,
      bezierStart1Y + size.height,
    );
    canvas.drawRect(shadowRect, shadowPaint);

    canvas.restore();
  }

  Offset _getCross(Offset p1, Offset p2, Offset p3, Offset p4) {
    final a1 = (p2.dy - p1.dy) / (p2.dx - p1.dx + 0.0001);
    final b1 = (p1.dx * p2.dy - p2.dx * p1.dy) / (p1.dx - p2.dx + 0.0001);
    final a2 = (p4.dy - p3.dy) / (p4.dx - p3.dx + 0.0001);
    final b2 = (p3.dx * p4.dy - p4.dx * p3.dy) / (p3.dx - p4.dx + 0.0001);
    final x = (b2 - b1) / (a1 - a2 + 0.0001);
    final y = a1 * x + b1;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant SimulationBackPagePainter oldDelegate) {
    return touchPoint != oldDelegate.touchPoint ||
        cornerX != oldDelegate.cornerX ||
        cornerY != oldDelegate.cornerY;
  }
}

/// 贝塞尔曲线控制点集合
class BezierPoints {
  final Offset touch;
  final Offset control1;
  final Offset control2;
  final Offset start1;
  final Offset start2;
  final Offset end1;
  final Offset end2;
  final Offset vertex1;
  final Offset vertex2;

  BezierPoints({
    required this.touch,
    required this.control1,
    required this.control2,
    required this.start1,
    required this.start2,
    required this.end1,
    required this.end2,
    required this.vertex1,
    required this.vertex2,
  });
}
