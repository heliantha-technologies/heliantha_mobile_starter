import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heliantha_mobile/core/api/api_client.dart';
import 'package:heliantha_mobile/core/api/providers.dart';
import 'package:heliantha_mobile/core/storage/token_storage.dart';
import 'package:heliantha_mobile/features/addresses/data/addresses_repository.dart';
import 'package:heliantha_mobile/features/addresses/presentation/addresses_screen.dart';
import 'package:heliantha_mobile/features/addresses/providers/addresses_provider.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:heliantha_mobile/features/favorites/providers/favorites_provider.dart';
import 'package:heliantha_mobile/features/product/presentation/product_screen.dart';
import 'package:heliantha_mobile/shared/models/address.dart';
import 'package:heliantha_mobile/shared/models/product.dart';
import 'package:heliantha_mobile/shared/theme/app_colors.dart';
import 'package:heliantha_mobile/shared/widgets/product_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAddressesRepository implements AddressesRepository {
  int listCalls = 0;

  @override
  Future<List<AddressModel>> list() async {
    listCalls++;
    return const [
      AddressModel(
        id: 10,
        alias: 'Maison',
        address1: '12 Rue du Soleil',
        city: 'Casablanca',
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _product = Product(
  id: 42,
  name: 'Panneau solaire 450 W',
  price: 950,
  currency: 'MAD',
  currencySymbol: 'DH',
  available: true,
);

ApiClient _recordingApi(List<RequestOptions> requests) {
  final api = ApiClient(TokenStorage());
  api.dio.interceptors.clear();
  api.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        requests.add(request);
        handler.resolve(Response(requestOptions: request, statusCode: 200));
      },
    ),
  );
  return api;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guest addresses skip API and keep login return destination',
      (tester) async {
    final repository = _FakeAddressesRepository();
    Uri? loginUri;
    final router = GoRouter(
      initialLocation: '/addresses?from=checkout',
      routes: [
        GoRoute(
          path: '/addresses',
          builder: (_, state) => AddressesScreen(
            from: state.uri.queryParameters['from'],
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, state) {
            loginUri = state.uri;
            return const Scaffold(body: Text('Connexion client'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => null),
          addressesRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.listCalls, 0);
    expect(find.text('Bienvenue chez HeliAntha'), findsOneWidget);
    expect(find.text('Service momentanément indisponible'), findsNothing);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.location_on_rounded)).color,
      AppColors.sun,
    );

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion client'), findsOneWidget);
    expect(loginUri?.path, '/login');
    expect(
      loginUri?.queryParameters['redirect'],
      '/addresses?from=checkout',
    );
    expect(repository.listCalls, 0);
  });

  testWidgets('addresses wait for authentication then load connected data',
      (tester) async {
    final authentication = Completer<Map<String, dynamic>?>();
    final repository = _FakeAddressesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => authentication.future),
          addressesRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AddressesScreen()),
      ),
    );
    await tester.pump();
    expect(repository.listCalls, 0);

    authentication.complete({'id': 7});
    await tester.pumpAndSettle();
    expect(repository.listCalls, 1);
    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('12 Rue du Soleil'), findsOneWidget);
  });

  test('direct guest addresses provider access also skips API', () async {
    final repository = _FakeAddressesRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) async => null),
        addressesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(addressesProvider.future), isEmpty);
    expect(repository.listCalls, 0);
  });

  test('guest favorites restore and toggle locally without an API request',
      () async {
    SharedPreferences.setMockInitialValues({
      'favorite_product_ids': ['7'],
    });
    final requests = <RequestOptions>[];
    final api = _recordingApi(requests);
    addTearDown(api.dio.close);
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) async => null),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(favoritesProvider.notifier);
    // First interaction must retain favorites restored asynchronously.
    await notifier.toggle(42);
    expect(container.read(favoritesProvider), {7, 42});
    expect(requests, isEmpty);

    final restored = ProviderContainer(
      overrides: [currentUserProvider.overrideWith((ref) async => null)],
    );
    addTearDown(restored.dispose);
    await restored.read(favoritesProvider.notifier).ready;
    expect(restored.read(favoritesProvider), {7, 42});

    await notifier.toggle(42);
    expect(container.read(favoritesProvider), {7});
    expect(
      (await SharedPreferences.getInstance())
          .getStringList('favorite_product_ids'),
      ['7'],
    );
    expect(requests, isEmpty);
  });

  test('connected favorites retain server synchronization', () async {
    final requests = <RequestOptions>[];
    final api = _recordingApi(requests);
    addTearDown(api.dio.close);
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) async => {'id': 7}),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(favoritesProvider.notifier);
    await notifier.toggle(42);
    await notifier.toggle(42);

    expect(
        requests.map((request) => request.method).toList(), ['POST', 'DELETE']);
    expect(requests.every((request) => request.path == '/v1/favorites/42'),
        isTrue);
    expect(container.read(favoritesProvider), isEmpty);
  });

  testWidgets('guest product card toggles favorites without opening login',
      (tester) async {
    final requests = <RequestOptions>[];
    final api = _recordingApi(requests);
    addTearDown(api.dio.close);
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) async => null),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 340,
                child: ProductCard(product: _product),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await tester.pumpAndSettle();
    expect(container.read(favoritesProvider), contains(42));
    expect(find.byTooltip('Retirer des favoris'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byTooltip('Retirer des favoris'));
    await tester.pumpAndSettle();
    expect(container.read(favoritesProvider), isEmpty);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest product detail toggles favorites without opening login',
      (tester) async {
    final requests = <RequestOptions>[];
    final api = _recordingApi(requests);
    addTearDown(api.dio.close);
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) async => null),
        apiClientProvider.overrideWithValue(api),
        productProvider(42).overrideWith((ref) async => _product),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProductScreen(productId: 42)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ajouter aux favoris'));
    await tester.tap(find.text('Ajouter aux favoris'));
    await tester.pumpAndSettle();
    expect(container.read(favoritesProvider), contains(42));
    expect(find.text('Favori'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.text('Favori'));
    await tester.pumpAndSettle();
    expect(container.read(favoritesProvider), isEmpty);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
