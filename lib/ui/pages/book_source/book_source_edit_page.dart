import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/book_source.dart';
import '../../../data/models/book_source_rule.dart';
import '../../../services/source/book_source_service.dart';
import 'book_source_debug_page.dart';
import '../../widgets/book_source_rule_field.dart';
import '../../widgets/common/custom_switch_list_tile.dart';
import '../../widgets/common/custom_tab_bar.dart';

/// 书源编辑页面
class BookSourceEditPage extends StatefulWidget {
  final BookSource? bookSource;

  const BookSourceEditPage({super.key, this.bookSource});

  @override
  State<BookSourceEditPage> createState() => _BookSourceEditPageState();
}

class _BookSourceEditPageState extends State<BookSourceEditPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // 基本信息
  late TextEditingController _urlController;
  late TextEditingController _nameController;
  late TextEditingController _groupController;
  late TextEditingController _commentController;
  late TextEditingController _loginUrlController;
  late TextEditingController _loginUiController;
  late TextEditingController _loginCheckJsController;
  late TextEditingController _coverDecodeJsController;
  late TextEditingController _bookUrlPatternController;
  late TextEditingController _headerController;
  late TextEditingController _variableCommentController;
  late TextEditingController _concurrentRateController;
  late TextEditingController _jsLibController;

  bool _enabled = true;
  bool _enabledExplore = false;
  bool _enabledCookieJar = false;
  int _bookSourceType = 0; // 0: 文本, 1: 音频, 2: 图片, 3: 文件

  // 搜索规则
  late TextEditingController _searchUrlController;
  late TextEditingController _searchCheckKeyWordController;
  late TextEditingController _searchBookListController;
  late TextEditingController _searchNameController;
  late TextEditingController _searchAuthorController;
  late TextEditingController _searchKindController;
  late TextEditingController _searchWordCountController;
  late TextEditingController _searchLastChapterController;
  late TextEditingController _searchIntroController;
  late TextEditingController _searchCoverUrlController;
  late TextEditingController _searchBookUrlController;

  // 发现规则
  late TextEditingController _exploreUrlController;
  late TextEditingController _exploreBookListController;
  late TextEditingController _exploreNameController;
  late TextEditingController _exploreAuthorController;
  late TextEditingController _exploreKindController;
  late TextEditingController _exploreWordCountController;
  late TextEditingController _exploreLastChapterController;
  late TextEditingController _exploreIntroController;
  late TextEditingController _exploreCoverUrlController;
  late TextEditingController _exploreBookUrlController;

  // 详情页规则
  late TextEditingController _infoInitController;
  late TextEditingController _infoNameController;
  late TextEditingController _infoAuthorController;
  late TextEditingController _infoKindController;
  late TextEditingController _infoWordCountController;
  late TextEditingController _infoLastChapterController;
  late TextEditingController _infoIntroController;
  late TextEditingController _infoCoverUrlController;
  late TextEditingController _infoTocUrlController;
  late TextEditingController _infoCanReNameController;

  // 目录规则
  late TextEditingController _tocChapterListController;
  late TextEditingController _tocChapterNameController;
  late TextEditingController _tocChapterUrlController;
  late TextEditingController _tocIsVipController;
  late TextEditingController _tocUpdateTimeController;
  late TextEditingController _tocNextTocUrlController;

  // 正文规则
  late TextEditingController _contentContentController;
  late TextEditingController _contentNextContentUrlController;
  late TextEditingController _contentWebJsController;
  late TextEditingController _contentSourceRegexController;
  late TextEditingController _contentReplaceRegexController;
  late TextEditingController _contentImageStyleController;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initializeControllers();
  }

  void _initializeControllers() {
    final source = widget.bookSource;

    // 基本信息
    _urlController = TextEditingController(text: source?.bookSourceUrl ?? '');
    _nameController = TextEditingController(text: source?.bookSourceName ?? '');
    _groupController =
        TextEditingController(text: source?.bookSourceGroup ?? '');
    _commentController =
        TextEditingController(text: source?.bookSourceComment ?? '');
    _loginUrlController = TextEditingController(text: source?.loginUrl ?? '');
    _loginUiController = TextEditingController(text: source?.loginUi ?? '');
    _loginCheckJsController =
        TextEditingController(text: source?.loginCheckJs ?? '');
    _coverDecodeJsController =
        TextEditingController(text: source?.coverDecodeJs ?? '');
    _bookUrlPatternController =
        TextEditingController(text: source?.bookUrlPattern ?? '');
    _headerController = TextEditingController(text: source?.header ?? '');
    _variableCommentController =
        TextEditingController(text: source?.variableComment ?? '');
    _concurrentRateController =
        TextEditingController(text: source?.concurrentRate ?? '');
    _jsLibController = TextEditingController(text: source?.jsLib ?? '');

    _enabled = source?.enabled ?? true;
    _enabledExplore = source?.enabledExplore ?? false;
    _enabledCookieJar = source?.enabledCookieJar ?? false;
    _bookSourceType = source?.bookSourceType ?? 0;

    // 搜索规则
    final searchRule = source?.ruleSearch;
    _searchUrlController = TextEditingController(text: source?.searchUrl ?? '');
    _searchCheckKeyWordController =
        TextEditingController(text: searchRule?.checkKeyWord ?? '');
    _searchBookListController =
        TextEditingController(text: searchRule?.bookList ?? '');
    _searchNameController = TextEditingController(text: searchRule?.name ?? '');
    _searchAuthorController =
        TextEditingController(text: searchRule?.author ?? '');
    _searchKindController = TextEditingController(text: searchRule?.kind ?? '');
    _searchWordCountController =
        TextEditingController(text: searchRule?.wordCount ?? '');
    _searchLastChapterController =
        TextEditingController(text: searchRule?.lastChapter ?? '');
    _searchIntroController =
        TextEditingController(text: searchRule?.intro ?? '');
    _searchCoverUrlController =
        TextEditingController(text: searchRule?.coverUrl ?? '');
    _searchBookUrlController =
        TextEditingController(text: searchRule?.bookUrl ?? '');

    // 发现规则
    final exploreRule = source?.ruleExplore;
    _exploreUrlController =
        TextEditingController(text: source?.exploreUrl ?? '');
    _exploreBookListController =
        TextEditingController(text: exploreRule?.bookList ?? '');
    _exploreNameController =
        TextEditingController(text: exploreRule?.name ?? '');
    _exploreAuthorController =
        TextEditingController(text: exploreRule?.author ?? '');
    _exploreKindController =
        TextEditingController(text: exploreRule?.kind ?? '');
    _exploreWordCountController =
        TextEditingController(text: exploreRule?.wordCount ?? '');
    _exploreLastChapterController =
        TextEditingController(text: exploreRule?.lastChapter ?? '');
    _exploreIntroController =
        TextEditingController(text: exploreRule?.intro ?? '');
    _exploreCoverUrlController =
        TextEditingController(text: exploreRule?.coverUrl ?? '');
    _exploreBookUrlController =
        TextEditingController(text: exploreRule?.bookUrl ?? '');

    // 详情页规则
    final infoRule = source?.ruleBookInfo;
    _infoInitController = TextEditingController(text: infoRule?.init ?? '');
    _infoNameController = TextEditingController(text: infoRule?.name ?? '');
    _infoAuthorController = TextEditingController(text: infoRule?.author ?? '');
    _infoKindController = TextEditingController(text: infoRule?.kind ?? '');
    _infoWordCountController =
        TextEditingController(text: infoRule?.wordCount ?? '');
    _infoLastChapterController =
        TextEditingController(text: infoRule?.lastChapter ?? '');
    _infoIntroController = TextEditingController(text: infoRule?.intro ?? '');
    _infoCoverUrlController =
        TextEditingController(text: infoRule?.coverUrl ?? '');
    _infoTocUrlController = TextEditingController(text: infoRule?.tocUrl ?? '');
    _infoCanReNameController =
        TextEditingController(text: infoRule?.canReName ?? '');

    // 目录规则
    final tocRule = source?.ruleToc;
    _tocChapterListController =
        TextEditingController(text: tocRule?.chapterList ?? '');
    _tocChapterNameController =
        TextEditingController(text: tocRule?.chapterName ?? '');
    _tocChapterUrlController =
        TextEditingController(text: tocRule?.chapterUrl ?? '');
    _tocIsVipController = TextEditingController(text: tocRule?.isVip ?? '');
    _tocUpdateTimeController =
        TextEditingController(text: tocRule?.updateTime ?? '');
    _tocNextTocUrlController =
        TextEditingController(text: tocRule?.nextTocUrl ?? '');

    // 正文规则
    final contentRule = source?.ruleContent;
    _contentContentController =
        TextEditingController(text: contentRule?.content ?? '');
    _contentNextContentUrlController =
        TextEditingController(text: contentRule?.nextContentUrl ?? '');
    _contentWebJsController =
        TextEditingController(text: contentRule?.webJs ?? '');
    _contentSourceRegexController =
        TextEditingController(text: contentRule?.sourceRegex ?? '');
    _contentReplaceRegexController =
        TextEditingController(text: contentRule?.replaceRegex ?? '');
    _contentImageStyleController =
        TextEditingController(text: contentRule?.imageStyle ?? '');

    // 添加监听器以检测变化
    _addChangeListeners();
  }

  void _addChangeListeners() {
    final controllers = [
      _urlController,
      _nameController,
      _groupController,
      _commentController,
      _loginUrlController,
      _loginUiController,
      _loginCheckJsController,
      _coverDecodeJsController,
      _bookUrlPatternController,
      _headerController,
      _variableCommentController,
      _concurrentRateController,
      _jsLibController,
      _searchUrlController,
      _searchCheckKeyWordController,
      _searchBookListController,
      _searchNameController,
      _searchAuthorController,
      _searchKindController,
      _searchWordCountController,
      _searchLastChapterController,
      _searchIntroController,
      _searchCoverUrlController,
      _searchBookUrlController,
      _exploreUrlController,
      _exploreBookListController,
      _exploreNameController,
      _exploreAuthorController,
      _exploreKindController,
      _exploreWordCountController,
      _exploreLastChapterController,
      _exploreIntroController,
      _exploreCoverUrlController,
      _exploreBookUrlController,
      _infoInitController,
      _infoNameController,
      _infoAuthorController,
      _infoKindController,
      _infoWordCountController,
      _infoLastChapterController,
      _infoIntroController,
      _infoCoverUrlController,
      _infoTocUrlController,
      _infoCanReNameController,
      _tocChapterListController,
      _tocChapterNameController,
      _tocChapterUrlController,
      _tocIsVipController,
      _tocUpdateTimeController,
      _tocNextTocUrlController,
      _contentContentController,
      _contentNextContentUrlController,
      _contentWebJsController,
      _contentSourceRegexController,
      _contentReplaceRegexController,
      _contentImageStyleController,
    ];

    for (final controller in controllers) {
      controller.addListener(() {
        if (!_hasChanges) {
          setState(() {
            _hasChanges = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _urlController.dispose();
    _nameController.dispose();
    _groupController.dispose();
    _commentController.dispose();
    _loginUrlController.dispose();
    _loginUiController.dispose();
    _loginCheckJsController.dispose();
    _coverDecodeJsController.dispose();
    _bookUrlPatternController.dispose();
    _headerController.dispose();
    _variableCommentController.dispose();
    _concurrentRateController.dispose();
    _jsLibController.dispose();
    _searchUrlController.dispose();
    _searchCheckKeyWordController.dispose();
    _searchBookListController.dispose();
    _searchNameController.dispose();
    _searchAuthorController.dispose();
    _searchKindController.dispose();
    _searchWordCountController.dispose();
    _searchLastChapterController.dispose();
    _searchIntroController.dispose();
    _searchCoverUrlController.dispose();
    _searchBookUrlController.dispose();
    _exploreUrlController.dispose();
    _exploreBookListController.dispose();
    _exploreNameController.dispose();
    _exploreAuthorController.dispose();
    _exploreKindController.dispose();
    _exploreWordCountController.dispose();
    _exploreLastChapterController.dispose();
    _exploreIntroController.dispose();
    _exploreCoverUrlController.dispose();
    _exploreBookUrlController.dispose();
    _infoInitController.dispose();
    _infoNameController.dispose();
    _infoAuthorController.dispose();
    _infoKindController.dispose();
    _infoWordCountController.dispose();
    _infoLastChapterController.dispose();
    _infoIntroController.dispose();
    _infoCoverUrlController.dispose();
    _infoTocUrlController.dispose();
    _infoCanReNameController.dispose();
    _tocChapterListController.dispose();
    _tocChapterNameController.dispose();
    _tocChapterUrlController.dispose();
    _tocIsVipController.dispose();
    _tocUpdateTimeController.dispose();
    _tocNextTocUrlController.dispose();
    _contentContentController.dispose();
    _contentNextContentUrlController.dispose();
    _contentWebJsController.dispose();
    _contentSourceRegexController.dispose();
    _contentReplaceRegexController.dispose();
    _contentImageStyleController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bookSource != null;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('退出'),
              content: const Text('有未保存的更改，确定要退出吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
          if (shouldPop == true && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? '编辑书源' : '添加书源'),
          bottom: CustomTabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: '基本信息'),
              Tab(text: '搜索规则'),
              Tab(text: '发现规则'),
              Tab(text: '详情页规则'),
              Tab(text: '目录规则'),
              Tab(text: '正文规则'),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'save':
                    _saveBookSource();
                    break;
                  case 'debug':
                    _debugSource();
                    break;
                  case 'copy':
                    _copySource();
                    break;
                  case 'paste':
                    _pasteSource();
                    break;
                  case 'share':
                    _shareSource();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      Icon(Icons.save, size: 20),
                      SizedBox(width: 8),
                      Text('保存'),
                    ],
                  ),
                ),
                if (isEdit) ...[
                  const PopupMenuItem(
                    value: 'debug',
                    child: Row(
                      children: [
                        Icon(Icons.bug_report, size: 20),
                        SizedBox(width: 8),
                        Text('调试'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 20),
                        SizedBox(width: 8),
                        Text('复制'),
                      ],
                    ),
                  ),
                ],
                const PopupMenuItem(
                  value: 'paste',
                  child: Row(
                    children: [
                      Icon(Icons.paste, size: 20),
                      SizedBox(width: 8),
                      Text('粘贴'),
                    ],
                  ),
                ),
                if (isEdit)
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(width: 8),
                        Text('分享'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBasicInfoTab(),
              _buildSearchRuleTab(),
              _buildExploreRuleTab(),
              _buildInfoRuleTab(),
              _buildTocRuleTab(),
              _buildContentRuleTab(),
            ],
          ),
        ),
      ),
    );
  }

  // 由于代码太长，我会在下一个回复中继续实现各个标签页的构建方法
  // 这里先创建一个占位实现
  Widget _buildBasicInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 基本信息字段
        TextFormField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: '书源地址 *',
            hintText: 'https://example.com',
            border: const OutlineInputBorder(),
            helperText: widget.bookSource != null 
                ? '修改地址将创建新书源并删除旧书源' 
                : null,
            helperMaxLines: 2,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入书源地址';
            }
            final uri = Uri.tryParse(value);
            if (uri == null || !uri.hasScheme) {
              return '请输入有效的URL';
            }
            return null;
          },
          onChanged: (_) {
            setState(() {
              _hasChanges = true;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '书源名称 *',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入书源名称';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _groupController,
          decoration: const InputDecoration(
            labelText: '分组（多个用逗号分隔）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _bookSourceType,
          decoration: const InputDecoration(
            labelText: '书源类型',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 0, child: Text('文本')),
            DropdownMenuItem(value: 1, child: Text('音频')),
            DropdownMenuItem(value: 2, child: Text('图片')),
            DropdownMenuItem(value: 3, child: Text('文件')),
          ],
          onChanged: (value) {
            setState(() {
              _bookSourceType = value ?? 0;
              _hasChanges = true;
            });
          },
        ),
        const SizedBox(height: 16),
        CustomSwitchListTile(
          title: const Text('启用'),
          value: _enabled,
          onChanged: (value) {
            setState(() {
              _enabled = value;
              _hasChanges = true;
            });
          },
        ),
        CustomSwitchListTile(
          title: const Text('启用发现'),
          value: _enabledExplore,
          onChanged: (value) {
            setState(() {
              _enabledExplore = value;
              _hasChanges = true;
            });
          },
        ),
        CustomSwitchListTile(
          title: const Text('启用CookieJar'),
          value: _enabledCookieJar,
          onChanged: (value) {
            setState(() {
              _enabledCookieJar = value;
              _hasChanges = true;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _commentController,
          decoration: const InputDecoration(
            labelText: '注释',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _headerController,
          decoration: const InputDecoration(
            labelText: '请求头（JSON格式）',
            border: OutlineInputBorder(),
            helperText: '例如: {"User-Agent": "Mozilla/5.0"}',
          ),
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _loginUrlController,
          decoration: const InputDecoration(
            labelText: '登录地址',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _loginUiController,
          decoration: const InputDecoration(
            labelText: '登录UI',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _loginCheckJsController,
          decoration: const InputDecoration(
            labelText: '登录检测JS',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bookUrlPatternController,
          decoration: const InputDecoration(
            labelText: '详情页URL正则',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _coverDecodeJsController,
          decoration: const InputDecoration(
            labelText: '封面解密JS',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _concurrentRateController,
          decoration: const InputDecoration(
            labelText: '并发率',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _variableCommentController,
          decoration: const InputDecoration(
            labelText: '变量说明',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _jsLibController,
          decoration: const InputDecoration(
            labelText: 'JS库',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _buildSearchRuleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BookSourceRuleField(
          controller: _searchUrlController,
          label: '搜索URL',
          hint: '例如: /search?q={{key}}',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchCheckKeyWordController,
          label: '关键词检查',
          hint: '检查关键词规则',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchBookListController,
          label: '书籍列表',
          hint: 'CSS选择器或XPath',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchNameController,
          label: '书名',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchAuthorController,
          label: '作者',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchKindController,
          label: '分类',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchWordCountController,
          label: '字数',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchLastChapterController,
          label: '最新章节',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchIntroController,
          label: '简介',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchCoverUrlController,
          label: '封面URL',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _searchBookUrlController,
          label: '详情页URL',
        ),
      ],
    );
  }

  Widget _buildExploreRuleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BookSourceRuleField(
          controller: _exploreUrlController,
          label: '发现URL',
          hint: '例如: /sort/0_{{page}}/',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _exploreBookListController,
          label: '书籍列表',
          hint: 'CSS选择器或XPath',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _exploreNameController,
          label: '书名',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _exploreAuthorController,
          label: '作者',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _exploreKindController,
          label: '分类',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _exploreWordCountController,
          label: '字数',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _exploreLastChapterController,
          label: '最新章节',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _exploreIntroController,
          label: '简介',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _exploreCoverUrlController,
          label: '封面URL',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _exploreBookUrlController,
          label: '详情页URL',
        ),
      ],
    );
  }

  Widget _buildInfoRuleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BookSourceRuleField(
          controller: _infoInitController,
          label: '初始化规则',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _infoNameController,
          label: '书名',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _infoAuthorController,
          label: '作者',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _infoKindController,
          label: '分类',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _infoWordCountController,
          label: '字数',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _infoLastChapterController,
          label: '最新章节',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _infoIntroController,
          label: '简介',
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _infoCoverUrlController,
          label: '封面URL',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _infoTocUrlController,
          label: '目录URL',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _infoCanReNameController,
          label: '可重命名',
        ),
      ],
    );
  }

  Widget _buildTocRuleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BookSourceRuleField(
          controller: _tocChapterListController,
          label: '章节列表',
          hint: 'CSS选择器或XPath',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _tocChapterNameController,
          label: '章节名称',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _tocChapterUrlController,
          label: '章节URL',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _tocIsVipController,
          label: 'VIP标识',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _tocUpdateTimeController,
          label: '更新时间',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _tocNextTocUrlController,
          label: '下一页目录URL',
        ),
      ],
    );
  }

  Widget _buildContentRuleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BookSourceRuleField(
          controller: _contentContentController,
          label: '正文内容',
          hint: 'CSS选择器或XPath',
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _contentNextContentUrlController,
          label: '下一章URL',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _contentWebJsController,
          label: 'Web JS',
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _contentSourceRegexController,
          label: '源正则',
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _contentReplaceRegexController,
          label: '替换正则',
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        BookSourceRuleField(
          controller: _contentImageStyleController,
          label: '图片样式',
        ),
      ],
    );
  }

  Future<void> _saveBookSource() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final bookSource = _buildBookSource();
      final newUrl = _urlController.text.trim();
      final oldUrl = widget.bookSource?.bookSourceUrl;

      if (widget.bookSource != null) {
        // 编辑模式
        if (oldUrl != null && oldUrl != newUrl) {
          // URL 已修改：删除旧书源，添加新书源
          await BookSourceService.instance.deleteBookSource(oldUrl);
          await BookSourceService.instance.addBookSource(bookSource);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('书源地址已修改，已创建新书源并删除旧书源')),
            );
          }
        } else {
          // URL 未修改：正常更新
          await BookSourceService.instance.updateBookSource(bookSource);
        }
      } else {
        // 新增模式
        await BookSourceService.instance.addBookSource(bookSource);
      }

      setState(() {
        _hasChanges = false;
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.bookSource != null ? '保存成功' : '添加成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  BookSource _buildBookSource() {
    final source = widget.bookSource;

    return BookSource(
      bookSourceUrl: _urlController.text.trim(),
      bookSourceName: _nameController.text.trim(),
      bookSourceGroup: _groupController.text.trim().isEmpty
          ? null
          : _groupController.text.trim(),
      bookSourceType: _bookSourceType,
      bookUrlPattern: _bookUrlPatternController.text.trim().isEmpty
          ? null
          : _bookUrlPatternController.text.trim(),
      customOrder: source?.customOrder ?? 0,
      enabled: _enabled,
      enabledExplore: _enabledExplore,
      jsLib: _jsLibController.text.trim().isEmpty
          ? null
          : _jsLibController.text.trim(),
      enabledCookieJar: _enabledCookieJar,
      concurrentRate: _concurrentRateController.text.trim().isEmpty
          ? null
          : _concurrentRateController.text.trim(),
      header: _headerController.text.trim().isEmpty
          ? null
          : _headerController.text.trim(),
      loginUrl: _loginUrlController.text.trim().isEmpty
          ? null
          : _loginUrlController.text.trim(),
      loginUi: _loginUiController.text.trim().isEmpty
          ? null
          : _loginUiController.text.trim(),
      loginCheckJs: _loginCheckJsController.text.trim().isEmpty
          ? null
          : _loginCheckJsController.text.trim(),
      coverDecodeJs: _coverDecodeJsController.text.trim().isEmpty
          ? null
          : _coverDecodeJsController.text.trim(),
      bookSourceComment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      variableComment: _variableCommentController.text.trim().isEmpty
          ? null
          : _variableCommentController.text.trim(),
      lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
      respondTime: source?.respondTime ?? 0,
      weight: source?.weight ?? 0,
      searchUrl: _searchUrlController.text.trim().isEmpty
          ? null
          : _searchUrlController.text.trim(),
      ruleSearch: SearchRule(
        checkKeyWord: _searchCheckKeyWordController.text.trim().isEmpty
            ? null
            : _searchCheckKeyWordController.text.trim(),
        bookList: _searchBookListController.text.trim().isEmpty
            ? null
            : _searchBookListController.text.trim(),
        name: _searchNameController.text.trim().isEmpty
            ? null
            : _searchNameController.text.trim(),
        author: _searchAuthorController.text.trim().isEmpty
            ? null
            : _searchAuthorController.text.trim(),
        kind: _searchKindController.text.trim().isEmpty
            ? null
            : _searchKindController.text.trim(),
        wordCount: _searchWordCountController.text.trim().isEmpty
            ? null
            : _searchWordCountController.text.trim(),
        lastChapter: _searchLastChapterController.text.trim().isEmpty
            ? null
            : _searchLastChapterController.text.trim(),
        intro: _searchIntroController.text.trim().isEmpty
            ? null
            : _searchIntroController.text.trim(),
        coverUrl: _searchCoverUrlController.text.trim().isEmpty
            ? null
            : _searchCoverUrlController.text.trim(),
        bookUrl: _searchBookUrlController.text.trim().isEmpty
            ? null
            : _searchBookUrlController.text.trim(),
      ),
      exploreUrl: _exploreUrlController.text.trim().isEmpty
          ? null
          : _exploreUrlController.text.trim(),
      ruleExplore: ExploreRule(
        bookList: _exploreBookListController.text.trim().isEmpty
            ? null
            : _exploreBookListController.text.trim(),
        name: _exploreNameController.text.trim().isEmpty
            ? null
            : _exploreNameController.text.trim(),
        author: _exploreAuthorController.text.trim().isEmpty
            ? null
            : _exploreAuthorController.text.trim(),
        kind: _exploreKindController.text.trim().isEmpty
            ? null
            : _exploreKindController.text.trim(),
        wordCount: _exploreWordCountController.text.trim().isEmpty
            ? null
            : _exploreWordCountController.text.trim(),
        lastChapter: _exploreLastChapterController.text.trim().isEmpty
            ? null
            : _exploreLastChapterController.text.trim(),
        intro: _exploreIntroController.text.trim().isEmpty
            ? null
            : _exploreIntroController.text.trim(),
        coverUrl: _exploreCoverUrlController.text.trim().isEmpty
            ? null
            : _exploreCoverUrlController.text.trim(),
        bookUrl: _exploreBookUrlController.text.trim().isEmpty
            ? null
            : _exploreBookUrlController.text.trim(),
      ),
      ruleBookInfo: BookInfoRule(
        init: _infoInitController.text.trim().isEmpty
            ? null
            : _infoInitController.text.trim(),
        name: _infoNameController.text.trim().isEmpty
            ? null
            : _infoNameController.text.trim(),
        author: _infoAuthorController.text.trim().isEmpty
            ? null
            : _infoAuthorController.text.trim(),
        kind: _infoKindController.text.trim().isEmpty
            ? null
            : _infoKindController.text.trim(),
        wordCount: _infoWordCountController.text.trim().isEmpty
            ? null
            : _infoWordCountController.text.trim(),
        lastChapter: _infoLastChapterController.text.trim().isEmpty
            ? null
            : _infoLastChapterController.text.trim(),
        intro: _infoIntroController.text.trim().isEmpty
            ? null
            : _infoIntroController.text.trim(),
        coverUrl: _infoCoverUrlController.text.trim().isEmpty
            ? null
            : _infoCoverUrlController.text.trim(),
        tocUrl: _infoTocUrlController.text.trim().isEmpty
            ? null
            : _infoTocUrlController.text.trim(),
        canReName: _infoCanReNameController.text.trim().isEmpty
            ? null
            : _infoCanReNameController.text.trim(),
      ),
      ruleToc: TocRule(
        chapterList: _tocChapterListController.text.trim().isEmpty
            ? null
            : _tocChapterListController.text.trim(),
        chapterName: _tocChapterNameController.text.trim().isEmpty
            ? null
            : _tocChapterNameController.text.trim(),
        chapterUrl: _tocChapterUrlController.text.trim().isEmpty
            ? null
            : _tocChapterUrlController.text.trim(),
        isVip: _tocIsVipController.text.trim().isEmpty
            ? null
            : _tocIsVipController.text.trim(),
        updateTime: _tocUpdateTimeController.text.trim().isEmpty
            ? null
            : _tocUpdateTimeController.text.trim(),
        nextTocUrl: _tocNextTocUrlController.text.trim().isEmpty
            ? null
            : _tocNextTocUrlController.text.trim(),
      ),
      ruleContent: ContentRule(
        content: _contentContentController.text.trim().isEmpty
            ? null
            : _contentContentController.text.trim(),
        nextContentUrl: _contentNextContentUrlController.text.trim().isEmpty
            ? null
            : _contentNextContentUrlController.text.trim(),
        webJs: _contentWebJsController.text.trim().isEmpty
            ? null
            : _contentWebJsController.text.trim(),
        sourceRegex: _contentSourceRegexController.text.trim().isEmpty
            ? null
            : _contentSourceRegexController.text.trim(),
        replaceRegex: _contentReplaceRegexController.text.trim().isEmpty
            ? null
            : _contentReplaceRegexController.text.trim(),
        imageStyle: _contentImageStyleController.text.trim().isEmpty
            ? null
            : _contentImageStyleController.text.trim(),
      ),
    );
  }

  Future<void> _debugSource() async {
    final source = _buildBookSource();
    await BookSourceService.instance.updateBookSource(source);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BookSourceDebugPage(sourceUrl: source.bookSourceUrl),
        ),
      );
    }
  }

  Future<void> _copySource() async {
    final source = _buildBookSource();
    final json = jsonEncode(source.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  Future<void> _pasteSource() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板为空')),
        );
      }
      return;
    }

    try {
      final json = jsonDecode(data.text!);
      BookSource.fromJson(json as Map<String, dynamic>);
      // 重新初始化控制器
      setState(() {
        _disposeControllers();
        _initializeControllers();
        _hasChanges = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('粘贴成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('粘贴失败: $e')),
        );
      }
    }
  }

  Future<void> _shareSource() async {
    try {
      final source = _buildBookSource();
      final jsonStr = jsonEncode(source.toJson());
      
      // 使用 share_plus 包分享
      await Share.share(
        jsonStr,
        subject: '书源分享: ${source.bookSourceName}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书源已分享')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }
}
