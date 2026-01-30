import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/book_source_provider.dart';

/// 书源分组管理对话框
class BookSourceGroupManageDialog extends ConsumerStatefulWidget {
  const BookSourceGroupManageDialog({super.key});

  @override
  ConsumerState<BookSourceGroupManageDialog> createState() =>
      _BookSourceGroupManageDialogState();
}

class _BookSourceGroupManageDialogState
    extends ConsumerState<BookSourceGroupManageDialog> {
  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(bookSourceGroupListProvider);

    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '分组管理',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 分组列表
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无分组', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(group),
                        trailing: IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          onPressed: () {
                            // 按分组筛选
                            Navigator.pop(context, 'group:$group');
                          },
                        ),
                        onTap: () {
                          // 按分组筛选
                          Navigator.pop(context, 'group:$group');
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('加载失败: $error'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
