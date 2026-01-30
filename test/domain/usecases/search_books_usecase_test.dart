import 'package:flutter_test/flutter_test.dart';
import 'package:legado_flutter/domain/entities/book_entity.dart';
import 'package:legado_flutter/domain/entities/book_source_entity.dart';
import 'package:legado_flutter/domain/usecases/search_books_usecase.dart';
import '../../mocks/mock_book_repository.dart';
import '../../mocks/mock_book_source_repository.dart';

void main() {
  late SearchBooksUseCase useCase;
  late MockBookRepository mockBookRepository;
  late MockBookSourceRepository mockBookSourceRepository;

  setUp(() {
    mockBookRepository = MockBookRepository();
    mockBookSourceRepository = MockBookSourceRepository();
    useCase = SearchBooksUseCase(
      bookRepository: mockBookRepository,
      bookSourceRepository: mockBookSourceRepository,
    );
  });

  group('SearchBooksUseCase', () {
    test('应该返回搜索结果流', () async {
      // Arrange
      final testBooks = [
        BookEntity(
          bookUrl: 'https://test.com/book1',
          name: '测试书籍1',
          author: '作者1',
          origin: 'https://source1.com',
          kind: '玄幻',
          intro: '简介1',
          coverUrl: '',
          tocUrl: '',
          latestChapterTitle: '',
          latestChapterTime: 0,
          lastCheckTime: 0,
          lastCheckCount: 0,
          totalChapterNum: 0,
          durChapterIndex: 0,
          durChapterPos: 0,
          durChapterTime: 0,
          durChapterTitle: '',
          wordCount: '',
          canUpdate: true,
          order: 0,
          originOrder: 0,
          variable: '',
          readConfig: null,
          group: 0,
          customCoverUrl: '',
          customIntro: '',
          customTag: '',
        ),
      ];

      final testSources = [
        BookSourceEntity(
          bookSourceUrl: 'https://source1.com',
          bookSourceName: '测试书源',
          bookSourceGroup: '',
          bookSourceType: 0,
          enabled: true,
          enabledExplore: true,
          enabledCookieJar: false,
          concurrentRate: '',
          header: '',
          loginUrl: '',
          loginUi: '',
          loginCheckJs: '',
          bookUrlPattern: '',
          coverDecodeJs: '',
          bookSourceComment: '',
          lastUpdateTime: 0,
          respondTime: 0,
          weight: 0,
          exploreUrl: '',
          ruleExplore: null,
          searchUrl: '',
          ruleSearch: null,
          ruleBookInfo: null,
          ruleToc: null,
          ruleContent: null,
        ),
      ];

      mockBookSourceRepository.setAllSources(testSources);
      mockBookRepository.setSearchBooksStream(Stream.value(testBooks));

      // Act
      final results = await useCase.execute('测试关键词').first;

      // Assert
      expect(results, equals(testBooks));
      expect(mockBookRepository.searchBooksCallCount, equals(1));
    });

    test('应该在没有书源时返回空列表', () async {
      // Arrange
      mockBookSourceRepository.setAllSources([]);

      // Act
      final results = await useCase.execute('测试关键词').first;

      // Assert
      expect(results, isEmpty);
      expect(mockBookRepository.searchBooksCallCount, equals(0));
    });

    test('应该进行去重处理', () async {
      // Arrange
      final duplicateBooks = [
        BookEntity(
          bookUrl: 'https://test.com/book1',
          name: '重复书籍',
          author: '作者A',
          origin: 'https://source1.com',
          kind: '',
          intro: '',
          coverUrl: '',
          tocUrl: '',
          latestChapterTitle: '',
          latestChapterTime: 0,
          lastCheckTime: 0,
          lastCheckCount: 0,
          totalChapterNum: 0,
          durChapterIndex: 0,
          durChapterPos: 0,
          durChapterTime: 0,
          durChapterTitle: '',
          wordCount: '',
          canUpdate: true,
          order: 0,
          originOrder: 0,
          variable: '',
          readConfig: null,
          group: 0,
          customCoverUrl: '',
          customIntro: '',
          customTag: '',
        ),
        BookEntity(
          bookUrl: 'https://test.com/book2',
          name: '重复书籍',
          author: '作者A',
          origin: 'https://source2.com',
          kind: '',
          intro: '',
          coverUrl: '',
          tocUrl: '',
          latestChapterTitle: '',
          latestChapterTime: 0,
          lastCheckTime: 0,
          lastCheckCount: 0,
          totalChapterNum: 0,
          durChapterIndex: 0,
          durChapterPos: 0,
          durChapterTime: 0,
          durChapterTitle: '',
          wordCount: '',
          canUpdate: true,
          order: 0,
          originOrder: 0,
          variable: '',
          readConfig: null,
          group: 0,
          customCoverUrl: '',
          customIntro: '',
          customTag: '',
        ),
      ];

      final testSources = [
        BookSourceEntity(
          bookSourceUrl: 'https://source1.com',
          bookSourceName: '测试书源',
          bookSourceGroup: '',
          bookSourceType: 0,
          enabled: true,
          enabledExplore: true,
          enabledCookieJar: false,
          concurrentRate: '',
          header: '',
          loginUrl: '',
          loginUi: '',
          loginCheckJs: '',
          bookUrlPattern: '',
          coverDecodeJs: '',
          bookSourceComment: '',
          lastUpdateTime: 0,
          respondTime: 0,
          weight: 0,
          exploreUrl: '',
          ruleExplore: null,
          searchUrl: '',
          ruleSearch: null,
          ruleBookInfo: null,
          ruleToc: null,
          ruleContent: null,
        ),
      ];

      mockBookSourceRepository.setAllSources(testSources);
      mockBookRepository.setSearchBooksStream(Stream.value(duplicateBooks));

      // Act
      final results = await useCase.executeWithDeduplication('测试关键词').first;

      // Assert
      expect(results.length, equals(1)); // 去重后只剩1本
      expect(results.first.name, equals('重复书籍'));
    });
  });
}
