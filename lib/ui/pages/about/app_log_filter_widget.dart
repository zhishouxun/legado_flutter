import 'package:flutter/material.dart';
import 'app_log_page.dart';

/// 日志筛选组件
class AppLogFilterWidget extends StatelessWidget {
  final String searchQuery;
  final LogLevel filterLevel;
  final bool showErrorsOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<LogLevel> onFilterLevelChanged;
  final ValueChanged<bool> onShowErrorsOnlyChanged;

  const AppLogFilterWidget({
    super.key,
    required this.searchQuery,
    required this.filterLevel,
    required this.showErrorsOnly,
    required this.onSearchChanged,
    required this.onFilterLevelChanged,
    required this.onShowErrorsOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          // 搜索框
          TextField(
            decoration: InputDecoration(
              hintText: '搜索日志...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => onSearchChanged(''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 8),
          // 筛选选项
          Row(
            children: [
              // 级别筛选
              Expanded(
                child: DropdownButtonFormField<LogLevel>(
                  initialValue: filterLevel,
                  decoration: InputDecoration(
                    labelText: '级别',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: LogLevel.all,
                      child: Text('全部'),
                    ),
                    DropdownMenuItem(
                      value: LogLevel.info,
                      child: Text('信息'),
                    ),
                    DropdownMenuItem(
                      value: LogLevel.warning,
                      child: Text('警告'),
                    ),
                    DropdownMenuItem(
                      value: LogLevel.error,
                      child: Text('错误'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onFilterLevelChanged(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 仅显示错误
              FilterChip(
                label: const Text('仅错误'),
                selected: showErrorsOnly,
                onSelected: onShowErrorsOnlyChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
