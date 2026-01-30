import 'package:flutter_test/flutter_test.dart';
import 'package:legado_flutter/domain/entities/book_entity.dart';
import 'package:legado_flutter/domain/usecases/get_shelf_books_usecase.dart';
import '../../mocks/mock_book_repository.dart';

void main() {
  late GetShelfBooksUseCase useCase;
  late MockBookRepository mockBookRepository;

  setUp(() {
    mockBookRepository = MockBookRepository();
    useCase = GetShelfBooksUseCase(
      bookRepository: mockBookRepository,
    );
  });

  group('GetShelfBooksUseCase', () {
    test('应该返回书架中的所有书籍', () async {
      // Arrange
      final testBooks = [
        _createTestBook('book1', '书籍1', 0, 1000),
        _createTestBook('book2', '书籍2', 0, 2000),
        _createTestBook('book3', '书籍3', 0, 3000),
      ];
      mockBookRepository.setShelfBooks(testBooks);

      // Act
      final result = await useCase.execute();

      // Assert
      expect(result.length, equals(3));
      expect(mockBookRepository.getShelfBooksCallCount, equals(1));
    });

    test('应该按分组返回书籍', () async {
      // Arrange
      final testBooks = [
        _createTestBook('book1', '书籍1', 1, 1000),
        _createTestBook('book2', '书籍2', 2, 2000),
        _createTestBook('book3', '书籍3', 1, 3000),
      ];
      mockBookRepository.setShelfBooks(testBooks);

      // Act
      final result = await useCase.executeByGroup(1);

      // Assert
      expect(result.length, equals(2));
      expect(result.every((book) => book.group == 1), isTrue);
    });

    test('应该返回最近阅读的书籍（按时间排序）', () async {
      // Arrange
      final testBooks = [
        _createTestBook('book1', '书籍1', 0, 1000),
        _createTestBook('book2', '书籍2', 0, 3000), // 最近
        _createTestBook('book3', '书籍3', 0, 2000),
      ];
      mockBookRepository.setShelfBooks(testBooks);

      // Act
      final result = await useCase.executeRecentlyRead(limit: 2);

      // Assert
      expect(result.length, equals(2));
      expect(result.first.bookUrl, equals('book2')); // 时间最新的排第一
      expect(result.last.bookUrl, equals('book3'));
    });

    test('应该返回最近更新的书籍（按更新时间排序）', () async {
      // Arrange
      final testBooks = [
        _createTestBook('book1', '书籍1', 0, 0, updateTime: 1000),
        _createTestBook('book2', '书籍2', 0, 0, updateTime: 3000), // 最新更新
        _createTestBook('book3', '书籍3', 0, 0, updateTime: 2000),
      ];
      mockBookRepository.setShelfBooks(testBooks);

      // Act
      final result = await useCase.executeRecentlyUpdated(limit: 2);

      // Assert
      expect(result.length, equals(2));
      expect(result.first.bookUrl, equals('book2'));
      expect(result.last.bookUrl, equals('book3'));
    });
  });
}

BookEntity _createTestBook(
  String url,
  String name,
  int group,
  int readTime, {
  int updateTime = 0,
}) {
  return BookEntity(
    bookUrl: url,
    name: name,
    author: '作者',
    origin: 'https://test.com',
    kind: '',
    intro: '',
    coverUrl: '',
    tocUrl: '',
    latestChapterTitle: '',
    latestChapterTime: updateTime,
    lastCheckTime: 0,
    lastCheckCount: 0,
    totalChapterNum: 0,
    durChapterIndex: 0,
    durChapterPos: 0,
    durChapterTime: readTime,
    durChapterTitle: '',
    wordCount: '',
    canUpdate: true,
    order: 0,
    originOrder: 0,
    variable: '',
    readConfig: null,
    group: group,
    customCoverUrl: '',
    customIntro: '',
    customTag: '',
  );
}
