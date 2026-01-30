import 'package:flutter/material.dart';
import '../../../data/models/book_source.dart';
import '../../../services/source/book_source_service.dart';
import '../../widgets/base/base_bottom_sheet_stateful.dart';

/// 搜索范围选择对话框
class SearchScopeDialog extends BaseBottomSheetStateful {
  final Function(List<BookSource>? sources, List<String>? groups)
      onScopeSelected;

  const SearchScopeDialog({
    super.key,
    required this.onScopeSelected,
  }) : super(
          title: '选择搜索范围',
          heightFactor: 0.8,
        );

  @override
  State<SearchScopeDialog> createState() => _SearchScopeDialogState();
}

class _SearchScopeDialogState extends BaseBottomSheetState<SearchScopeDialog> {
  bool _isLoading = true;
  List<BookSource> _allSources = [];
  List<String> _allGroups = [];

  // 选择状态
  bool _selectAll = true;
  List<BookSource> _selectedSources = [];
  List<String> _selectedGroups = [];

  // 视图模式：true = 按书源选择，false = 按分组选择
  bool _viewBySource = false;
  final TextEditingController _searchController = TextEditingController();
  List<BookSource> _filteredSources = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sources =
          await BookSourceService.instance.getAllBookSources(enabledOnly: true);
      final groups = await BookSourceService.instance.getAllGroups();

      setState(() {
        _allSources = sources;
        _allGroups = groups;
        _filteredSources = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _filteredSources = _allSources;
      } else {
        _filteredSources = _allSources.where((source) {
          return source.bookSourceName
                  .toLowerCase()
                  .contains(value.toLowerCase()) ||
              (source.bookSourceGroup != null &&
                  source.bookSourceGroup!
                      .toLowerCase()
                      .contains(value.toLowerCase()));
        }).toList();
      }
    });
  }

  void _toggleSource(BookSource source) {
    setState(() {
      if (_selectedSources.contains(source)) {
        _selectedSources.remove(source);
      } else {
        _selectedSources.add(source);
      }
      _selectAll = false;
    });
  }

  void _toggleGroup(String group) {
    setState(() {
      if (_selectedGroups.contains(group)) {
        _selectedGroups.remove(group);
      } else {
        _selectedGroups.add(group);
      }
      _selectAll = false;
    });
  }

  void _selectAllSources() {
    setState(() {
      if (_selectAll) {
        _selectedSources = [];
        _selectedGroups = [];
        _selectAll = false;
      } else {
        _selectedSources = List.from(_allSources);
        _selectAll = true;
      }
    });
  }

  void _confirm() {
    if (_selectAll) {
      widget.onScopeSelected(null, null);
    } else if (_viewBySource) {
      widget.onScopeSelected(
        _selectedSources.isEmpty ? null : _selectedSources,
        null,
      );
    } else {
      widget.onScopeSelected(
        null,
        _selectedGroups.isEmpty ? null : _selectedGroups,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 切换按钮
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('按分组'),
                  selected: !_viewBySource,
                  onSelected: (selected) {
                    setState(() {
                      _viewBySource = !selected;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('按书源'),
                  selected: _viewBySource,
                  onSelected: (selected) {
                    setState(() {
                      _viewBySource = selected;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // 搜索框（仅书源模式）
        if (_viewBySource)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索书源',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        // 内容区域
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _viewBySource
                  ? _buildSourceList()
                  : _buildGroupList(),
        ),
        // 底部按钮
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: _selectAllSources,
                child: Text(_selectAll ? '取消全选' : '全选'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _confirm,
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceList() {
    return ListView.builder(
      itemCount: _filteredSources.length,
      itemBuilder: (context, index) {
        final source = _filteredSources[index];
        final isSelected = _selectAll || _selectedSources.contains(source);

        return CheckboxListTile(
          title: Text(source.bookSourceName),
          subtitle: source.bookSourceGroup != null
              ? Text(source.bookSourceGroup!)
              : null,
          value: isSelected,
          onChanged: (value) => _toggleSource(source),
        );
      },
    );
  }

  Widget _buildGroupList() {
    return ListView.builder(
      itemCount: _allGroups.length,
      itemBuilder: (context, index) {
        final group = _allGroups[index];
        final isSelected = _selectAll || _selectedGroups.contains(group);

        return CheckboxListTile(
          title: Text(group),
          value: isSelected,
          onChanged: (value) => _toggleGroup(group),
        );
      },
    );
  }
}
