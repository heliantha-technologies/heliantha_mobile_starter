import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/cart/domain/cart_item.dart';
import 'package:heliantha_mobile/features/cart/providers/cart_provider.dart';
import 'package:heliantha_mobile/features/catalog/data/catalog_repository.dart';
import 'package:heliantha_mobile/features/catalog/data/store_context_repository.dart';
import 'package:heliantha_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:heliantha_mobile/features/catalog/providers/store_context_provider.dart';
import 'package:heliantha_mobile/shared/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

Product _product(int id, int currencyId) => Product(
      id: id,
      name: 'Équipement solaire $id',
      price: currencyId == 1 ? 1000 : 100,
      currency: currencyId == 1 ? 'MAD' : 'EUR',
      currencySymbol: currencyId == 1 ? 'DH' : '€',
      currencyId: currencyId,
      available: true,
    );

class _SelectedCurrencyRepository implements StoreContextRepository {
  @override
  Future<int?> readCurrencyId() async => 2;

  @override
  Future<int?> readLanguageId() async => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CurrencyCatalogRepository implements CatalogRepository {
  final requestedCurrencies = <int?>[];
  final refreshFlags = <bool>[];

  @override
  Future<Product> product(
    int id, {
    int? languageId,
    int? currencyId,
    bool forceRefresh = false,
  }) async {
    requestedCurrencies.add(currencyId);
    refreshFlags.add(forceRefresh);
    return _product(id, currencyId!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('clearing cart cancels an addition awaiting another currency', () async {
    final prefs = await SharedPreferences.getInstance();
    final loadStarted = Completer<void>();
    final productResponse = Completer<Product>();
    final requests = <(int, int?)>[];
    final notifier = CartNotifier(
      preferencesLoader: () async => prefs,
      productLoader: (id, currencyId) {
        requests.add((id, currencyId));
        loadStarted.complete();
        return productResponse.future;
      },
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    notifier.add(_product(1, 1));
    await notifier.flush();

    notifier.add(_product(2, 2));
    await loadStarted.future;
    expect(requests, [(2, 1)]);
    notifier.clear();
    productResponse.complete(_product(2, 1));
    await notifier.flush();

    expect(notifier.state, isEmpty);
    expect(jsonDecode(prefs.getString(CartNotifier.storageKey)!), isEmpty);
  });

  test('empty cart converts a stale product card to the selected currency',
      () async {
    final requests = <int?>[];
    final notifier = CartNotifier(
      productLoader: (id, currencyId) async {
        requests.add(currencyId);
        return _product(id, currencyId!);
      },
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    await notifier.refreshCurrency(2);

    // The previous MAD card can remain visible during a catalogue refresh.
    notifier.add(_product(42, 1));
    await notifier.flush();

    expect(requests, [2]);
    expect(notifier.state.single.product.currency, 'EUR');
    expect(notifier.state.single.product.price, 100);
  });

  test('cart honors currency selection loaded before provider initialization',
      () async {
    SharedPreferences.setMockInitialValues({
      CartNotifier.storageKey: jsonEncode([
        CartItem(product: _product(42, 1), quantity: 2).toJson(),
      ]),
    });
    final catalog = _CurrencyCatalogRepository();
    final container = ProviderContainer(
      overrides: [
        storeContextRepositoryProvider.overrideWithValue(
          _SelectedCurrencyRepository(),
        ),
        catalogRepositoryProvider.overrideWithValue(catalog),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedCurrencyIdProvider.notifier).ready;
    expect(container.read(selectedCurrencyIdProvider), 2);
    final notifier = container.read(cartProvider.notifier);
    await notifier.flush();

    expect(container.read(cartProvider).single.product.currency, 'EUR');
    expect(container.read(cartProvider).single.quantity, 2);
    expect(catalog.requestedCurrencies, [2]);
    expect(catalog.refreshFlags, [true]);
  });

  test('disposed currency refresh cannot overwrite a newer persisted cart',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final loadStarted = Completer<void>();
    final productResponse = Completer<Product>();
    final previous = CartNotifier(
      preferencesLoader: () async => prefs,
      productLoader: (_, __) {
        loadStarted.complete();
        return productResponse.future;
      },
    );
    await previous.ready;
    previous.add(_product(1, 1));
    await previous.flush();

    final refresh = previous.refreshCurrency(2);
    await loadStarted.future;
    previous.dispose();
    final current = CartNotifier(preferencesLoader: () async => prefs);
    addTearDown(current.dispose);
    await current.ready;
    current.clear();
    current.add(_product(9, 1));
    await current.flush();

    productResponse.complete(_product(1, 2));
    await refresh;
    await previous.flush();
    final stored =
        jsonDecode(prefs.getString(CartNotifier.storageKey)!) as List;
    final item = CartItem.fromJson(Map<String, dynamic>.from(stored.single));
    expect(item.product.id, 9);
    expect(item.product.currency, 'MAD');
  });

  test('disposed hydration cannot overwrite a newer persisted cart', () async {
    final prefs = await SharedPreferences.getInstance();
    final delayedPreferences = Completer<SharedPreferences>();
    final previous = CartNotifier(
      preferencesLoader: () => delayedPreferences.future,
    );
    previous.add(_product(1, 1));
    previous.dispose();

    final current = CartNotifier(preferencesLoader: () async => prefs);
    addTearDown(current.dispose);
    await current.ready;
    current.add(_product(9, 1));
    await current.flush();

    delayedPreferences.complete(prefs);
    await previous.ready;
    await previous.flush();
    final stored =
        jsonDecode(prefs.getString(CartNotifier.storageKey)!) as List;
    final item = CartItem.fromJson(Map<String, dynamic>.from(stored.single));
    expect(item.product.id, 9);
  });
}
