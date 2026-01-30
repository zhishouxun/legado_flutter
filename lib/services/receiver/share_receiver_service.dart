import '../../core/base/base_service.dart';
import '../../utils/app_log.dart';
import '../qrcode_result_handler.dart';
import '../../config/app_config.dart';

/// 分享接收服务
/// 参考项目：io.legado.app.receiver.SharedReceiverActivity
class ShareReceiverService extends BaseService {
  static final ShareReceiverService instance = ShareReceiverService._init();
  ShareReceiverService._init();

  /// 处理分享的文本
  /// 参考项目：SharedReceiverActivity.dispose()
  /// 
  /// [text] 分享的文本内容
  Future<void> handleSharedText(String text) async {
    try {
      if (text.trim().isEmpty) {
        AppLog.instance.put('分享文本为空');
        return;
      }

      // 提取URL（参考项目逻辑）
      final urls = text.split(RegExp(r'\s+')).where((url) => url.trim().isNotEmpty).toList();
      final urlList = <String>[];
      
      for (final url in urls) {
        final trimmedUrl = url.trim();
        // 检查是否是URL（以http开头）
        if (RegExp(r'^http.+', caseSensitive: false).hasMatch(trimmedUrl)) {
          urlList.add(trimmedUrl);
        }
      }

      // 如果有URL，使用URL Scheme导入
      if (urlList.isNotEmpty) {
        final urlText = urlList.join('\n');
        AppLog.instance.put('检测到URL，使用导入功能: $urlText');
        
        // 使用二维码结果处理器处理（支持自动识别类型）
        for (final url in urlList) {
          await QrcodeResultHandler.instance.handleResult(url);
        }
        
        // 导航到主页面（通过配置）
        await AppConfig.setString('pending_navigation', 'bookshelf');
      } else {
        // 如果没有URL，使用搜索功能
        AppLog.instance.put('使用搜索功能: $text');
        
        // 导航到搜索页面（通过配置）
        await AppConfig.setString('pending_navigation', 'search');
        await AppConfig.setString('pending_search_text', text);
      }
    } catch (e) {
      AppLog.instance.put('处理分享文本失败: $e', error: e);
    }
  }

  /// 处理文本选择
  /// 参考项目：SharedReceiverActivity.dispose() (ACTION_PROCESS_TEXT)
  /// 
  /// [text] 选择的文本内容
  Future<void> handleProcessText(String text) async {
    try {
      if (text.trim().isEmpty) {
        AppLog.instance.put('选择文本为空');
        return;
      }

      // 文本选择通常用于搜索
      AppLog.instance.put('处理文本选择: $text');
      
      // 导航到搜索页面
      await AppConfig.setString('pending_navigation', 'search');
      await AppConfig.setString('pending_search_text', text);
    } catch (e) {
      AppLog.instance.put('处理文本选择失败: $e', error: e);
    }
  }

  /// 处理朗读动作
  /// 参考项目：SharedReceiverActivity.initIntent() (action == "readAloud")
  Future<void> handleReadAloud() async {
    try {
      AppLog.instance.put('通过分享启动朗读');
      
      // 导航到朗读功能
      await AppConfig.setString('pending_navigation', 'readAloud');
    } catch (e) {
      AppLog.instance.put('启动朗读失败: $e', error: e);
    }
  }
}

