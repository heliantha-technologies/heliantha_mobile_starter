import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/cart/presentation/cart_screen.dart';
import 'package:heliantha_mobile/features/cart/providers/cart_provider.dart';
import 'package:heliantha_mobile/shared/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('vider le panier demande confirmation et efface le panier local',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cart = CartNotifier();
    await cart.ready;
    cart.add(const Product(
      id: 42,
      name: 'Panneau solaire',
      price: 1500,
      currency: 'MAD',
      currencySymbol: 'DH',
      currencyId: 1,
      available: true,
    ));
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) async => null),
      cartProvider.overrideWith((ref) => cart),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CartScreen()),
    ));
    await tester.pump();

    await tester.tap(find.text('Vider le panier'));
    await tester.pumpAndSettle();
    expect(find.text('Vider le panier ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(container.read(cartProvider), hasLength(1));

    await tester.tap(find.text('Vider le panier'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Vider le panier'),
    ));
    await tester.pumpAndSettle();
    await cart.flush();

    expect(container.read(cartProvider), isEmpty);
    expect(find.text('Votre panier est vide'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(CartNotifier.storageKey), '[]');
    expect(tester.takeException(), isNull);
  });
}
