import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/search_books_usecase.dart';
import '../../domain/usecases/get_book_info_usecase.dart';
import '../../domain/usecases/get_chapter_list_usecase.dart';
import '../../domain/usecases/get_chapter_content_usecase.dart';
import '../../domain/usecases/get_shelf_books_usecase.dart';
import '../../domain/usecases/add_book_to_shelf_usecase.dart';
import '../../domain/usecases/remove_book_from_shelf_usecase.dart';
import '../../domain/usecases/update_read_progress_usecase.dart';
import '../../domain/usecases/check_book_update_usecase.dart';
import '../../domain/usecases/get_book_sources_usecase.dart';
import '../../domain/usecases/manage_book_source_usecase.dart';
import '../../domain/usecases/toggle_book_source_usecase.dart';
import '../../domain/usecases/import_export_book_source_usecase.dart';
import 'repository_providers.dart';

/// UseCase层的Provider定义
/// 使用Riverpod管理UseCase实例的生命周期

// ==================== 书籍相关 UseCases ====================

/// 搜索书籍UseCase Provider
final searchBooksUseCaseProvider = Provider((ref) {
  return SearchBooksUseCase(
    bookRepository: ref.read(bookRepositoryProvider),
    bookSourceRepository: ref.read(bookSourceRepositoryProvider),
  );
});

/// 获取书籍详情UseCase Provider
final getBookInfoUseCaseProvider = Provider((ref) {
  return GetBookInfoUseCase(
    bookRepository: ref.read(bookRepositoryProvider),
    bookSourceRepository: ref.read(bookSourceRepositoryProvider),
  );
});

/// 获取章节列表UseCase Provider
final getChapterListUseCaseProvider = Provider((ref) {
  return GetChapterListUseCase(
    bookRepository: ref.read(bookRepositoryProvider),
    bookSourceRepository: ref.read(bookSourceRepositoryProvider),
  );
});

/// 获取章节内容UseCase Provider
final getChapterContentUseCaseProvider = Provider((ref) {
  return GetChapterContentUseCase(
    bookRepository: ref.read(bookRepositoryProvider),
    bookSourceRepository: ref.read(bookSourceRepositoryProvider),
  );
});

// ==================== 书架管理 UseCases ====================

/// 获取书架书籍UseCase Provider
final getShelfBooksUseCaseProvider = Provider((ref) {
  return GetShelfBooksUseCase(
    bookRepository: ref.read(bookRepositoryProvider),
  );
});

/// 添加书籍到书架UseCase Provider
final addBookToShelfUseCaseProvider = Provider((ref) {
  return AddBookToShelfUseCase(
    bookRepository: ref.read(bookRepositoryProvider),
  );
});

/// 从书架删除书籍UseCase Provider
final removeBookFromShelfUseCaseProvider = Provider((ref) {
  return RemoveBookFromShelfUseCase(
    bookRepository: ref.read(bookRepositoryProvider),
  );
});

/// 更新阅读进度UseCase Provider
final updateReadProgressUseCaseProvider = Provider((ref) {
  return UpdateReadProgressUseCase(
    bookRepository: ref.read(bookRepositoryProvider),
  );
});

/// 检查书籍更新UseCase Provider
final checkBookUpdateUseCaseProvider = Provider((ref) {
  return CheckBookUpdateUseCase(
    bookRepository: ref.read(bookRepositoryProvider),
    bookSourceRepository: ref.read(bookSourceRepositoryProvider),
  );
});

// ==================== 书源管理 UseCases ====================

/// 获取书源列表UseCase Provider
final getBookSourcesUseCaseProvider = Provider((ref) {
  return GetBookSourcesUseCase(
    bookSourceRepository: ref.read(bookSourceRepositoryProvider),
  );
});

/// 管理书源UseCase Provider
final manageBookSourceUseCaseProvider = Provider((ref) {
  return ManageBookSourceUseCase(
    bookSourceRepository: ref.read(bookSourceRepositoryProvider),
  );
});

/// 切换书源启用状态UseCase Provider
final toggleBookSourceUseCaseProvider = Provider((ref) {
  return ToggleBookSourceUseCase(
    bookSourceRepository: ref.read(bookSourceRepositoryProvider),
  );
});

/// 导入导出书源UseCase Provider
final importExportBookSourceUseCaseProvider = Provider((ref) {
  return ImportExportBookSourceUseCase(
    bookSourceRepository: ref.read(bookSourceRepositoryProvider),
  );
});
