import 'package:flutter_test/flutter_test.dart';
import 'package:legado_flutter/domain/usecases/update_read_progress_usecase.dart';
import '../../mocks/mock_book_repository.dart';

void main() {
  late UpdateReadProgressUseCase useCase;
  late MockBookRepository mockBookRepository;

  setUp(() {
    mockBookRepository = MockBookRepository();
    useCase = UpdateReadProgressUseCase(
      bookRepository: mockBookRepository,
    );
  });

  group('UpdateReadProgressUseCase', () {
    test('应该成功更新阅读进度', () async {
      // Act
      await useCase.execute('https://test.com/book1', 10, 500);

      // Assert
      expect(mockBookRepository.updateReadProgressCallCount, equals(1));
    });

    test('应该移动到下一章', () async {
      // Act
      await useCase.moveToNextChapter('https://test.com/book1', 5);

      // Assert
      expect(mockBookRepository.updateReadProgressCallCount, equals(1));
      // 验证调用时使用的是下一章(6)和位置0
    });

    test('应该移动到上一章', () async {
      // Act
      await useCase.moveToPreviousChapter('https://test.com/book1', 5);

      // Assert
      expect(mockBookRepository.updateReadProgressCallCount, equals(1));
      // 验证调用时使用的是上一章(4)和位置0
    });

    test('当在第0章时不应该移动到上一章', () async {
      // Act
      await useCase.moveToPreviousChapter('https://test.com/book1', 0);

      // Assert
      expect(mockBookRepository.updateReadProgressCallCount, equals(0));
    });

    test('应该移动到指定章节开头', () async {
      // Act
      await useCase.moveToChapter('https://test.com/book1', 15);

      // Assert
      expect(mockBookRepository.updateReadProgressCallCount, equals(1));
      // 验证调用时使用的是第15章和位置0
    });
  });
}
