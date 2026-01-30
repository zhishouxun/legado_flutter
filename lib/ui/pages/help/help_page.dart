import 'package:flutter/material.dart';
import '../../widgets/common/custom_tab_bar.dart';

/// 帮助页面
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帮助'),
        bottom: CustomTabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '使用教程', icon: Icon(Icons.school)),
            Tab(text: '常见问题', icon: Icon(Icons.help)),
            Tab(text: '功能介绍', icon: Icon(Icons.info)),
            Tab(text: '快捷键', icon: Icon(Icons.keyboard)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTutorialTab(),
          _buildFAQTab(),
          _buildFeaturesTab(),
          _buildShortcutsTab(),
        ],
      ),
    );
  }

  /// 使用教程标签页
  Widget _buildTutorialTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: '快速开始',
          children: [
            _buildTutorialItem(
              '1. 添加书源',
              '在"我的"页面点击"书源管理"，可以导入或添加书源。支持从网络导入、本地文件导入等方式。',
            ),
            _buildTutorialItem(
              '2. 搜索书籍',
              '在书架页面点击搜索按钮，输入书名或作者名进行搜索。',
            ),
            _buildTutorialItem(
              '3. 开始阅读',
              '在搜索结果中选择书籍，点击"加入书架"后即可开始阅读。',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: '书源管理',
          children: [
            _buildTutorialItem(
              '导入书源',
              '支持从网络URL、本地文件、二维码等方式导入书源。推荐使用网络导入，可以自动更新。',
            ),
            _buildTutorialItem(
              '编辑书源',
              '点击书源列表中的书源，可以查看和编辑书源规则。',
            ),
            _buildTutorialItem(
              '测试书源',
              '在书源编辑页面可以测试书源的搜索、目录、正文等功能是否正常。',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: '阅读设置',
          children: [
            _buildTutorialItem(
              '字体设置',
              '在阅读页面点击设置，可以调整字体大小、字体类型、行距、边距等。',
            ),
            _buildTutorialItem(
              '主题设置',
              '支持自定义主题颜色，可以设置主色、强调色、背景色等。',
            ),
            _buildTutorialItem(
              '翻页方式',
              '支持点击翻页、滑动翻页、音量键翻页等多种翻页方式。',
            ),
          ],
        ),
      ],
    );
  }

  /// 常见问题标签页
  Widget _buildFAQTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFAQItem(
          question: '如何添加书源？',
          answer: '在"我的"页面点击"书源管理"，然后点击右上角的"+"按钮，可以选择从网络导入、本地文件导入或手动添加。',
        ),
        _buildFAQItem(
          question: '为什么搜索不到书籍？',
          answer: '可能的原因：1. 书源失效或规则错误；2. 网络连接问题；3. 搜索关键词不正确。建议尝试更换书源或检查网络连接。',
        ),
        _buildFAQItem(
          question: '如何备份数据？',
          answer: '在"我的"页面点击"备份恢复"，可以备份到本地或WebDAV。建议定期备份，以防数据丢失。',
        ),
        _buildFAQItem(
          question: '阅读时出现乱码怎么办？',
          answer: '可能是编码问题，可以在书源设置中调整编码方式。如果问题依然存在，建议更换其他书源。',
        ),
        _buildFAQItem(
          question: '如何清除缓存？',
          answer: '在"我的"页面点击"其他设置"，找到"缓存管理"部分，点击"清除所有缓存"即可。',
        ),
        _buildFAQItem(
          question: 'Web服务如何使用？',
          answer: '在"我的"页面开启"Web服务"开关，启动后会显示服务地址。可以通过浏览器访问该地址，使用Web界面管理书籍和书源。',
        ),
        _buildFAQItem(
          question: '如何导入本地书籍？',
          answer: '在书架页面点击右上角的菜单，选择"导入本地书籍"，然后选择TXT或EPUB格式的文件即可。',
        ),
        _buildFAQItem(
          question: '替换规则如何使用？',
          answer: '替换规则用于净化文本内容，可以去除广告、修正错别字等。在"我的"页面点击"替换规则"进行管理。',
        ),
      ],
    );
  }

  /// 功能介绍标签页
  Widget _buildFeaturesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFeatureCard(
          icon: Icons.book,
          title: '多源阅读',
          description: '支持多个书源，可以自由切换，确保阅读体验。',
        ),
        _buildFeatureCard(
          icon: Icons.palette,
          title: '自定义主题',
          description: '支持自定义主题颜色，打造个性化的阅读界面。',
        ),
        _buildFeatureCard(
          icon: Icons.bookmark,
          title: '书签功能',
          description: '支持添加书签，方便快速定位到重要位置。',
        ),
        _buildFeatureCard(
          icon: Icons.history,
          title: '阅读记录',
          description: '自动记录阅读进度，下次打开自动定位到上次阅读位置。',
        ),
        _buildFeatureCard(
          icon: Icons.backup,
          title: '数据备份',
          description: '支持本地备份和WebDAV备份，确保数据安全。',
        ),
        _buildFeatureCard(
          icon: Icons.web,
          title: 'Web服务',
          description: '内置Web服务，可以通过浏览器访问和管理。',
        ),
        _buildFeatureCard(
          icon: Icons.find_replace,
          title: '替换规则',
          description: '支持自定义替换规则，净化文本内容。',
        ),
        _buildFeatureCard(
          icon: Icons.volume_up,
          title: '朗读功能',
          description: '支持TTS朗读，解放双眼，享受听书乐趣。',
        ),
      ],
    );
  }

  /// 快捷键标签页
  Widget _buildShortcutsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: '阅读页面',
          children: [
            _buildShortcutItem('点击屏幕左侧', '上一页'),
            _buildShortcutItem('点击屏幕右侧', '下一页'),
            _buildShortcutItem('点击屏幕中央', '显示/隐藏菜单'),
            _buildShortcutItem('音量键', '翻页（需在设置中开启）'),
            _buildShortcutItem('双击屏幕', '添加/删除书签'),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: '书架页面',
          children: [
            _buildShortcutItem('长按书籍', '显示操作菜单'),
            _buildShortcutItem('点击搜索', '搜索书籍'),
            _buildShortcutItem('点击分组', '切换书籍分组'),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: '其他',
          children: [
            _buildShortcutItem('返回键', '返回上一页或退出'),
            _buildShortcutItem('菜单键', '显示更多选项'),
          ],
        ),
      ],
    );
  }

  /// 构建章节卡片
  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// 构建教程项
  Widget _buildTutorialItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
        ],
      ),
    );
  }

  /// 构建FAQ项
  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建功能卡片
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
      ),
    );
  }

  /// 构建快捷键项
  Widget _buildShortcutItem(String key, String action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              key,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                action,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

