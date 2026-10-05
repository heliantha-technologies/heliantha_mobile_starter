import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/core/api/api_client.dart';
import 'package:heliantha_mobile/core/storage/token_storage.dart';
import 'package:heliantha_mobile/features/catalog/data/catalog_repository.dart';
import 'package:heliantha_mobile/features/checkout/data/checkout_repository.dart';
import 'package:heliantha_mobile/features/checkout/domain/checkout_models.dart';

ApiClient _fakeApi(
  List<RequestOptions> requests,
  Object Function(RequestOptions) responseData,
) {
  final api = ApiClient(TokenStorage());
  // Requests resolve locally before storage plugins or a network adapter run.
  api.dio.interceptors.clear();
  api.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    requests.add(options);
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: {'data': responseData(options)},
    ));
  }));
  addTearDown(() => api.dio.close(force: true));
  return api;
}

const _lines = [CheckoutLineRequest(productId: 42, quantity: 3)];

Map<String, Object> _productData(RequestOptions request, {bool detail = true}) {
  final currencyId = request.queryParameters['currency_id'] as int? ?? 1;
  final languageId = request.queryParameters['language_id'] as int? ?? 1;
  return {
    'id': 42,
    'name': 'Panneau $languageId',
    'price': currencyId == 1 ? 950 : 90,
    'currency': currencyId == 1 ? 'MAD' : 'EUR',
    'currency_id': currencyId,
    'available': true,
    if (detail) 'description': 'Description complète $languageId',
  };
}

void main() {
  test(
      'L’aperçu et la confirmation transmettent la même devise et la même langue',
      () async {
    final requests = <RequestOptions>[];
    final repository = CheckoutRepository(_fakeApi(requests, (request) {
      if (request.path.endsWith('/preview')) {
        return {
          'totals': {'currency': 'EUR', 'total_ttc': 270},
          'stock_ok': true,
        };
      }
      return {'order_id': 77, 'currency': 'EUR', 'total': 270};
    }));

    final preview = await repository.preview(
      lines: _lines,
      currencyId: 2,
      languageId: 1,
      addressId: 8,
    );
    final confirmation = await repository.confirm(
      lines: _lines,
      mode: 'guest',
      idempotencyKey: 'test-order-key',
      currencyId: 2,
      languageId: 1,
      guest: {'email': 'client@example.com'},
      address: {'city': 'Casablanca'},
    );

    expect(requests.map((request) => request.path), [
      '/v1/checkout/preview',
      '/v1/checkout/confirm',
    ]);
    for (final request in requests) {
      final body = request.data as Map;
      expect(body['currency_id'], 2);
      expect(body['language_id'], 1);
      expect((body['lines'] as List).single['product_id'], 42);
      expect((body['lines'] as List).single['quantity'], 3);
    }
    expect((requests.last.data as Map)['idempotency_key'], 'test-order-key');
    expect(preview.totals.currency, 'EUR');
    expect(confirmation.currency, 'EUR');
    expect(confirmation.orderId, 77);
  });

  test(
      'Les paramètres optionnels absents ne remplacent pas les valeurs par défaut du serveur',
      () async {
    final requests = <RequestOptions>[];
    final repository = CheckoutRepository(_fakeApi(requests, (_) => {}));
    await repository.preview(lines: _lines);
    await repository.confirm(
      lines: _lines,
      mode: 'customer',
      idempotencyKey: 'test-default-currency',
    );
    for (final request in requests) {
      final body = request.data as Map;
      expect(body.containsKey('currency_id'), isFalse);
      expect(body.containsKey('language_id'), isFalse);
    }
  });

  test(
      'Le cache des détails distingue devise et langue et autorise une actualisation',
      () async {
    final requests = <RequestOptions>[];
    final catalog = CatalogRepository(_fakeApi(requests, _productData));

    final mad = await catalog.product(42, currencyId: 1, languageId: 1);
    final eur = await catalog.product(42, currencyId: 2, languageId: 1);
    final translated = await catalog.product(42, currencyId: 2, languageId: 2);
    final cached = await catalog.product(42, currencyId: 1, languageId: 1);

    expect(mad.currency, 'MAD');
    expect(eur.currency, 'EUR');
    expect(translated.name, 'Panneau 2');
    expect(cached.price, 950);
    expect(requests.length, 3);

    await catalog.product(42, currencyId: 1, languageId: 1, forceRefresh: true);
    expect(requests.length, 4);
    expect(requests.last.queryParameters['currency_id'], 1);
    expect(requests.last.queryParameters['language_id'], 1);
  });

  test('Un résumé de catalogue ne remplace pas les détails complets du produit',
      () async {
    final requests = <RequestOptions>[];
    final catalog = CatalogRepository(_fakeApi(requests, (request) {
      if (request.path == '/v1/products') {
        return [_productData(request, detail: false)];
      }
      return _productData(request);
    }));

    final products = await catalog.products(currencyId: 1, languageId: 1);
    expect(products.single.description, isNull);
    final detail = await catalog.product(42, currencyId: 1, languageId: 1);
    expect(detail.description, 'Description complète 1');
    expect(requests.map((request) => request.path), [
      '/v1/products',
      '/v1/products/42',
    ]);
  });
}
