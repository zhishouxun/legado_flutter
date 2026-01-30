import 'package:shared_preferences/shared_preferences.dart';
import '../../core/base/base_service.dart';
import '../../utils/app_log.dart';

/// 书源配置服务
/// 参考项目：io.legado.app.help.config.SourceConfig
///
/// 管理书源和书籍的评分功能
class SourceConfigService extends BaseService {
  static final SourceConfigService instance = SourceConfigService._init();
  SharedPreferences? _prefs;

  SourceConfigService._init();

  @override
  Future<void> onInit() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取 SharedPreferences 实例
  /// 如果未初始化，则初始化
  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  /// 设置书籍评分
  /// 参考项目：SourceConfig.setBookScore()
  ///
  /// [origin] 书源URL
  /// [name] 书籍名称
  /// [author] 作者名称
  /// [score] 评分值
  Future<void> setBookScore(
      String origin, String name, String author, int score) async {
    return await execute(
      action: () async {
        final prefs = await _getPrefs();

        // 获取之前的评分
        final preScore = getBookScore(origin, name, author);

        // 计算新的评分增量
        var newScore = score;
        if (preScore != 0) {
          newScore = score - preScore;
        }

        // 更新书源总评分
        final sourceScore = getSourceScore(origin);
        await prefs.setInt(origin, sourceScore + newScore);

        // 保存书籍评分
        final bookKey = '${origin}_${name}_$author';
        await prefs.setInt(bookKey, score);
      },
      operationName: '设置书籍评分',
      logError: true,
    );
  }

  /// 获取书籍评分
  /// 参考项目：SourceConfig.getBookScore()
  ///
  /// [origin] 书源URL
  /// [name] 书籍名称
  /// [author] 作者名称
  /// 返回评分值，如果不存在则返回 0
  int getBookScore(String origin, String name, String author) {
    try {
      if (_prefs == null) {
        // 同步初始化（不推荐，但为了兼容性）
        return 0;
      }

      final bookKey = '${origin}_${name}_$author';
      return _prefs!.getInt(bookKey) ?? 0;
    } catch (e) {
      AppLog.instance.put('获取书籍评分失败', error: e);
      return 0;
    }
  }

  /// 获取书源评分
  /// 参考项目：SourceConfig.getSourceScore()
  ///
  /// [origin] 书源URL
  /// 返回书源总评分，如果不存在则返回 0
  int getSourceScore(String origin) {
    try {
      if (_prefs == null) {
        AppLog.instance.put('SourceConfigService 未初始化');
        return 0;
      }

      return _prefs!.getInt(origin) ?? 0;
    } catch (e) {
      AppLog.instance.put('获取书源评分失败', error: e);
      return 0;
    }
  }

  /// 删除书源配置
  /// 参考项目：SourceConfig.removeSource()
  ///
  /// [origin] 书源URL
  /// 删除该书源的所有相关配置（包括所有书籍评分）
  Future<void> removeSource(String origin) async {
    return await execute(
      action: () async {
        final prefs = await _getPrefs();

        // 获取所有以 origin 开头的键
        final allKeys = prefs.getKeys();
        final keysToRemove =
            allKeys.where((key) => key.startsWith(origin)).toList();

        // 删除所有相关键
        for (final key in keysToRemove) {
          await prefs.remove(key);
        }
      },
      operationName: '删除书源配置',
      logError: true,
    );
  }

  /// 获取所有书源评分
  /// 返回所有书源的评分映射
  Map<String, int> getAllSourceScores() {
    try {
      if (_prefs == null) {
        AppLog.instance.put('SourceConfigService 未初始化');
        return {};
      }

      final allKeys = _prefs!.getKeys();
      final scores = <String, int>{};

      for (final key in allKeys) {
        // 排除书籍评分键（包含下划线的键）
        if (!key.contains('_')) {
          final score = _prefs!.getInt(key);
          if (score != null) {
            scores[key] = score;
          }
        }
      }

      return scores;
    } catch (e) {
      AppLog.instance.put('获取所有书源评分失败', error: e);
      return {};
    }
  }

  /// 清除所有评分
  /// 清除所有书源和书籍的评分
  Future<void> clearAllScores() async {
    return await execute(
      action: () async {
        final prefs = await _getPrefs();

        // 获取所有键
        final allKeys = prefs.getKeys().toList();

        // 删除所有键
        for (final key in allKeys) {
          await prefs.remove(key);
        }
      },
      operationName: '清除所有评分',
      logError: true,
    );
  }
}
