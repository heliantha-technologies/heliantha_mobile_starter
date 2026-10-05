import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/cart/domain/cart_item.dart';
import 'package:heliantha_mobile/features/cart/providers/cart_provider.dart';
import 'package:heliantha_mobile/shared/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

Product _product(int id, {int currencyId = 1, double price = 100}) => Product(
      id: id,
      name: 'Panneau solaire $id',
      price: price,
      currency: currencyId == 1 ? 'MAD' : 'EUR',
      currencySymbol: currencyId == 1 ? 'DH' : '€',
      currencyId: currencyId,
      available: true,
      quantity: 12,
      imageUrl: 'https://example.com/panel-$id.jpg',
      features: const [ProductFeature(name: 'Puissance', value: '450 W')],
    );

String _saved(List<CartItem> items) =>
    jsonEncode([for (final item in items) item.toJson()]);

List<CartItem> _readSaved(SharedPreferences prefs) => [
      for (final row in jsonDecode(prefs.getString(CartNotifier.storageKey)!))
        CartItem.fromJson(Map<String, dynamic>.from(row as Map)),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Restaure produits, quantités et devise après un redémarrage', () async {
    SharedPreferences.setMockInitialValues({
      CartNotifier.storageKey: _saved([
        CartItem(product: _product(42, currencyId: 2, price: 85), quantity: 3),
      ]),
    });
    final notifier = CartNotifier();
    addTearDown(notifier.dispose);
    await notifier.ready;

    final item = notifier.state.single;
    expect(item.product.id, 42);
    expect(item.quantity, 3);
    expect(item.total, 255);
    expect(notifier.currencyId, 2);
    expect(item.product.currency, 'EUR');
    expect(item.product.imageUrl, 'https://example.com/panel-42.jpg');
    expect(item.product.features.single.value, '450 W');
    await notifier.flush();
  });

  test('Chaque mutation est conservée dans le panier suivant', () async {
    final notifier = CartNotifier();
    await notifier.ready;
    notifier.addItem(_product(1));
    notifier.addItem(_product(1));
    notifier.add(_product(2));
    notifier.updateQuantity(1, 5);
    notifier.decrement(1);
    notifier.removeItem(2);
    await notifier.flush();
    notifier.dispose();

    final restored = CartNotifier();
    await restored.ready;
    expect(restored.state.single.product.id, 1);
    expect(restored.state.single.quantity, 4);
    restored.clear();
    await restored.flush();
    restored.dispose();

    final empty = CartNotifier();
    addTearDown(empty.dispose);
    await empty.ready;
    expect(empty.state, isEmpty);
    await empty.flush();
  });

  test('Rejoue les actions effectuées pendant la restauration', () async {
    SharedPreferences.setMockInitialValues({
      CartNotifier.storageKey: _saved([
        CartItem(product: _product(1), quantity: 3),
        CartItem(product: _product(2), quantity: 2),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final loader = Completer<SharedPreferences>();
    final notifier = CartNotifier(preferencesLoader: () => loader.future);
    addTearDown(notifier.dispose);
    notifier.addItem(_product(1));
    notifier.remove(2);
    notifier.addItem(_product(3));
    notifier.updateQuantity(1, 6);
    loader.complete(prefs);
    await notifier.flush();

    expect(notifier.state.map((item) => item.product.id), [1, 3]);
    expect(notifier.state.first.quantity, 6);
    expect(_readSaved(prefs).first.quantity, 6);
  });

  test(
      'Vider le panier pendant la restauration efface aussi les articles sauvegardés',
      () async {
    SharedPreferences.setMockInitialValues({
      CartNotifier.storageKey: _saved([
        CartItem(product: _product(1), quantity: 3),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final loader = Completer<SharedPreferences>();
    final notifier = CartNotifier(preferencesLoader: () => loader.future);
    addTearDown(notifier.dispose);
    notifier.clear();
    loader.complete(prefs);
    await notifier.flush();

    expect(notifier.state, isEmpty);
    expect(_readSaved(prefs), isEmpty);
  });

  test('Une ligne endommagée ne supprime pas les autres articles', () async {
    SharedPreferences.setMockInitialValues({
      CartNotifier.storageKey: jsonEncode([
        CartItem(product: _product(1), quantity: 2).toJson(),
        {
          'quantity': 0,
          'product': {'id': 4}
        },
        'ligne endommagée',
        CartItem(product: _product(2), quantity: 1).toJson(),
      ]),
    });
    final notifier = CartNotifier();
    addTearDown(notifier.dispose);
    await notifier.flush();
    expect(notifier.state.map((item) => item.product.id), [1, 2]);
  });

  test('Un JSON illisible ne bloque pas les nouveaux achats', () async {
    SharedPreferences.setMockInitialValues({
      CartNotifier.storageKey: '{invalid JSON',
    });
    final notifier = CartNotifier();
    addTearDown(notifier.dispose);
    notifier.addItem(_product(7));
    await notifier.flush();
    expect(notifier.state.single.product.id, 7);
    final prefs = await SharedPreferences.getInstance();
    expect(_readSaved(prefs).single.product.id, 7);
  });

  test(
      'La destruction pendant la restauration ne réécrit pas un panier obsolète',
      () async {
    SharedPreferences.setMockInitialValues({
      CartNotifier.storageKey: _saved([
        CartItem(product: _product(1), quantity: 3),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final loader = Completer<SharedPreferences>();
    final notifier = CartNotifier(preferencesLoader: () => loader.future);
    notifier.addItem(_product(1));
    notifier.dispose();
    loader.complete(prefs);
    await notifier.flush();

    expect(_readSaved(prefs).single.quantity, 3);
  });

  test(
      'Le changement de devise est atomique et respecte les dernières quantités',
      () async {
    final first = Completer<Product>();
    final second = Completer<Product>();
    final notifier = CartNotifier(
      productLoader: (id, currencyId) {
        expect(currencyId, 2);
        return id == 1 ? first.future : second.future;
      },
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    notifier.add(_product(1));
    notifier.add(_product(2));
    final refresh = notifier.refreshCurrency(2);
    await Future<void>.delayed(Duration.zero);
    notifier.updateQuantity(1, 4);
    first.complete(_product(1, currencyId: 2, price: 10));
    await Future<void>.delayed(Duration.zero);
    expect(
        notifier.state.every((item) => item.product.currency == 'MAD'), isTrue);
    notifier.remove(2);
    second.complete(_product(2, currencyId: 2, price: 20));
    await refresh;
    await notifier.flush();

    expect(notifier.state.single.product.currency, 'EUR');
    expect(notifier.state.single.quantity, 4);
    expect(notifier.state.single.total, 40);
    final prefs = await SharedPreferences.getInstance();
    expect(_readSaved(prefs).single.product.currencyId, 2);
  });

  test(
      'Un échec de conversion conserve toutes les lignes dans leur devise initiale',
      () async {
    final first = Completer<Product>();
    final second = Completer<Product>();
    final notifier = CartNotifier(
      productLoader: (id, _) => id == 1 ? first.future : second.future,
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    notifier.add(_product(1, price: 100));
    notifier.add(_product(2, price: 200));
    final refresh = notifier.refreshCurrency(2);
    final failure = expectLater(refresh, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    first.complete(_product(1, currencyId: 2, price: 10));
    second.completeError(StateError('Price unavailable'));
    await failure;
    await notifier.flush();

    expect(notifier.state.map((item) => item.product.price), [100, 200]);
    expect(
        notifier.state.every((item) => item.product.currency == 'MAD'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(_readSaved(prefs).every((item) => item.product.currencyId == 1),
        isTrue);
  });

  test(
      'Ajouter un produit dans une autre devise utilise le prix de la devise du panier',
      () async {
    final loads = <int?>[];
    final notifier = CartNotifier(
      productLoader: (id, currencyId) async {
        loads.add(currencyId);
        return _product(id, currencyId: currencyId!, price: 250);
      },
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    notifier.add(_product(1));
    notifier.add(_product(2, currencyId: 2, price: 25));
    await notifier.flush();

    expect(loads, [1]);
    expect(notifier.state.map((item) => item.product.currencyId), [1, 1]);
    expect(notifier.state.last.product.price, 250);
  });
}
