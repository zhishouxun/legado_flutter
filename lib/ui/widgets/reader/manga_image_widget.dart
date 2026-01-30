import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/manga_color_filter_config.dart';
import '../../../config/app_config.dart';

/// 漫画图片组件（支持颜色滤镜、电子墨水、灰度效果）
class MangaImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const MangaImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // 获取配置
    final colorFilterConfig = MangaColorFilterConfig.fromJsonString(
      AppConfig.getMangaColorFilter(),
    );
    final enableEInk = AppConfig.getEnableMangaEInk();
    final enableGray = AppConfig.getEnableMangaGray();

    // 构建颜色滤镜
    ColorFilter? colorFilter;

    // 如果启用电子墨水，应用电子墨水效果
    if (enableEInk) {
      // 电子墨水效果：先灰度化，然后二值化
      // 这里使用ColorFilter实现灰度化，二值化需要更复杂的处理
      // 简化实现：使用高对比度灰度
      final matrix = <double>[
        0.299, 0.587, 0.114, 0, 0, // R通道
        0.299, 0.587, 0.114, 0, 0, // G通道
        0.299, 0.587, 0.114, 0, 0, // B通道
        0, 0, 0, 1, 0, // Alpha通道
      ];
      colorFilter = ColorFilter.matrix(matrix);
    } else if (enableGray) {
      // 灰度效果
      final matrix = <double>[
        0.299, 0.587, 0.114, 0, 0, // R通道
        0.299, 0.587, 0.114, 0, 0, // G通道
        0.299, 0.587, 0.114, 0, 0, // B通道
        0, 0, 0, 1, 0, // Alpha通道
      ];
      colorFilter = ColorFilter.matrix(matrix);
    } else if (!colorFilterConfig.isEmpty) {
      // 颜色滤镜
      final r = colorFilterConfig.r / 100.0;
      final g = colorFilterConfig.g / 100.0;
      final b = colorFilterConfig.b / 100.0;
      final a = colorFilterConfig.a / 100.0;
      final l = 1.0 + (colorFilterConfig.l / 100.0);

      final matrix = <double>[
        l, 0, 0, 0, r, // R通道
        0, l, 0, 0, g, // G通道
        0, 0, l, 0, b, // B通道
        0, 0, 0, 1, a, // Alpha通道
      ];
      colorFilter = ColorFilter.matrix(matrix);
    }

    return ColorFiltered(
      colorFilter: colorFilter ?? const ColorFilter.mode(Colors.transparent, BlendMode.dst),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                '加载失败',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

