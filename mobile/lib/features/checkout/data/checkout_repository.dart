import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../domain/checkout_models.dart';

class CheckoutRepository {
  CheckoutRepository(this._api);

  final ApiClient _api;

  Future<CheckoutPreview> preview({
    required List<CheckoutLineRequest> lines,
    int? currencyId,
    int? languageId,
    int? carrierId,
    int? addressId,
  }) async {
    final response = await _api.dio.post(
      '/v1/checkout/preview',
      data: {
        'lines': [for (final line in lines) line.toJson()],
        if (currencyId != null) 'currency_id': currencyId,
        if (languageId != null) 'language_id': languageId,
        if (carrierId != null) 'carrier_id': carrierId,
        if (addressId != null) 'address_id': addressId,
      },
    );
    return CheckoutPreview.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

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
  }) async {
    final body = {
      'lines': [for (final line in lines) line.toJson()],
      'mode': mode,
      'idempotency_key': idempotencyKey,
      if (currencyId != null) 'currency_id': currencyId,
      if (languageId != null) 'language_id': languageId,
      if (guest != null) 'guest': guest,
      if (address != null) 'address': address,
      if (addressId != null) 'address_id': addressId,
      if (carrierId != null) 'carrier_id': carrierId,
      if (paymentModule != null) 'payment_module': paymentModule,
    };

    try {
      final response = await _api.dio.post('/v1/checkout/confirm', data: body);
      return CheckoutConfirmResult.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map? ?? const {}),
      );
    } on DioException catch (error) {
      final duplicate = _duplicateCheckoutResult(error);
      if (duplicate != null) {
        return duplicate;
      }
      rethrow;
    }
  }

  CheckoutConfirmResult? _duplicateCheckoutResult(DioException error) {
    if (error.response?.statusCode != 409) {
      return null;
    }
    final text = error.response?.data?.toString() ?? '';
    if (!text.contains('DUPLICATE_CHECKOUT')) {
      return null;
    }
    final match =
        RegExp(r'''['"]?order_id['"]?\s*:\s*(\d+)''').firstMatch(text);
    final orderId = int.tryParse(match?.group(1) ?? '');
    if (orderId == null) {
      return null;
    }
    return CheckoutConfirmResult(orderId: orderId);
  }
}
