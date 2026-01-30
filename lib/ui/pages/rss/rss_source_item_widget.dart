import 'package:flutter/material.dart';
import '../../../data/models/rss_source.dart';
import '../../widgets/common/custom_switch.dart';

/// RSS源项组件
class RssSourceItemWidget extends StatelessWidget {
  final RssSource source;
  final bool isSelected;
  final bool isBatchMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onToggleEnabled;

  const RssSourceItemWidget({
    super.key,
    required this.source,
    this.isSelected = false,
    this.isBatchMode = false,
    required this.onTap,
    this.onLongPress,
    this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected 
          ? Theme.of(context).primaryColor.withOpacity(0.1)
          : null,
      child: ListTile(
        leading: isBatchMode
            ? Checkbox(
                value: isSelected,
                onChanged: (value) => onTap(),
              )
            : Icon(
                source.enabled ? Icons.rss_feed : Icons.rss_feed_outlined,
                color: source.enabled 
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
        title: Text(
          source.sourceName,
          style: TextStyle(
            fontWeight: source.enabled ? FontWeight.bold : FontWeight.normal,
            decoration: source.enabled ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (source.sourceGroup != null && source.sourceGroup!.isNotEmpty)
              Text(
                '分组: ${source.sourceGroup}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            Text(
              source.sourceUrl,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: isBatchMode
            ? null
            : CustomSwitch(
                value: source.enabled,
                onChanged: onToggleEnabled,
              ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

