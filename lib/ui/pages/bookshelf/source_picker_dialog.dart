import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/book_source.dart';
import '../../../services/source/book_source_service.dart';
import '../../widgets/base/base_bottom_sheet_consumer.dart';

/// 书源选择对话框
/// 参考项目：SourcePickerDialog.kt
class SourcePickerDialog extends BaseBottomSheetConsumer {
  final Function(BookSource)? onSourceSelected;

  const SourcePickerDialog({
    super.key,
    this.onSourceSelected,
  }) : super(
          title: '选择书源',
          heightFactor: 0.8,
        );

  @override
  ConsumerState<SourcePickerDialog> createState() => _SourcePickerDialogState();
}

class _SourcePickerDialogState
    extends BaseBottomSheetConsumerState<SourcePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<BookSource> _allSources = [];
  List<BookSource> _filteredSources = [];
  bool _isLoading = true;
  String? _selectedGroup;
  List<String> _groups = [];

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
        _groups = groups;
        _filteredSources = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterSources(String keyword) {
    setState(() {
      if (keyword.isEmpty) {
        _filteredSources = _allSources;
      } else {
        _filteredSources = _allSources.where((source) {
          return source.bookSourceName
                  .toLowerCase()
                  .contains(keyword.toLowerCase()) ||
              source.bookSourceUrl
                  .toLowerCase()
                  .contains(keyword.toLowerCase());
        }).toList();
      }
    });
  }

  void _filterByGroup(String? group) {
    setState(() {
      _selectedGroup = group;
      if (group == null || group.isEmpty) {
        _filteredSources = _allSources;
      } else {
        _filteredSources = _allSources.where((source) {
          return source.bookSourceGroup == group;
        }).toList();
      }
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // 搜索框和分组选择
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索书源',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterSources('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: _filterSources,
              ),
              const SizedBox(height: 8),
              // 分组选择
              if (_groups.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('全部分组'),
                        selected: _selectedGroup == null,
                        onSelected: (selected) {
                          if (selected) {
                            _filterByGroup(null);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._groups.map((group) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(group),
                              selected: _selectedGroup == group,
                              onSelected: (selected) {
                                if (selected) {
                                  _filterByGroup(group);
                                }
                              },
                            ),
                          )),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 书源列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSources.isEmpty
                  ? const Center(
                      child: Text('没有找到书源'),
                    )
                  : ListView.builder(
                      itemCount: _filteredSources.length,
                      itemBuilder: (context, index) {
                        final source = _filteredSources[index];
                        return ListTile(
                          title: Text(source.bookSourceName),
                          subtitle: Text(
                            source.bookSourceUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: source.bookSourceGroup != null
                              ? Chip(
                                  label: Text(
                                    source.bookSourceGroup!,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  padding: EdgeInsets.zero,
                                )
                              : null,
                          onTap: () {
                            widget.onSourceSelected?.call(source);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
