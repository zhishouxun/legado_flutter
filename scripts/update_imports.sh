#!/bin/bash

# 批量更新导入路径脚本
# 使用方法: ./scripts/update_imports.sh

echo "开始更新导入路径..."

# 更新工具类导入
echo "更新工具类导入..."
find lib -name "*.dart" -type f -exec sed -i '' 's|utils/html_parser|utils/parsers/html_parser|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|utils/rule_parser|utils/parsers/rule_parser|g' {} +

# 更新服务导入 - 网络服务
echo "更新网络服务导入..."
find lib -name "*.dart" -type f -exec sed -i '' 's|services/network_service|services/network/network_service|g' {} +

# 更新服务导入 - 书籍服务
echo "更新书籍服务导入..."
find lib -name "*.dart" -type f -exec sed -i '' 's|services/book_service|services/book/book_service|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/local_book_service|services/book/local_book_service|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/remote_book_service|services/book/remote_book_service|g' {} +

# 更新服务导入 - 书源服务
echo "更新书源服务导入..."
find lib -name "*.dart" -type f -exec sed -i '' 's|services/book_source_service|services/source/book_source_service|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/book_source_debug_service|services/source/book_source_debug_service|g' {} +

# 更新服务导入 - 阅读器服务
echo "更新阅读器服务导入..."
find lib -name "*.dart" -type f -exec sed -i '' 's|services/content_processor|services/reader/content_processor|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/cache_service|services/reader/cache_service|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/cache_export_service|services/reader/cache_export_service|g' {} +

# 更新服务导入 - 媒体服务
echo "更新媒体服务导入..."
find lib -name "*.dart" -type f -exec sed -i '' 's|services/audio_play_service|services/media/audio_play_service|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/tts_service|services/media/tts_service|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/manga_service|services/media/manga_service|g' {} +

# 更新服务导入 - 存储服务
echo "更新存储服务导入..."
find lib -name "*.dart" -type f -exec sed -i '' 's|services/backup_service|services/storage/backup_service|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/restore_service|services/storage/restore_service|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/webdav_service|services/storage/webdav_service|g' {} +

# 更新服务导入 - Web服务
echo "更新Web服务导入..."
find lib -name "*.dart" -type f -exec sed -i '' 's|services/web_service_manager|services/web/web_service_manager|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|services/websocket_debug_handler|services/web/websocket_debug_handler|g' {} +

# 更新组件导入
echo "更新组件导入..."
find lib -name "*.dart" -type f -exec sed -i '' 's|widgets/book_card|widgets/book/book_card|g' {} +
find lib -name "*.dart" -type f -exec sed -i '' 's|widgets/book_grid_card|widgets/book/book_grid_card|g' {} +

echo "导入路径更新完成！"
echo "请运行 'flutter analyze' 检查是否有错误"

