import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/book_repository.dart';
import '../domain/repositories/book_source_repository.dart';
import '../data/repositories/book_repository_impl.dart';
import '../data/repositories/book_source_repository_impl.dart';
import '../data/datasources/book_local_datasource_impl.dart';
import '../data/datasources/book_remote_datasource_impl.dart';
import '../data/datasources/book_source_local_datasource_impl.dart';

/// Repository层的Provider定义
/// 使用Riverpod管理Repository实例的生命周期

// ==================== DataSource Providers ====================

/// Book本地数据源Provider
final bookLocalDataSourceProvider = Provider((ref) {
  return BookLocalDataSourceImpl();
});

/// Book远程数据源Provider
final bookRemoteDataSourceProvider = Provider((ref) {
  return BookRemoteDataSourceImpl();
});

/// BookSource本地数据源Provider
final bookSourceLocalDataSourceProvider = Provider((ref) {
  return BookSourceLocalDataSourceImpl();
});

// ==================== Repository Providers ====================

/// BookRepository Provider
/// 提供书籍相关的所有业务操作
final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepositoryImpl(
    localDataSource: ref.read(bookLocalDataSourceProvider),
    remoteDataSource: ref.read(bookRemoteDataSourceProvider),
  );
});

/// BookSourceRepository Provider
/// 提供书源相关的所有业务操作
final bookSourceRepositoryProvider = Provider<BookSourceRepository>((ref) {
  return BookSourceRepositoryImpl(
    localDataSource: ref.read(bookSourceLocalDataSourceProvider),
  );
});
