import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:typed_data';

/// 漫画图片效果处理工具类
/// 参考项目：EpaperTransformation.kt, GrayscaleTransformation.kt
class MangaImageFilters {
  /// 应用颜色滤镜
  /// 参考项目：MangaColorFilterConfig
  /// [r] 红色偏移 (-100 到 100)
  /// [g] 绿色偏移 (-100 到 100)
  /// [b] 蓝色偏移 (-100 到 100)
  /// [a] 透明度偏移 (-100 到 100)
  /// [l] 亮度偏移 (-100 到 100)
  static Future<ui.Image> applyColorFilter(
    ui.Image image, {
    int r = 0,
    int g = 0,
    int b = 0,
    int a = 0,
    int l = 0,
  }) async {
    if (r == 0 && g == 0 && b == 0 && a == 0 && l == 0) {
      return image;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // 创建颜色矩阵
    // 颜色矩阵格式：[R, G, B, A, 偏移]
    // 每行代表一个颜色通道
    final matrix = List<double>.filled(20, 0.0);
    
    // 红色通道
    matrix[0] = 1.0; // R -> R
    matrix[4] = r / 100.0; // R偏移
    
    // 绿色通道
    matrix[6] = 1.0; // G -> G
    matrix[9] = g / 100.0; // G偏移
    
    // 蓝色通道
    matrix[12] = 1.0; // B -> B
    matrix[14] = b / 100.0; // B偏移
    
    // Alpha通道
    matrix[18] = 1.0; // A -> A
    matrix[19] = a / 100.0; // A偏移
    
    // 亮度调整（影响所有通道）
    final brightness = 1.0 + (l / 100.0);
    matrix[0] *= brightness; // R
    matrix[6] *= brightness; // G
    matrix[12] *= brightness; // B

    final colorFilter = ColorFilter.matrix(matrix);
    paint.colorFilter = colorFilter;

    canvas.drawImage(image, Offset.zero, paint);

    final picture = recorder.endRecording();
    return await picture.toImage(image.width, image.height);
  }

  /// 应用电子墨水效果
  /// 参考项目：EpaperTransformation.kt
  /// [threshold] 二值化阈值 (0-255)
  static Future<ui.Image> applyEpaperEffect(
    ui.Image image, {
    int threshold = 150,
  }) async {
    // 先转换为灰度
    final grayscaleImage = await applyGrayscale(image);
    
    // 读取像素数据
    final byteData = await grayscaleImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return image;

    final pixels = byteData.buffer.asUint8List();
    final width = grayscaleImage.width;
    final height = grayscaleImage.height;

    // 二值化处理
    for (int i = 0; i < pixels.length; i += 4) {
      // 获取灰度值（R、G、B应该相同）
      final gray = pixels[i];
      
      // 二值化：低于阈值变黑，高于阈值变白
      final value = gray < threshold ? 0 : 255;
      pixels[i] = value; // R
      pixels[i + 1] = value; // G
      pixels[i + 2] = value; // B
      // Alpha保持不变
    }

    // 创建新的图片
    final codec = await ui.instantiateImageCodec(
      Uint8List.view(pixels.buffer),
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// 应用灰度效果
  /// 参考项目：GrayscaleTransformation.kt
  static Future<ui.Image> applyGrayscale(ui.Image image) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // 使用标准灰度转换矩阵
    // 公式：Gray = 0.299*R + 0.587*G + 0.114*B
    final matrix = [
      0.299, 0.587, 0.114, 0, 0, // R通道
      0.299, 0.587, 0.114, 0, 0, // G通道
      0.299, 0.587, 0.114, 0, 0, // B通道
      0, 0, 0, 1, 0, // Alpha通道
    ];

    final colorFilter = ColorFilter.matrix(matrix);
    paint.colorFilter = colorFilter;

    canvas.drawImage(image, Offset.zero, paint);

    final picture = recorder.endRecording();
    return await picture.toImage(image.width, image.height);
  }
}

