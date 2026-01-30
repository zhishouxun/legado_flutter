import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../data/models/book.dart';
import '../../../services/book/book_service.dart';
import '../../../services/read_config_service.dart';
import '../../../config/app_config.dart';
import '../../../core/constants/app_status.dart';
import 'custom_color_dialog.dart';
import 'font_select_dialog.dart';
import '../../widgets/common/custom_switch.dart';

/// 阅读设置页面（底部弹出式）
class ReaderSettingsPage extends ConsumerStatefulWidget {
  final Book book;
  final ValueChanged<ReadConfig>? onConfigChanged; // 配置改变时的回调

  const ReaderSettingsPage({
    super.key,
    required this.book,
    this.onConfigChanged,
  });

  @override
  ConsumerState<ReaderSettingsPage> createState() => _ReaderSettingsPageState();
}

class _ReaderSettingsPageState extends ConsumerState<ReaderSettingsPage> {
  late ReadConfig _config;
  late ReadConfig _sharedLayoutConfig; // 共用布局配置
  late bool _sharedLayout; // 共用布局开关
  int _selectedTab = 0; // 0: 中/粗/细, 1: 字体, 2: 缩进, 3: 简/繁, 4: 边距, 5: 信息

  @override
  void initState() {
    super.initState();
    _sharedLayout = AppConfig.getSharedLayout();
    _loadConfig();
  }

  /// 加载配置（根据共用布局设置）
  void _loadConfig() {
    final bookConfig = widget.book.readConfig ?? ReadConfig();

    if (_sharedLayout) {
      // 启用共用布局：从全局配置加载布局设置
      final sharedConfigJson = AppConfig.getSharedReadConfig();
      if (sharedConfigJson != null && sharedConfigJson.isNotEmpty) {
        try {
          final sharedConfigMap =
              jsonDecode(sharedConfigJson) as Map<String, dynamic>;
          _sharedLayoutConfig = ReadConfig.fromJson(sharedConfigMap);
        } catch (e) {
          _sharedLayoutConfig = bookConfig.getLayoutConfig();
        }
      } else {
        // 如果没有共用配置，使用当前书籍的布局配置
        _sharedLayoutConfig = bookConfig.getLayoutConfig();
      }
      // 应用共用布局配置，但保留书籍的颜色配置
      _config = bookConfig.applyLayoutConfig(_sharedLayoutConfig);
    } else {
      // 关闭共用布局：使用书籍自己的配置
      _config = bookConfig;
      _sharedLayoutConfig = bookConfig.getLayoutConfig();
    }
  }

  @override
  void dispose() {
    // 不再在关闭时保存，所有修改都在调整时立即应用
    super.dispose();
  }

  /// 静默保存配置（不关闭页面，异步执行）
  void _saveConfigSilently() {
    if (_sharedLayout) {
      // 启用共用布局：保存到全局配置
      final layoutConfig = _config.getLayoutConfig();
      final layoutConfigJson = jsonEncode(layoutConfig.toJson());
      AppConfig.setSharedReadConfig(layoutConfigJson);
      // 同时更新所有书籍的布局配置
      _updateAllBooksLayout(layoutConfig);
    } else {
      // 关闭共用布局：只保存当前书籍的配置
      final updatedBook = widget.book.copyWith(readConfig: _config);
      BookService.instance.saveBook(updatedBook).catchError((error) {});
    }

    // 通知父组件配置已改变
    if (widget.onConfigChanged != null) {
      widget.onConfigChanged!(_config);
    }
  }

  /// 更新所有书籍的布局配置（共用布局时）
  Future<void> _updateAllBooksLayout(ReadConfig layoutConfig) async {
    try {
      final allBooks = await BookService.instance.getBookshelfBooks();
      for (final book in allBooks) {
        final currentConfig = book.readConfig ?? ReadConfig();
        final updatedConfig = currentConfig.applyLayoutConfig(layoutConfig);
        final updatedBook = book.copyWith(readConfig: updatedConfig);
        await BookService.instance.saveBook(updatedBook);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.60, // 设置为50%高度
        decoration: BoxDecoration(
          // 渐变背景
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a1a),
              Color(0xFF2a2a2a),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 顶部关闭按钮
            _buildCloseButton(),
            // 顶部标签栏
            _buildTabBar(),
            Divider(height: 1, color: Colors.white.withOpacity(0.1)),
            // 内容区域
            Expanded(
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建顶部关闭按钮
  Widget _buildCloseButton() {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        children: [
          // 拖动指示器
          Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48),
              const Text(
                '阅读设置',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white.withOpacity(0.9)),
                iconSize: 24,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建顶部标签栏
  Widget _buildTabBar() {
    final tabs = ['中/粗/细', '字体', '缩进', '简/繁', '边距', '信息'];

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTab == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF8E53),
                        ],
                      )
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建标签内容
  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildFontWeightTab();
      case 1:
        return _buildFontTab();
      case 2:
        return _buildIndentTab();
      case 3:
        return _buildSimplifiedTraditionalTab();
      case 4:
        return _buildMarginTab();
      case 5:
        return _buildInfoTab();
      default:
        return _buildFontWeightTab();
    }
  }

  /// 中/粗/细标签页
  Widget _buildFontWeightTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 让Column适应内容，消除底部空白
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 字号
            _buildSliderWithButtons(
              label: '字号',
              value: _config.fontSize,
              min: 12,
              max: 36,
              step: 1,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(fontSize: value);
                });
              },
              onChangeEnd: (value) {
                // 拖动结束后保存并应用
                _saveConfigSilently();
              },
            ),
            const SizedBox(height: 4), // 滑杆之间的间距

            // 字距
            _buildSliderWithButtons(
              label: '字距',
              value: _config.letterSpacing,
              min: -0.1,
              max: 0.1,
              step: 0.01,
              formatValue: (value) => value.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(letterSpacing: value);
                });
              },
              onChangeEnd: (value) {
                // 拖动结束后保存并应用
                _saveConfigSilently();
              },
            ),
            const SizedBox(height: 4), // 滑杆之间的间距

            // 行距
            _buildSliderWithButtons(
              label: '行距',
              value: _config.lineHeight - 1.0, // 转换为相对值
              min: -0.5,
              max: 2.0,
              step: 0.1,
              formatValue: (value) => value.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(lineHeight: value + 1.0);
                });
              },
              onChangeEnd: (value) {
                // 拖动结束后保存并应用
                _saveConfigSilently();
              },
            ),
            const SizedBox(height: 4), // 滑杆之间的间距

            // 段距
            _buildSliderWithButtons(
              label: '段距',
              value: _config.paragraphSpacing,
              min: 0.0,
              max: 2.0,
              step: 0.1,
              formatValue: (value) => value.toStringAsFixed(1),
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(paragraphSpacing: value);
                });
              },
              onChangeEnd: (value) {
                // 拖动结束后保存并应用
                _saveConfigSilently();
              },
            ),
            const SizedBox(height: 12), // 段距与字体粗细之间的间距

            // 字体粗细选择
            _buildSectionTitle('字体粗细'),
            Row(
              mainAxisAlignment: MainAxisAlignment.start, // 改为居左对齐
              children: [
                _buildFontWeightOption('细', 0),
                const SizedBox(width: 8), // 添加按钮之间的间距
                _buildFontWeightOption('中', 1),
                const SizedBox(width: 8), // 添加按钮之间的间距
                _buildFontWeightOption('粗', 2),
              ],
            ),
            const SizedBox(height: 16), // 24 * 2/3 = 16

            // 翻页动画
            _buildSectionTitle('翻页动画'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAnimationOption('覆盖', AppStatus.pageAnimCover),
                _buildAnimationOption('滑动', AppStatus.pageAnimSlide),
                _buildAnimationOption('仿真', AppStatus.pageAnimSimulation),
                _buildAnimationOption('滚动', AppStatus.pageAnimScroll),
                _buildAnimationOption('无动画', AppStatus.pageAnimNone),
              ],
            ),
            const SizedBox(height: 16), // 24 * 2/3 = 16

            // 文字颜色和背景预设
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行：文字颜色和背景标题 + 共用布局
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '文字颜色和背景 (长按自定义)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // 共用布局（放在最右边，与标题同一行）
                    Row(
                      children: [
                        const Text(
                          '共用布局',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final newValue = !_sharedLayout;
                            setState(() {
                              _sharedLayout = newValue;
                            });
                            // 保存共用布局开关状态
                            await AppConfig.setSharedLayout(newValue);

                            if (newValue) {
                              // 启用共用布局：将当前配置保存为共用配置
                              final layoutConfig = _config.getLayoutConfig();
                              final layoutConfigJson =
                                  jsonEncode(layoutConfig.toJson());
                              await AppConfig.setSharedReadConfig(
                                  layoutConfigJson);
                              // 更新所有书籍的布局配置
                              _updateAllBooksLayout(layoutConfig);
                            } else {
                              // 关闭共用布局：只保存当前书籍的配置
                              final updatedBook =
                                  widget.book.copyWith(readConfig: _config);
                              await BookService.instance.saveBook(updatedBook);
                            }
                            // 重新加载配置以应用更改
                            _loadConfig();
                            setState(() {});
                          },
                          child: Container(
                            width: 40,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _sharedLayout
                                  ? Colors.orange
                                  : Colors.grey.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  left: _sharedLayout ? 20 : 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 颜色预设
                _buildColorPresets(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 字体标签页
  Widget _buildFontTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 让Column适应内容，消除底部空白
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('字体选择'),
            _buildFontFamilyList(),
          ],
        ),
      ),
    );
  }

  /// 缩进标签页
  Widget _buildIndentTab() {
    final indentOptions = [
      {'label': '无缩进', 'value': ''},
      {'label': '一字符缩进', 'value': '　'},
      {'label': '二字符缩进', 'value': '　　'},
      {'label': '三字符缩进', 'value': '　　　'},
      {'label': '四字符缩进', 'value': '　　　　'},
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 让Column适应内容，消除底部空白
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('缩进'),
            ...indentOptions.map((option) {
              final isSelected = _config.paragraphIndent == option['value'];
              return ListTile(
                title: Text(
                  option['label']!,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.red)
                    : null,
                onTap: () {
                  setState(() {
                    _config =
                        _config.copyWith(paragraphIndent: option['value']!);
                  });
                  // 立即保存并应用
                  _saveConfigSilently();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 简/繁标签页
  Widget _buildSimplifiedTraditionalTab() {
    final converterType = AppConfig.getChineseConverterType();
    const options = ['关闭', '繁体转简体', '简体转繁体'];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 让Column适应内容，消除底部空白
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('简繁转换'),
            // 简繁转换选项
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '转换模式',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF2C2C2C),
                          title: const Text(
                            '选择转换模式',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: options.asMap().entries.map((entry) {
                              return RadioListTile<int>(
                                title: Text(
                                  entry.value,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                value: entry.key,
                                groupValue: converterType,
                                activeColor: Colors.orange,
                                onChanged: (value) {
                                  if (value != null) {
                                    AppConfig.setChineseConverterType(value);
                                    setState(() {});
                                    // 通知配置改变，需要重新加载内容
                                    if (widget.onConfigChanged != null) {
                                      widget.onConfigChanged!(_config);
                                    }
                                    Navigator.pop(context);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      options[converterType],
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 说明文字
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '• 关闭：不进行转换\n• 繁体转简体：将繁体中文转换为简体中文\n• 简体转繁体：将简体中文转换为繁体中文',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 边距标签页
  Widget _buildMarginTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 让Column适应内容，消除底部空白
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页眉
            _buildPaddingSection(
              title: '页眉',
              showLineToggle: true,
              showLineValue: _config.showHeaderLine,
              onShowLineChanged: (value) {
                setState(() {
                  _config = _config.copyWith(showHeaderLine: value);
                });
                _saveConfigSilently();
              },
              paddingTop: _config.headerPaddingTop,
              paddingBottom: _config.headerPaddingBottom,
              paddingLeft: _config.headerPaddingLeft,
              paddingRight: _config.headerPaddingRight,
              onPaddingChanged: (top, bottom, left, right) {
                setState(() {
                  _config = _config.copyWith(
                    headerPaddingTop: top,
                    headerPaddingBottom: bottom,
                    headerPaddingLeft: left,
                    headerPaddingRight: right,
                  );
                });
              },
              onPaddingChangeEnd: () {
                _saveConfigSilently();
              },
            ),
            const SizedBox(height: 16),

            // 正文
            _buildPaddingSection(
              title: '正文',
              showLineToggle: false,
              paddingTop: _config.paddingTop,
              paddingBottom: _config.paddingBottom,
              paddingLeft: _config.paddingLeft,
              paddingRight: _config.paddingRight,
              onPaddingChanged: (top, bottom, left, right) {
                setState(() {
                  _config = _config.copyWith(
                    paddingTop: top,
                    paddingBottom: bottom,
                    paddingLeft: left,
                    paddingRight: right,
                  );
                });
              },
              onPaddingChangeEnd: () {
                _saveConfigSilently();
              },
            ),
            const SizedBox(height: 16),

            // 页脚
            _buildPaddingSection(
              title: '页脚',
              showLineToggle: true,
              showLineValue: _config.showFooterLine,
              onShowLineChanged: (value) {
                setState(() {
                  _config = _config.copyWith(showFooterLine: value);
                });
                _saveConfigSilently();
              },
              paddingTop: _config.footerPaddingTop,
              paddingBottom: _config.footerPaddingBottom,
              paddingLeft: _config.footerPaddingLeft,
              paddingRight: _config.footerPaddingRight,
              onPaddingChanged: (top, bottom, left, right) {
                setState(() {
                  _config = _config.copyWith(
                    footerPaddingTop: top,
                    footerPaddingBottom: bottom,
                    footerPaddingLeft: left,
                    footerPaddingRight: right,
                  );
                });
              },
              onPaddingChangeEnd: () {
                _saveConfigSilently();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建边距设置区域
  Widget _buildPaddingSection({
    required String title,
    required bool showLineToggle,
    bool showLineValue = false,
    ValueChanged<bool>? onShowLineChanged,
    required double paddingTop,
    required double paddingBottom,
    required double paddingLeft,
    required double paddingRight,
    required Function(double, double, double, double) onPaddingChanged,
    required VoidCallback onPaddingChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和显示分隔线开关
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(title),
            if (showLineToggle)
              Row(
                children: [
                  const Text(
                    '显示分隔线',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  CustomSwitch(
                    value: showLineValue,
                    onChanged: onShowLineChanged ?? (value) {},
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),

        // 上边距
        _buildSliderWithButtons(
          label: '上边距',
          value: paddingTop,
          min: 0,
          max: 100,
          step: 1,
          formatValue: (value) => value.toInt().toString(),
          onChanged: (value) {
            onPaddingChanged(value, paddingBottom, paddingLeft, paddingRight);
          },
          onChangeEnd: (value) {
            onPaddingChangeEnd();
          },
        ),
        const SizedBox(height: 4),

        // 下边距
        _buildSliderWithButtons(
          label: '下边距',
          value: paddingBottom,
          min: 0,
          max: 100,
          step: 1,
          formatValue: (value) => value.toInt().toString(),
          onChanged: (value) {
            onPaddingChanged(paddingTop, value, paddingLeft, paddingRight);
          },
          onChangeEnd: (value) {
            onPaddingChangeEnd();
          },
        ),
        const SizedBox(height: 4),

        // 左边距
        _buildSliderWithButtons(
          label: '左边距',
          value: paddingLeft,
          min: 0,
          max: 100,
          step: 1,
          formatValue: (value) => value.toInt().toString(),
          onChanged: (value) {
            onPaddingChanged(paddingTop, paddingBottom, value, paddingRight);
          },
          onChangeEnd: (value) {
            onPaddingChangeEnd();
          },
        ),
        const SizedBox(height: 4),

        // 右边距
        _buildSliderWithButtons(
          label: '右边距',
          value: paddingRight,
          min: 0,
          max: 100,
          step: 1,
          formatValue: (value) => value.toInt().toString(),
          onChanged: (value) {
            onPaddingChanged(paddingTop, paddingBottom, paddingLeft, value);
          },
          onChangeEnd: (value) {
            onPaddingChangeEnd();
          },
        ),
      ],
    );
  }

  /// 信息标签页
  Widget _buildInfoTab() {
    // 提示信息类型常量（参考 ReadTipConfig）
    const tipTypes = [
      '无',
      '书名',
      '标题',
      '时间',
      '电量',
      '电量%',
      '页数',
      '进度(%)',
      '进度(xx/yyy)',
      '页数及进度',
      '时间+电量',
      '时间+电量%',
    ];

    const tipTypeValues = [0, 7, 1, 2, 3, 10, 4, 5, 11, 6, 8, 9];

    // 页眉显示模式
    const headerModes = ['状态栏显示时隐藏', '显示', '隐藏'];

    // 页脚显示模式
    const footerModes = ['显示', '隐藏'];

    // 文字颜色选项
    const tipColorNames = ['跟随正文', '自定义'];

    // 分隔线颜色选项
    const tipDividerColorNames = ['默认', '跟随内容', '自定义'];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 让Column适应内容，消除底部空白
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 正文标题
            _buildSectionTitle('正文标题'),
            // 对齐选项
            Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    title: const Text('靠左',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    value: 0,
                    groupValue: _config.titleMode,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _config = _config.copyWith(titleMode: value);
                        });
                        _saveConfigSilently();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    title: const Text('居中',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    value: 1,
                    groupValue: _config.titleMode,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _config = _config.copyWith(titleMode: value);
                        });
                        _saveConfigSilently();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    title: const Text('隐藏',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    value: 2,
                    groupValue: _config.titleMode,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _config = _config.copyWith(titleMode: value);
                        });
                        _saveConfigSilently();
                      }
                    },
                  ),
                ),
              ],
            ),
            // 字号滑块
            _buildSliderWithButtons(
              label: '字号',
              value: _config.titleSize.toDouble(),
              min: -10,
              max: 10,
              step: 1,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(titleSize: value.round());
                });
                _saveConfigSilently();
              },
              formatValue: (value) => value.round().toString(),
            ),
            const SizedBox(height: 8),
            // 上边距滑块
            _buildSliderWithButtons(
              label: '上边距',
              value: _config.titleTopSpacing.toDouble(),
              min: 0,
              max: 20,
              step: 1,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(titleTopSpacing: value.round());
                });
                _saveConfigSilently();
              },
              formatValue: (value) => value.round().toString(),
            ),
            const SizedBox(height: 8),
            // 下边距滑块
            _buildSliderWithButtons(
              label: '下边距',
              value: _config.titleBottomSpacing.toDouble(),
              min: 0,
              max: 20,
              step: 1,
              onChanged: (value) {
                setState(() {
                  _config = _config.copyWith(titleBottomSpacing: value.round());
                });
                _saveConfigSilently();
              },
              formatValue: (value) => value.round().toString(),
            ),
            const SizedBox(height: 16),

            // 页眉
            _buildSectionTitle('页眉'),
            // 显示/隐藏
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('显示/隐藏',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF2C2C2C),
                          title: const Text('选择显示模式',
                              style: TextStyle(color: Colors.white)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: headerModes.asMap().entries.map((entry) {
                              return RadioListTile<int>(
                                title: Text(entry.value,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                value: entry.key,
                                groupValue: _config.headerMode,
                                activeColor: Colors.orange,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _config =
                                          _config.copyWith(headerMode: value);
                                    });
                                    _saveConfigSilently();
                                    Navigator.pop(context);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      headerModes[_config.headerMode],
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            // 左、中、右
            _buildTipSelector(
                '左', _config.tipHeaderLeft, tipTypes, tipTypeValues, (value) {
              setState(() {
                _config = _config.copyWith(tipHeaderLeft: value);
              });
              _saveConfigSilently();
            }),
            _buildTipSelector(
                '中', _config.tipHeaderMiddle, tipTypes, tipTypeValues, (value) {
              setState(() {
                _config = _config.copyWith(tipHeaderMiddle: value);
              });
              _saveConfigSilently();
            }),
            _buildTipSelector(
                '右', _config.tipHeaderRight, tipTypes, tipTypeValues, (value) {
              setState(() {
                _config = _config.copyWith(tipHeaderRight: value);
              });
              _saveConfigSilently();
            }),
            const SizedBox(height: 16),

            // 页脚
            _buildSectionTitle('页脚'),
            // 显示/隐藏
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('显示/隐藏',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF2C2C2C),
                          title: const Text('选择显示模式',
                              style: TextStyle(color: Colors.white)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: footerModes.asMap().entries.map((entry) {
                              return RadioListTile<int>(
                                title: Text(entry.value,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                value: entry.key,
                                groupValue: _config.footerMode,
                                activeColor: Colors.orange,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _config =
                                          _config.copyWith(footerMode: value);
                                    });
                                    _saveConfigSilently();
                                    Navigator.pop(context);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      footerModes[_config.footerMode],
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            // 左、中、右
            _buildTipSelector(
                '左', _config.tipFooterLeft, tipTypes, tipTypeValues, (value) {
              setState(() {
                _config = _config.copyWith(tipFooterLeft: value);
              });
              _saveConfigSilently();
            }),
            _buildTipSelector(
                '中', _config.tipFooterMiddle, tipTypes, tipTypeValues, (value) {
              setState(() {
                _config = _config.copyWith(tipFooterMiddle: value);
              });
              _saveConfigSilently();
            }),
            _buildTipSelector(
                '右', _config.tipFooterRight, tipTypes, tipTypeValues, (value) {
              setState(() {
                _config = _config.copyWith(tipFooterRight: value);
              });
              _saveConfigSilently();
            }),
            const SizedBox(height: 16),

            // 页眉&页脚
            _buildSectionTitle('页眉&页脚'),
            // 文字颜色
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('文字颜色',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF2C2C2C),
                          title: const Text('选择文字颜色',
                              style: TextStyle(color: Colors.white)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children:
                                tipColorNames.asMap().entries.map((entry) {
                              return ListTile(
                                title: Text(entry.value,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                trailing: _config.tipColor == 0 &&
                                        entry.key == 0
                                    ? const Icon(Icons.check,
                                        color: Colors.orange)
                                    : _config.tipColor != 0 && entry.key == 1
                                        ? const Icon(Icons.check,
                                            color: Colors.orange)
                                        : null,
                                onTap: () {
                                  if (entry.key == 0) {
                                    setState(() {
                                      _config = _config.copyWith(tipColor: 0);
                                    });
                                    _saveConfigSilently();
                                    Navigator.pop(context);
                                  } else {
                                    Navigator.pop(context); // 先关闭当前对话框
                                    _showTipColorPicker(); // 打开颜色选择器
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      _config.tipColor == 0
                          ? tipColorNames[0]
                          : tipColorNames[1],
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            // 分隔线颜色
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('分隔线颜色',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF2C2C2C),
                          title: const Text('选择分隔线颜色',
                              style: TextStyle(color: Colors.white)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: tipDividerColorNames
                                .asMap()
                                .entries
                                .map((entry) {
                              int currentValue = _config.tipDividerColor;
                              bool isSelected =
                                  (currentValue == -1 && entry.key == 0) ||
                                      (currentValue == 0 && entry.key == 1) ||
                                      (currentValue > 0 && entry.key == 2);
                              return ListTile(
                                title: Text(entry.value,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                trailing: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.orange)
                                    : null,
                                onTap: () {
                                  if (entry.key == 2) {
                                    Navigator.pop(context); // 先关闭当前对话框
                                    _showTipDividerColorPicker(); // 打开颜色选择器
                                  } else {
                                    int newValue = entry.key == 0
                                        ? -1
                                        : (entry.key == 1 ? 0 : 1);
                                    setState(() {
                                      _config = _config.copyWith(
                                          tipDividerColor: newValue);
                                    });
                                    _saveConfigSilently();
                                    Navigator.pop(context);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      _config.tipDividerColor == -1
                          ? tipDividerColorNames[0]
                          : _config.tipDividerColor == 0
                              ? tipDividerColorNames[1]
                              : tipDividerColorNames[2],
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建提示信息选择器
  Widget _buildTipSelector(
    String label,
    int currentValue,
    List<String> tipTypes,
    List<int> tipTypeValues,
    ValueChanged<int> onChanged,
  ) {
    // 找到当前值对应的索引
    int currentIndex = tipTypeValues.indexOf(currentValue);
    if (currentIndex == -1) currentIndex = 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF2C2C2C),
                  title: Text('选择$label',
                      style: const TextStyle(color: Colors.white)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: tipTypes.asMap().entries.map((entry) {
                        return ListTile(
                          title: Text(entry.value,
                              style: const TextStyle(color: Colors.white70)),
                          trailing: tipTypeValues[entry.key] == currentValue
                              ? const Icon(Icons.check, color: Colors.orange)
                              : null,
                          onTap: () {
                            onChanged(tipTypeValues[entry.key]);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
            child: Text(
              tipTypes[currentIndex],
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建带+/-按钮的滑块
  Widget _buildSliderWithButtons({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd, // 拖动结束回调
    String Function(double)? formatValue,
  }) {
    formatValue ??= (v) => v.toStringAsFixed(0);

    return Row(
      children: [
        // 标题
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        // 减号按钮
        IconButton(
          icon: const Icon(Icons.remove, color: Colors.white70, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
          onPressed: () {
            final newValue = (value - step).clamp(min, max);
            onChanged(newValue);
            // +/- 按钮点击时也立即保存并应用
            if (onChangeEnd != null) {
              onChangeEnd(newValue);
            }
          },
        ),
        // 滑块
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              activeTrackColor: const Color(0xFFFF6B6B),
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6.0,
              ),
              thumbColor: const Color(0xFFFF6B6B),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 12.0,
              ),
              overlayColor: const Color(0xFFFF6B6B).withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              activeColor: const Color(0xFFFF6B6B),
              onChanged: (newValue) {
                // 拖动过程中实时更新UI
                onChanged(newValue);
              },
              onChangeEnd: (newValue) {
                // 拖动结束后调用回调（如果提供）
                if (onChangeEnd != null) {
                  onChangeEnd(newValue);
                }
              },
            ),
          ),
        ),
        // 加号按钮
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white70, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
          onPressed: () {
            final newValue = (value + step).clamp(min, max);
            onChanged(newValue);
            // +/- 按钮点击时也立即保存并应用
            if (onChangeEnd != null) {
              onChangeEnd(newValue);
            }
          },
        ),
        const SizedBox(width: 8),
        // 当前值
        SizedBox(
          width: 42,
          child: Text(
            formatValue(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }

  /// 构建字体粗细选项
  Widget _buildFontWeightOption(String label, int value) {
    final isSelected = _config.fontWeight == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _config = _config.copyWith(fontWeight: value);
          // 根据字体粗细设置bold
          _config = _config.copyWith(bold: value == 2);
        });
        // 立即保存
        _saveConfigSilently();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8), // 24*2/3=16, 12*2/3=8
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withOpacity(0.3) : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey,
            width: isSelected ? 1.5 : 1, // 2*2/3≈1.33，取1.5
          ),
          borderRadius: BorderRadius.circular(5), // 8*2/3≈5.33，取5
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10, // 添加字体大小，缩小三分之一
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 构建翻页动画选项
  Widget _buildAnimationOption(String label, int value) {
    final isSelected = _config.pageAnimation == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _config = _config.copyWith(pageAnimation: value);
        });
        // 立即保存
        _saveConfigSilently();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  /// 构建颜色预设
  Widget _buildColorPresets() {
    // 从 ReadConfigService 动态加载配置列表
    final configList = ReadConfigService.instance.getConfigList();

    // 将 ReadConfig 转换为预设数据格式
    final presets = configList.asMap().entries.map((entry) {
      final config = entry.value;
      return {
        'index': entry.key, // 保存索引用于删除
        'name': config.styleName ?? '预设${entry.key + 1}',
        'text': config.textColor,
        'bg': config.backgroundColor,
      };
    }).toList();

    return SizedBox(
      height: 50, // 固定高度，允许横向滚动
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // 添加自定义按钮（放在第一个）
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                _showCustomColorDialog(
                    _config.textColor, _config.backgroundColor, null);
              },
              child: Container(
                width: 40, // 60 * 2/3 = 40
                height: 40, // 60 * 2/3 = 40
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, width: 1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add,
                    color: Colors.white, size: 20), // 30 * 2/3 = 20
              ),
            ),
          ),
          // 颜色预设列表
          ...presets.map((preset) {
            final isSelected = _config.textColor == preset['text'] &&
                _config.backgroundColor == preset['bg'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _config = _config.copyWith(
                      textColor: preset['text'] as int,
                      backgroundColor: preset['bg'] as int,
                    );
                  });
                  // 立即保存
                  _saveConfigSilently();
                },
                onLongPress: () {
                  // 长按打开自定义颜色对话框，传入配置索引
                  _showCustomColorDialog(
                    preset['text'] as int,
                    preset['bg'] as int,
                    preset['index'] as int,
                  );
                },
                child: Container(
                  width: 40, // 60 * 2/3 = 40
                  height: 40, // 60 * 2/3 = 40
                  decoration: BoxDecoration(
                    color: Color(preset['bg'] as int),
                    border: Border.all(
                      color: isSelected ? Colors.red : Colors.grey,
                      width: isSelected ? 2 : 1, // 3 * 2/3 = 2
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 13, // 20 * 2/3 ≈ 13.33，取13
                      height: 13, // 20 * 2/3 ≈ 13.33，取13
                      decoration: BoxDecoration(
                        color: Color(preset['text'] as int),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 构建字体列表
  Widget _buildFontFamilyList() {
    final fonts = [
      '系统默认',
      '宋体',
      '黑体',
      '楷体',
      '微软雅黑',
      '思源黑体',
      '思源宋体',
      '方正书宋',
      '方正黑体',
      '方正楷体',
      '华文宋体',
      '华文黑体',
      '华文楷体',
      '华文仿宋',
      '苹方',
      '冬青黑体',
      '兰亭黑',
      '文鼎PL简中楷',
      '文鼎PL简中宋',
      '文鼎PL简中黑',
    ];

    return Column(
      children: [
        // 快速选择按钮
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.font_download),
            label: const Text('更多字体'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => FontSelectDialog(
                  currentFontFamily: _config.fontFamily,
                  onFontSelected: (fontFamily) {
                    setState(() {
                      _config = _config.copyWith(fontFamily: fontFamily);
                    });
                    _saveConfigSilently();
                  },
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
          ),
        ),
        // 常用字体列表
        ...fonts.map((font) {
          final isSelected = (_config.fontFamily ?? '系统默认') == font;
          return ListTile(
            title: Text(
              font,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: font == '系统默认' ? null : font,
              ),
            ),
            trailing:
                isSelected ? const Icon(Icons.check, color: Colors.red) : null,
            onTap: () {
              setState(() {
                _config = _config.copyWith(
                  fontFamily: font == '系统默认' ? null : font,
                );
              });
              // 立即保存
              _saveConfigSilently();
            },
          );
        }),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _showCustomColorDialog(int currentTextColor, int currentBgColor,
      [int? configIndex]) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CustomColorDialog(
        book: widget.book,
        configIndex: configIndex,
        onConfigChanged: (newConfig) {
          // 配置改变时立即应用
          setState(() {
            _config = newConfig;
          });
          _saveConfigSilently();
        },
      ),
    );
  }

  /// 显示提示文字颜色选择器
  void _showTipColorPicker() {
    final currentColor = _config.tipColor > 0
        ? Color(_config.tipColor)
        : const Color(0xFFFFA500); // 默认橙色

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          '选择提示文字颜色',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                _config = _config.copyWith(tipColor: color.value);
              });
              _saveConfigSilently();
            },
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hslWithSaturation,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  /// 显示分隔线颜色选择器
  void _showTipDividerColorPicker() {
    final currentColor = _config.tipDividerColor > 0
        ? Color(_config.tipDividerColor)
        : const Color(0xFF666666); // 默认灰色

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          '选择分隔线颜色',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                _config = _config.copyWith(tipDividerColor: color.value);
              });
              _saveConfigSilently();
            },
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hslWithSaturation,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
