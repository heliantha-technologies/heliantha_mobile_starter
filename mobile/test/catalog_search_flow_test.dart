import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/core/api/api_client.dart';
import 'package:heliantha_mobile/core/storage/token_storage.dart';
import 'package:heliantha_mobile/features/catalog/data/catalog_repository.dart';
import 'package:heliantha_mobile/features/catalog/presentation/catalog_screen.dart';
import 'package:heliantha_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:heliantha_mobile/features/catalog/providers/store_context_provider.dart';
import 'package:heliantha_mobile/shared/models/product.dart';
import 'package:heliantha_mobile/shared/models/store_context.dart';
import 'package:heliantha_mobile/shared/widgets/product_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Request {
  _Request(this.query, this.page, this.languageId, this.currencyId);
  final String? query;
  final int page;
  final int? languageId;
  final int? currencyId;
  final result = Completer<CatalogPage>();

  void complete(List<Product> items, {bool hasMore = false}) {
    result.complete(CatalogPage(items: items, page: page, hasMore: hasMore));
  }
}

class _FakeRepository implements CatalogRepository {
  final requests = <_Request>[];

  @override
  Future<CatalogPage> productsPage({
    int page = 1,
    int pageSize = 30,
    int? category,
    String? query,
    int? languageId,
    int? currencyId,
  }) {
    final request = _Request(query, page, languageId, currencyId);
    requests.add(request);
    return request.result.future;
  }

  @override
  void prefetchProducts({
    int page = 1,
    int pageSize = 30,
    int? category,
    String? query,
    int? languageId,
    int? currencyId,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product _product(int id) => Product(
      id: id,
      name: 'Produit $id',
      price: 100,
      currency: 'MAD',
      currencySymbol: 'DH',
      available: true,
    );

Future<void> _mount(WidgetTester tester, _FakeRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(repository),
      categoriesProvider.overrideWith((ref) async => []),
      storeContextProvider.overrideWith((ref) async => const StoreContext(
            defaultLanguageId: 1,
            languages: [],
            defaultCurrencyId: 1,
            currencies: [],
          )),
    ],
    child: const MaterialApp(home: CatalogScreen()),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

List<Product> _visibleGrid(WidgetTester tester) => tester
    .widget<ResponsiveProductSliverGrid>(
      find.byType(ResponsiveProductSliverGrid),
    )
    .products;

TextEditingController _search(WidgetTester tester) =>
    tester.widget<SearchBar>(find.byType(SearchBar)).controller!;

void _scrollToEnd(WidgetTester tester) {
  final scroll = tester
      .widget<CustomScrollView>(find.byType(CustomScrollView))
      .controller!;
  scroll.jumpTo(scroll.position.maxScrollExtent);
}

ApiClient _api(
    void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
  final api = ApiClient(TokenStorage());
  api.dio.interceptors.clear();
  api.dio.interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  addTearDown(() => api.dio.close(force: true));
  return api;
}

void main() {
  testWidgets('Typing invalidates a response before the 350ms debounce expires',
      (tester) async {
    final repository = _FakeRepository();
    await _mount(tester, repository);
    final obsolete = repository.requests.single;
    _search(tester).text = 'panneau';
    obsolete.complete([_product(1)]);
    await tester.pump(const Duration(milliseconds: 349));
    expect(repository.requests, hasLength(1));
    expect(find.byType(ResponsiveProductSliverGrid), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.requests.last.query, 'panneau');
    repository.requests.last.complete([_product(2)]);
    await tester.pump();
    await tester.pump();
    expect(_visibleGrid(tester).map((p) => p.id), [2]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Scrolling during debounce cannot mix two searches',
      (tester) async {
    final repository = _FakeRepository();
    await _mount(tester, repository);
    repository.requests.single.complete([
      for (var id = 1; id <= 30; id++) _product(id),
    ], hasMore: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    _search(tester).text = 'nouveau';
    _scrollToEnd(tester);
    await tester.pump(const Duration(milliseconds: 349));
    expect(repository.requests, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.requests.last.query, 'nouveau');
    expect(repository.requests.last.page, 1);
    repository.requests.last.complete([_product(901)]);
    await tester.pump();
    await tester.pump();
    expect(_visibleGrid(tester).map((p) => p.id), [901]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Clearing the field rejects an old pagination response',
      (tester) async {
    final repository = _FakeRepository();
    await _mount(tester, repository);
    repository.requests.single.complete([]);
    await tester.pump();
    _search(tester).text = 'batterie';
    await tester.pump(const Duration(milliseconds: 350));
    repository.requests.last.complete([
      for (var id = 1; id <= 30; id++) _product(id),
    ], hasMore: true);
    await tester.pump();
    await tester.pump();
    _scrollToEnd(tester);
    await tester.pump();
    final obsolete = repository.requests.last;
    expect(obsolete.query, 'batterie');
    expect(obsolete.page, 2);
    expect(obsolete.languageId, 1);
    expect(obsolete.currencyId, 1);
    _search(tester).clear();
    obsolete.complete([_product(900)]);
    await tester.pump(const Duration(milliseconds: 349));
    expect(_visibleGrid(tester).map((p) => p.id),
        [for (var id = 1; id <= 30; id++) id]);
    await tester.pump(const Duration(milliseconds: 1));
    final replacement = repository.requests.last;
    expect(replacement.query, isNull);
    expect(replacement.page, 1);
    replacement.complete([_product(901)]);
    await tester.pump();
    await tester.pump();
    expect(_visibleGrid(tester).map((p) => p.id), [901]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('A short page continues when has_more is true', (tester) async {
    final repository = _FakeRepository();
    await _mount(tester, repository);
    repository.requests.single.complete([_product(1)], hasMore: true);
    await tester.pump();
    await tester.pump();
    expect(repository.requests.last.page, 2);
    repository.requests.last.complete([_product(2)]);
    await tester.pump();
    await tester.pump();
    expect(_visibleGrid(tester).map((p) => p.id), [1, 2]);
    expect(repository.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('A full page stops when has_more is false', (tester) async {
    final repository = _FakeRepository();
    await _mount(tester, repository);
    repository.requests.single
        .complete([for (var id = 1; id <= 30; id++) _product(id)]);
    await tester.pump();
    await tester.pump();
    _scrollToEnd(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Category cache separates languages and reuses the correct translation',
      () async {
    final requested = <int?>[];
    final api = _api((options, handler) {
      final languageId = options.queryParameters['language_id'] as int?;
      requested.add(languageId);
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'data': [
            {
              'id': 9,
              'name': languageId == 1 ? 'Batteries' : 'Batterien',
              'active': true
            },
          ]
        },
      ));
    });
    final repository = CatalogRepository(api);
    expect(
        (await repository.categories(languageId: 1)).single.name, 'Batteries');
    expect(
        (await repository.categories(languageId: 2)).single.name, 'Batterien');
    expect(
        (await repository.categories(languageId: 1)).single.name, 'Batteries');
    expect(requested, [1, 2]);
  });

  test('Prefetch failure is silent and a foreground request can retry',
      () async {
    var calls = 0;
    final api = _api((options, handler) {
      calls++;
      if (calls == 1) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 503),
        ));
      } else {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'items': [
              {'id': 330, 'name': 'Batterie DEYE'}
            ],
            'page': 2,
            'has_more': false
          },
        ));
      }
    });
    final repository = CatalogRepository(api);
    repository.prefetchProducts(query: 'batterie', page: 2);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final result = await repository.productsPage(query: 'batterie', page: 2);
    expect(result.items.single.id, 330);
    expect(result.hasMore, isFalse);
    expect(calls, 2);
  });

  test(
      'Prefetch and foreground requests share one pending request and metadata',
      () async {
    final release = Completer<void>();
    var calls = 0;
    final api = _api((options, handler) async {
      calls++;
      await release.future;
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'data': [
            {'id': 330, 'name': 'Batterie DEYE'}
          ],
          'meta': {'page': 2, 'has_more': true}
        },
      ));
    });
    final repository = CatalogRepository(api);
    repository.prefetchProducts(
        query: 'batterie', page: 2, languageId: 1, currencyId: 2);
    final future = repository.productsPage(
        query: 'batterie', page: 2, languageId: 1, currencyId: 2);
    await Future<void>.delayed(Duration.zero);
    release.complete();
    final result = await future;
    expect(result.hasMore, isTrue);
    expect(result.page, 2);
    expect(result.items.single.id, 330);
    final cached = await repository.productsPage(
        query: 'batterie', page: 2, languageId: 1, currencyId: 2);
    expect(cached.hasMore, isTrue);
    expect(calls, 1);
  });

  test('Missing pagination metadata fails without guessing from the row count',
      () async {
    final api = _api((options, handler) {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'data': [
            {'id': 1, 'name': 'Panneau'}
          ]
        },
      ));
    });
    final repository = CatalogRepository(api);
    expect(
        (await repository.products()).single.id, 1); // Legacy list consumers.
    await expectLater(repository.productsPage(), throwsFormatException);
  });
}
