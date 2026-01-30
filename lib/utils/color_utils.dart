import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 颜色工具类
/// 参考项目：ColorUtils.kt
class ColorUtils {
  /// 判断颜色是否为浅色
  /// 参考项目：ColorUtils.isColorLight
  static bool isColorLight(Color color) {
    return _calculateLuminance(color) >= 0.5;
  }

  /// 计算颜色亮度
  static double _calculateLuminance(Color color) {
    // 使用相对亮度公式：Y = 0.2126*R + 0.7152*G + 0.0722*B
    final r = _linearizeComponent(color.red / 255.0);
    final g = _linearizeComponent(color.green / 255.0);
    final b = _linearizeComponent(color.blue / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 线性化颜色分量
  static double _linearizeComponent(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    } else {
      return math.pow((component + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  /// 颜色整数转字符串
  /// 参考项目：ColorUtils.intToString
  static String intToString(int intColor) {
    // 移除alpha通道，只保留RGB
    final rgb = intColor & 0xFFFFFF;
    return '#${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }

  /// 移除透明度
  /// 参考项目：ColorUtils.stripAlpha
  static int stripAlpha(int color) {
    return 0xFF000000 | color;
  }

  /// 调整颜色亮度
  /// 参考项目：ColorUtils.shiftColor
  static Color shiftColor(Color color, double by) {
    if (by == 1.0) return color;
    
    final hsv = HSVColor.fromColor(color);
    final newValue = (hsv.value * by).clamp(0.0, 1.0);
    final newHsv = hsv.withValue(newValue);
    return newHsv.toColor();
  }

  /// 变暗颜色
  /// 参考项目：ColorUtils.darkenColor
  static Color darkenColor(Color color) {
    return shiftColor(color, 0.9);
  }

  /// 变亮颜色
  /// 参考项目：ColorUtils.lightenColor
  static Color lightenColor(Color color) {
    return shiftColor(color, 1.1);
  }

  /// 反色
  /// 参考项目：ColorUtils.invertColor
  static Color invertColor(Color color) {
    return Color.fromARGB(
      color.alpha,
      255 - color.red,
      255 - color.green,
      255 - color.blue,
    );
  }

  /// 调整透明度
  /// 参考项目：ColorUtils.adjustAlpha
  static Color adjustAlpha(Color color, double factor) {
    final alpha = (color.alpha * factor).round().clamp(0, 255);
    return color.withAlpha(alpha);
  }

  /// 设置透明度
  /// 参考项目：ColorUtils.withAlpha
  static Color withAlpha(Color baseColor, double alpha) {
    final a = (alpha * 255).round().clamp(0, 255);
    return baseColor.withAlpha(a);
  }

  /// 混合两种颜色
  /// 参考项目：ColorUtils.blendColors
  static Color blendColors(Color color1, Color color2, double ratio) {
    final inverseRatio = 1.0 - ratio;
    final a = (color1.alpha * inverseRatio + color2.alpha * ratio).round();
    final r = (color1.red * inverseRatio + color2.red * ratio).round();
    final g = (color1.green * inverseRatio + color2.green * ratio).round();
    final b = (color1.blue * inverseRatio + color2.blue * ratio).round();
    return Color.fromARGB(a, r, g, b);
  }

  /// 创建ARGB颜色
  /// 参考项目：ColorUtils.argb
  static Color argb(int alpha, int r, int g, int b) {
    return Color.fromARGB(alpha, r, g, b);
  }

  /// 创建RGB颜色（无透明度）
  static Color rgb(int r, int g, int b) {
    return Color.fromRGBO(r, g, b, 1.0);
  }

  /// 从整数获取RGB数组
  /// 参考项目：ColorUtils.rgb
  static List<int> getRgb(int argb) {
    return [
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
    ];
  }

  /// 计算颜色差异（CIE76算法）
  /// 参考项目：ColorUtils.getColorDifference
  static double getColorDifference(Color a, Color b) {
    final lab1 = _colorToLAB(a);
    final lab2 = _colorToLAB(b);
    final deltaL = lab2[0] - lab1[0];
    final deltaA = lab2[1] - lab1[1];
    final deltaB = lab2[2] - lab1[2];
    return math.sqrt(deltaL * deltaL + deltaA * deltaA + deltaB * deltaB);
  }

  /// 将颜色转换为LAB颜色空间
  static List<double> _colorToLAB(Color color) {
    // 转换为XYZ颜色空间
    final xyz = _colorToXYZ(color);
    // 转换为LAB颜色空间
    return _xyzToLAB(xyz);
  }

  /// 将颜色转换为XYZ颜色空间
  static List<double> _colorToXYZ(Color color) {
    double r = color.red / 255.0;
    double g = color.green / 255.0;
    double b = color.blue / 255.0;

    // 线性化
    r = r > 0.04045 ? math.pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
    g = g > 0.04045 ? math.pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
    b = b > 0.04045 ? math.pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;

    // 转换为XYZ
    final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) * 100.0;
    final y = (r * 0.2126 + g * 0.7152 + b * 0.0722) * 100.0;
    final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) * 100.0;

    return [x, y, z];
  }

  /// 将XYZ转换为LAB颜色空间
  static List<double> _xyzToLAB(List<double> xyz) {
    final x = xyz[0] / 95.047;
    final y = xyz[1] / 100.0;
    final z = xyz[2] / 108.883;

    final fx = x > 0.008856 ? math.pow(x, 1.0 / 3.0).toDouble() : (7.787 * x + 16.0 / 116.0);
    final fy = y > 0.008856 ? math.pow(y, 1.0 / 3.0).toDouble() : (7.787 * y + 16.0 / 116.0);
    final fz = z > 0.008856 ? math.pow(z, 1.0 / 3.0).toDouble() : (7.787 * z + 16.0 / 116.0);

    final l = 116.0 * fy - 16.0;
    final a = 500.0 * (fx - fy);
    final b = 200.0 * (fy - fz);

    return [l, a, b];
  }
}

