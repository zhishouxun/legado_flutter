/// 字典查询对话框
/// 参考项目：DictDialog.kt
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../data/models/dict_rule.dart';
import '../../../services/dict_rule_service.dart';
import '../../../utils/app_log.dart';
import '../../widgets/base/base_bottom_sheet_consumer.dart';
import '../../widgets/common/custom_tab_bar.dart';

/// 字典规则列表Provider
final enabledDictRulesProvider = FutureProvider<List<DictRule>>((ref) async {
  return await DictRuleService.instance.getEnabledRules();
});

/// 字典查询对话框
/// 参考项目：DictDialog.kt
class DictDialog extends BaseBottomSheetConsumer {
  final String word;

  const DictDialog({
    super.key,
    required this.word,
  }) : super(
          title: word,
          heightFactor: 0.8,
        );

  @override
  ConsumerState<DictDialog> createState() => _DictDialogState();
}

class _DictDialogState extends BaseBottomSheetConsumerState<DictDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DictRule> _rules = [];
  int _currentTabIndex = 0;
  String _currentResult = '';
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    final rulesAsync = ref.watch(enabledDictRulesProvider);

    return rulesAsync.when(
      data: (rules) {
        if (rules.isEmpty) {
          return Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.translate_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '没有启用的字典规则',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        // 更新TabController长度
        if (_tabController.length != rules.length) {
          _tabController.removeListener(_onTabChanged);
          _tabController.dispose();
          _currentTabIndex = _currentTabIndex.clamp(0, rules.length - 1);
          _tabController = TabController(
            length: rules.length,
            vsync: this,
            initialIndex: _currentTabIndex,
          );
          _tabController.addListener(_onTabChanged);
          _rules = rules;
          // 加载第一个字典的结果
          if (rules.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadDictResult(rules[_currentTabIndex]);
            });
          }
        } else if (_rules.length != rules.length) {
          // 规则列表更新了，但长度相同，更新规则列表
          _rules = rules;
        }

        return Column(
          children: [
            // Tab栏
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: CustomTabBar(
                controller: _tabController,
                isScrollable: rules.length > 4,
                tabs: rules.map((rule) => Tab(text: rule.name)).toList(),
              ),
            ),
            // 内容区域
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: _buildContent(),
            ),
          ],
        );
      },
      loading: () => const Expanded(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                '加载字典规则失败: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_currentResult.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            '请选择一个字典规则',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(
        data: _currentResult,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(16),
            lineHeight: const LineHeight(1.6),
          ),
        },
      ),
    );
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
        if (_currentTabIndex < _rules.length) {
          _loadDictResult(_rules[_currentTabIndex]);
        }
      });
    }
  }

  Future<void> _loadDictResult(DictRule rule) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentResult = '';
    });

    try {
      final result = await rule.search(widget.word);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentResult = result;
        });
      }
    } catch (e) {
      AppLog.instance.put('DictDialog: 查询失败: $e', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '查询失败: $e';
        });
      }
    }
  }
}
