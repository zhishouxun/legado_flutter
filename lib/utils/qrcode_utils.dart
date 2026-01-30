import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_log.dart';

/// 二维码工具类
/// 参考项目：QRCodeUtils.kt
class QRCodeUtils {
  static const int defaultReqWidth = 480;
  static const int defaultReqHeight = 640;

  /// 生成二维码
  /// 参考项目：QRCodeUtils.createQRCode
  static Future<ui.Image?> createQRCode(
    String content, {
    int size = defaultReqHeight,
    int errorCorrectLevel = QrErrorCorrectLevel.H,
  }) async {
    try {
      if (content.isEmpty) return null;

      // 使用 qr_flutter 包生成二维码
      final painter = QrPainter(
        data: content,
        version: QrVersions.auto,
        errorCorrectionLevel: errorCorrectLevel,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      // 将二维码绘制到图片
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final qrSize = Size(size.toDouble(), size.toDouble());
      painter.paint(canvas, qrSize);
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      return image;
    } catch (e) {
      AppLog.instance.put('QRCodeUtils.createQRCode error: $e');
    }
    return null;
  }

  /// 解析二维码
  /// 参考项目：QRCodeUtils.parseQRCode
  /// 使用平台通道调用原生ZXing库进行解析
  static Future<String?> parseQRCode(Uint8List imageBytes) async {
    try {
      if (imageBytes.isEmpty) {
        AppLog.instance.put('QRCodeUtils.parseQRCode: 图片字节为空');
        return null;
      }

      // 使用平台通道调用原生ZXing库
      if (Platform.isAndroid) {
        const platform = MethodChannel('io.legado.app/qrcode');
        try {
          final result = await platform.invokeMethod<String>(
            'parseQRCodeFromBytes',
            {'imageBytes': imageBytes},
          );
          return result;
        } on PlatformException catch (e) {
          // 如果解析失败（未检测到二维码），返回null而不是抛出异常
          if (e.code == 'ERROR' && e.message?.contains('未检测到二维码') == true) {
            AppLog.instance.put('QRCodeUtils.parseQRCode: 未检测到二维码');
            return null;
          }
          AppLog.instance
              .put('QRCodeUtils.parseQRCode platform error: ${e.message}');
          return null;
        } catch (e) {
          AppLog.instance.put('QRCodeUtils.parseQRCode error: $e');
          return null;
        }
      } else if (Platform.isIOS) {
        // iOS平台暂未实现，可以后续添加
        AppLog.instance.put('QRCodeUtils.parseQRCode: iOS平台暂未实现');
        return null;
      } else {
        AppLog.instance.put('QRCodeUtils.parseQRCode: 不支持的平台');
        return null;
      }
    } catch (e) {
      AppLog.instance.put('QRCodeUtils.parseQRCode error: $e');
      return null;
    }
  }

  /// 从文件路径解析二维码
  /// 参考项目：QRCodeUtils.parseQRCode(String)
  static Future<String?> parseQRCodeFromPath(String imagePath) async {
    try {
      if (Platform.isAndroid) {
        // 直接使用平台通道，避免读取大文件到内存
        const platform = MethodChannel('io.legado.app/qrcode');
        try {
          final result = await platform.invokeMethod<String>(
            'parseQRCodeFromPath',
            {'imagePath': imagePath},
          );
          return result;
        } on PlatformException catch (e) {
          // 如果解析失败（未检测到二维码），返回null而不是抛出异常
          if (e.code == 'ERROR' && e.message?.contains('未检测到二维码') == true) {
            AppLog.instance.put('QRCodeUtils.parseQRCodeFromPath: 未检测到二维码');
            return null;
          }
          AppLog.instance.put(
              'QRCodeUtils.parseQRCodeFromPath platform error: ${e.message}');
          return null;
        } catch (e) {
          AppLog.instance.put('QRCodeUtils.parseQRCodeFromPath error: $e');
          return null;
        }
      } else {
        // 其他平台使用字节方式
        final file = await File(imagePath).readAsBytes();
        return await parseQRCode(file);
      }
    } catch (e) {
      AppLog.instance.put('QRCodeUtils.parseQRCodeFromPath error: $e');
      return null;
    }
  }
}
