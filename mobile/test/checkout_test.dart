import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heliantha_mobile/core/api/api_client.dart';
import 'package:heliantha_mobile/core/storage/token_storage.dart';
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

const _products = [
  Product(
    id: 1,
    name: 'Panneau 1',
    price: 100,
    currency: 'MAD',
    currencySymbol: 'DH',
    currencyId: 1,
    available: true,
  ),
  Product(
    id: 2,
    name: 'Panneau 2',
    price: 200,
    currency: 'MAD',
    currencySymbol: 'DH',
    currencyId: 1,
    available: true,
  ),
  Product(
    id: 3,
    name: 'Panneau 3',
    price: 300,
    currency: 'MAD',
    currencySymbol: 'DH',
    currencyId: 1,
    available: true,
  ),
  Product(
    id: 4,
    name: 'Panneau 4',
    price: 400,
    currency: 'MAD',
    currencySymbol: 'DH',
    currencyId: 1,
    available: true,
  ),
  Product(
    id: 5,
    name: 'Panneau 5',
    price: 500,
    currency: 'MAD',
    currencySymbol: 'DH',
    currencyId: 1,
    available: true,
  ),
];

CheckoutPreview _preview({int carrierId = 1, double total = 1500}) =>
    CheckoutPreview(
      lines: [
        for (final product in _products)
          CheckoutLine(
            productId: product.id,
            name: product.name,
            quantity: 1,
            unitPrice: product.price,
            total: product.price,
            currency: 'MAD',
            currencySymbol: 'DH',
            available: true,
            stockQuantity: 10,
          ),
      ],
      totals: CheckoutTotals(
        subtotal: total,
        shippingLabel: 'Gratuit',
        discounts: 0,
        totalTtc: total,
        currency: 'MAD',
        currencySymbol: 'DH',
      ),
      carriers: const [
        CheckoutCarrier(id: 1, name: 'Transporteur 1'),
        CheckoutCarrier(id: 2, name: 'Transporteur 2'),
        CheckoutCarrier(id: 3, name: 'Transporteur 3'),
        CheckoutCarrier(id: 4, name: 'Transporteur 4'),
      ],
      payments: const [CheckoutPayment(module: 'wire', name: 'Virement')],
      selectedCarrierId: carrierId,
      stockOk: true,
      writeEnabled: true,
      bridgeRequired: const [],
    );

class _PreviewCall {
  _PreviewCall(this.carrierId, this.cancelToken);

  final int? carrierId;
  final CancelToken? cancelToken;
  final Completer<CheckoutPreview> response = Completer<CheckoutPreview>();
}

class _ControlledCheckoutRepository extends CheckoutRepository {
  _ControlledCheckoutRepository() : super(ApiClient(_MemoryTokenStorage()));

  final calls = <_PreviewCall>[];
  int canceled = 0;

  @override
  Future<CheckoutPreview> preview({
    required List<CheckoutLineRequest> lines,
    int? currencyId,
    int? languageId,
    int? carrierId,
    int? addressId,
    CancelToken? cancelToken,
  }) {
    expect(lines.map((line) => line.productId), [1, 2, 3, 4, 5]);
    final call = _PreviewCall(carrierId, cancelToken);
    calls.add(call);
    cancelToken?.whenCancel.then((_) => canceled++);
    if (carrierId == null) return Future.value(_preview());
    return call.response.future;
  }
}

class _MemoryTokenStorage extends TokenStorage {
  @override
  Future<String?> read() async => null;
}

Future<({ProviderContainer container, GoRouter router})> _mount(
  WidgetTester tester,
  _ControlledCheckoutRepository repository, {
  required void Function() onProductLoad,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});

  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWith((ref) async => null),
    storeContextProvider.overrideWith((ref) async => const StoreContext(
          defaultLanguageId: 3,
          languages: [],
          defaultCurrencyId: 1,
          currencies: [
            StoreCurrency(
              id: 1,
              name: 'Dirham',
              isoCode: 'MAD',
              symbol: 'DH',
              precision: 2,
              conversionRate: 1,
              active: true,
            ),
          ],
        )),
    checkoutRepositoryProvider.overrideWithValue(repository),
    cartProvider.overrideWith((ref) {
      final notifier = CartNotifier(
        productLoader: (id, currencyId) async {
          onProductLoad();
          return _products.firstWhere((product) => product.id == id);
        },
      );
      for (final product in _products) {
        notifier.add(product);
      }
      return notifier;
    }),
  ]);
  final router = GoRouter(
    initialLocation: '/checkout',
    routes: [
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      for (final path in ['/', '/cart', '/catalog', '/orders'])
        GoRoute(path: path, builder: (_, __) => const Scaffold()),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  return (container: container, router: router);
}

Future<void> _tapCarrier(WidgetTester tester, String label) async {
  final carrier = find.text(label);
  await tester.ensureVisible(carrier);
  await tester.pump();
  await tester.tap(carrier);
  await tester.pump();
}

void main() {
  testWidgets(
      'checkout opens with one grouped preview and no per-product refresh',
      (tester) async {
    final repository = _ControlledCheckoutRepository();
    var productLoads = 0;
    await _mount(
      tester,
      repository,
      onProductLoad: () => productLoads++,
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.carrierId, isNull);
    expect(productLoads, 0);
    expect(find.text('Récapitulatif'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid carrier changes cancel obsolete previews and keep latest',
      (tester) async {
    final repository = _ControlledCheckoutRepository();
    await _mount(tester, repository, onProductLoad: () {});
    await tester.pump(const Duration(milliseconds: 350));

    await _tapCarrier(tester, 'Transporteur 2');
    await tester.pump(const Duration(milliseconds: 300));
    await _tapCarrier(tester, 'Transporteur 3');
    await tester.pump(const Duration(milliseconds: 300));
    await _tapCarrier(tester, 'Transporteur 4');
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.calls.map((call) => call.carrierId), [null, 2, 3, 4]);
    expect(repository.canceled, 2);
    expect(find.text('Transporteur 4'), findsOneWidget);

    repository.calls[3].response.complete(_preview(carrierId: 4, total: 444));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    repository.calls[1].response.complete(_preview(carrierId: 2, total: 222));
    repository.calls[2].response.complete(_preview(carrierId: 3, total: 333));
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.textContaining('444'), findsNWidgets(2));
    expect(find.textContaining('222'), findsNothing);
    expect(find.textContaining('333'), findsNothing);
    expect(repository.canceled, 2);
    expect(tester.takeException(), isNull);
  });
}
