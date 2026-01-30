import 'package:flutter/material.dart';
import '../../../utils/app_log.dart';

/// 日志列表项组件
class AppLogItem extends StatelessWidget {
  final LogEntry log;
  final VoidCallback? onTap;

  const AppLogItem({
    super.key,
    required this.log,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = log.error != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[300]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 错误图标
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 2),
                child: Icon(
                  Icons.error_outline,
                  size: 20,
                  color: Colors.red[600],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 2),
                child: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.blue[600],
                ),
              ),
            // 日志内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间戳
                  Text(
                    log.formattedTime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 消息
                  Text(
                    log.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasError ? Colors.red[700] : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 错误信息（如果有）
                  if (hasError && log.error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 展开图标
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }
}

