import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/cart/providers/cart_provider.dart';
import 'package:heliantha_mobile/features/catalog/providers/store_context_provider.dart';
import 'package:heliantha_mobile/features/checkout/data/checkout_repository.dart';
import 'package:heliantha_mobile/features/checkout/domain/checkout_models.dart';
import 'package:heliantha_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:heliantha_mobile/features/checkout/providers/checkout_provider.dart';
import 'package:heliantha_mobile/shared/models/product.dart';
import 'package:heliantha_mobile/shared/models/store_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingCheckoutRepository implements CheckoutRepository {
  final requests = <Completer<CheckoutConfirmResult>>[];
  final keys = <String>[];

  @override
  Future<CheckoutPreview> preview({
    required List<CheckoutLineRequest> lines,
    int? currencyId,
    int? languageId,
    int? carrierId,
    int? addressId,
  }) async =>
      CheckoutPreview.fromJson({
        'lines': [],
        'totals': {'currency': 'MAD', 'total_ttc': 1500},
        'carriers': [],
        'payments': [
          {'module': 'ps_cashondelivery', 'name': 'Paiement à la livraison'}
        ],
        'stock_ok': true,
        'write_enabled': true,
      });

  @override
  Future<CheckoutConfirmResult> confirm({
    required List<CheckoutLineRequest> lines,
    required String mode,
    required String idempotencyKey,
    int? currencyId,
    int? languageId,
    Map<String, dynamic>? guest,
    Map<String, dynamic>? address,
    int? addressId,
    int? carrierId,
    String? paymentModule,
  }) {
    keys.add(idempotencyKey);
    final request = Completer<CheckoutConfirmResult>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('checkout blocks rapid taps, unlocks after failure and confirms once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _PendingCheckoutRepository();
    const product = Product(
      id: 42,
      name: 'Panneau solaire',
      price: 1500,
      currency: 'MAD',
      currencySymbol: 'DH',
      currencyId: 1,
      available: true,
    );
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) async => null),
      checkoutRepositoryProvider.overrideWithValue(repository),
      storeContextProvider.overrideWith((ref) async => const StoreContext(
            defaultLanguageId: 1,
            languages: [],
            defaultCurrencyId: 1,
            currencies: [],
          )),
      cartProvider.overrideWith((ref) => CartNotifier(
            productLoader: (_, __) async => product,
          )..add(product)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CheckoutScreen()),
    ));
    await tester.pumpAndSettle();
    for (final entry in {
      'Prénom': 'Sara',
      'Nom': 'Test',
      'E-mail': 'sara@example.test',
      'Adresse': '12 rue du Soleil',
      'Ville': 'Rabat',
    }.entries) {
      final field = find.widgetWithText(TextFormField, entry.key);
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
    tester.testTextInput.hide();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    final confirmAction = find.widgetWithText(FilledButton, 'Confirmer la commande');
    await tester.ensureVisible(confirmAction);
    final submit = tester.widget<FilledButton>(confirmAction).onPressed!;
    submit();
    submit();
    await tester.pump();
    expect(repository.requests, hasLength(1));
    final loadingAction =
        find.widgetWithText(FilledButton, 'Confirmation en cours...');
    expect(tester.widget<FilledButton>(loadingAction).onPressed, isNull);
    expect(
      find.descendant(
        of: loadingAction,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    repository.requests.single.completeError(StateError('network interrupted'));
    await tester.pumpAndSettle();
    final retry = tester.widget<FilledButton>(confirmAction).onPressed!;
    expect(container.read(cartProvider), isNotEmpty);
    retry();
    retry();
    await tester.pump();
    expect(repository.requests, hasLength(2));
    expect(repository.keys[1], repository.keys[0]);
    repository.requests.last.complete(const CheckoutConfirmResult(
      orderId: 77,
      reference: 'SAFE-77',
      total: 1500,
      currency: 'MAD',
    ));
    await tester.pumpAndSettle();
    expect(find.byType(OrderSuccessDialog), findsOneWidget);
    expect(container.read(cartProvider), isEmpty);
    expect(repository.requests, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
