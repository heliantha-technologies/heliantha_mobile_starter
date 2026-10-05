import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/product.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../catalog/providers/store_context_provider.dart';
import '../domain/cart_item.dart';

typedef CartProductLoader = Future<Product> Function(int id, int? currencyId);
typedef _CartMutation = List<CartItem> Function(List<CartItem> items);

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier({
    Future<SharedPreferences> Function()? preferencesLoader,
    CartProductLoader? productLoader,
    void Function(AsyncValue<void>)? onSyncState,
  })  : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        _productLoader = productLoader,
        _onSyncState = onSyncState,
        super(const []) {
    ready = _hydrate();
  }

  static const storageKey = 'heliantha_persistent_cart_v1';
  final Future<SharedPreferences> Function() _preferencesLoader;
  final CartProductLoader? _productLoader;
  final void Function(AsyncValue<void>)? _onSyncState;
  final List<_CartMutation> _beforeHydration = [];
  List<CartItem> _current = const [];
  SharedPreferences? _preferences;
  bool _hydrated = false;
  int? _desiredCurrencyId;
  int _pendingSyncs = 0;
  int _clearVersion = 0;
  Future<void> _writes = Future.value();
  Future<void> _syncs = Future.value();

  /// Completes after restoration, including actions made during startup.
  late final Future<void> ready;

  int? get currencyId =>
      _current.isEmpty ? _desiredCurrencyId : _current.first.product.currencyId;

  Future<void> _hydrate() async {
    var restored = <CartItem>[];
    try {
      _preferences = await _preferencesLoader();
      if (!mounted) return;
      final saved = _preferences!.getString(storageKey);
      if (saved != null) {
        final decoded = jsonDecode(saved);
        final rows = decoded is List ? decoded : decoded['items'] as List;
        for (final row in rows) {
          try {
            final item =
                CartItem.fromJson(Map<String, dynamic>.from(row as Map));
            // A saved total must never mix currencies, even after corruption.
            if (restored.isNotEmpty &&
                !_sameCurrency(restored.first.product, item.product)) {
              continue;
            }
            final index =
                restored.indexWhere((x) => x.product.id == item.product.id);
            if (index < 0) {
              restored.add(item);
            } else {
              restored[index] = item.copyWith(
                quantity: restored[index].quantity + item.quantity,
              );
            }
          } catch (_) {
            // Keep valid rows when just one stored item is damaged.
          }
        }
      }
    } catch (_) {
      // Local storage failure must not make shopping unavailable.
    }
    if (!mounted) return;
    for (final mutation in _beforeHydration) {
      restored = mutation(restored);
    }
    _beforeHydration.clear();
    _hydrated = true;
    _publish(restored);
    _save();
  }

  bool _sameCurrency(Product a, Product b) =>
      a.currency == b.currency &&
      (a.currencyId == null ||
          b.currencyId == null ||
          a.currencyId == b.currencyId);

  void _publish(List<CartItem> items) {
    _current = List.unmodifiable(items);
    if (mounted) state = _current;
  }

  void _mutate(_CartMutation mutation) {
    if (!_hydrated) _beforeHydration.add(mutation);
    _publish(mutation(_current));
    if (_hydrated) _save();
  }

  void _save() {
    final prefs = _preferences;
    if (prefs == null) return;
    final encoded = jsonEncode([for (final item in _current) item.toJson()]);
    // Serialized writes prevent an older quantity from overwriting the newest.
    _writes = _writes.then((_) async {
      await prefs.setString(storageKey, encoded);
    }).catchError((Object _) {});
  }

  void add(Product product) {
    if ((_desiredCurrencyId != null &&
            product.currencyId != _desiredCurrencyId) ||
        (_current.isNotEmpty &&
            !_sameCurrency(_current.first.product, product))) {
      _queueAdd(product);
      return;
    }
    _add(product);
  }

  void addItem(Product product) => add(product);

  void _add(Product product) {
    _mutate((items) {
      final index = items.indexWhere((x) => x.product.id == product.id);
      if (index >= 0) {
        final copy = [...items];
        copy[index] = copy[index].copyWith(quantity: copy[index].quantity + 1);
        return copy;
      }
      // An add before hydration can meet a restored cart in another currency.
      if (items.isNotEmpty && !_sameCurrency(items.first.product, product)) {
        _queueAdd(product);
        return items;
      }
      return [...items, CartItem(product: product, quantity: 1)];
    });
  }

  void _queueAdd(Product product) {
    final version = _clearVersion;
    unawaited(_queueSync(() => _addInCartCurrency(product, version))
        .catchError((Object _) {}));
  }

  Future<void> _addInCartCurrency(Product product, int version) async {
    await ready;
    if (!mounted || version != _clearVersion) return;
    await _refreshProducts(force: false);
    if (!mounted || version != _clearVersion) return;
    final target = _desiredCurrencyId ?? currencyId ?? product.currencyId;
    if ((target == null || product.currencyId == target) &&
        (_current.isEmpty || _sameCurrency(_current.first.product, product))) {
      _add(product);
      return;
    }
    final loader = _productLoader;
    if (loader == null || target == null) {
      throw StateError('Cart currency cannot be refreshed');
    }
    final refreshed = await loader(product.id, target);
    if (!mounted || version != _clearVersion) return;
    if (target != (_desiredCurrencyId ?? currencyId ?? product.currencyId)) {
      return _addInCartCurrency(product, version);
    }
    if (refreshed.currencyId != target ||
        (_current.isNotEmpty &&
            !_sameCurrency(_current.first.product, refreshed))) {
      throw StateError('Unexpected product currency');
    }
    _add(refreshed);
  }

  void updateQuantity(int productId, int quantity) {
    _mutate((items) => [
          for (final item in items)
            if (item.product.id != productId)
              item
            else if (quantity > 0)
              item.copyWith(quantity: quantity),
        ]);
  }

  void decrement(int productId) {
    _mutate((items) => [
          for (final item in items)
            if (item.product.id != productId)
              item
            else if (item.quantity > 1)
              item.copyWith(quantity: item.quantity - 1),
        ]);
  }

  void remove(int productId) => _mutate(
      (items) => items.where((x) => x.product.id != productId).toList());

  void removeItem(int productId) => remove(productId);

  void clear() {
    _clearVersion++;
    _mutate((_) => const []);
    if (mounted && _pendingSyncs == 0) {
      _onSyncState?.call(const AsyncData(null));
    }
  }

  /// Reprices all lines atomically; their latest quantities are preserved.
  Future<void> refreshCurrency(int? id, {bool force = false}) {
    _desiredCurrencyId = id;
    return _queueSync(() => _refreshProducts(force: force));
  }

  Future<void> _queueSync(Future<void> Function() operation) {
    _pendingSyncs++;
    if (mounted) _onSyncState?.call(const AsyncLoading());
    final next = _syncs.then((_) => operation());
    _syncs = next.then((_) {
      _pendingSyncs--;
      if (mounted && _pendingSyncs == 0) {
        _onSyncState?.call(const AsyncData(null));
      }
    }, onError: (Object error, StackTrace stack) {
      _pendingSyncs--;
      if (mounted) _onSyncState?.call(AsyncError(error, stack));
    });
    return next;
  }

  Future<void> _refreshProducts({required bool force}) async {
    await ready;
    final loader = _productLoader;
    while (mounted && _current.isNotEmpty) {
      final target = _desiredCurrencyId ?? currencyId;
      if (loader == null || target == null) return;
      if (!force &&
          _current.every((item) => item.product.currencyId == target)) {
        return;
      }
      final ids = _current.map((item) => item.product.id).toSet();
      final products =
          await Future.wait([for (final id in ids) loader(id, target)]);
      if (!mounted) return;
      if (target != (_desiredCurrencyId ?? currencyId)) continue;
      final byId = {for (final product in products) product.id: product};
      if (_current.any((item) => !byId.containsKey(item.product.id))) continue;
      if (products.any((product) => product.currencyId != target) ||
          products.any((product) => !_sameCurrency(products.first, product))) {
        throw StateError('Unexpected product currency');
      }
      _publish([
        for (final item in _current)
          item.copyWith(product: byId[item.product.id])
      ]);
      _save();
      return;
    }
  }

  /// Useful when a lifecycle boundary needs durable storage.
  Future<void> flush() async {
    await ready;
    await _syncs;
    await _writes;
  }
}

final cartSyncStateProvider = StateProvider<AsyncValue<void>>(
  (ref) => const AsyncData(null),
);

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final notifier = CartNotifier(
    productLoader: (id, currencyId) =>
        ref.read(catalogRepositoryProvider).product(
              id,
              currencyId: currencyId,
              languageId: ref.read(selectedLanguageIdProvider),
              forceRefresh: true,
            ),
    onSyncState: (value) =>
        ref.read(cartSyncStateProvider.notifier).state = value,
  );
  ref.listen<int?>(selectedCurrencyIdProvider, (_, next) {
    if (next != null) {
      unawaited(notifier.refreshCurrency(next).catchError((Object _) {}));
    }
  });
  final selectedCurrencyId = ref.read(selectedCurrencyIdProvider);
  if (selectedCurrencyId != null) {
    unawaited(Future<void>.microtask(
            () => notifier.refreshCurrency(selectedCurrencyId))
        .catchError((Object _) {}));
  }
  return notifier;
});

final cartTotalProvider = Provider<double>(
  (ref) => ref.watch(cartProvider).fold(0, (sum, item) => sum + item.total),
);

final cartItemCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).fold(0, (sum, item) => sum + item.quantity),
);
