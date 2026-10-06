import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_api_service.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_reply.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart';

const _product = {
  'id': 2,
  'name': 'Panneau solaire 590 Wc',
  'reference': 'CS6W-590TB-AG',
  'description': '590 Wc',
  'price': 1135.20,
  'currency': 'DH',
  'price_tax': 'HT',
  'en_stock': true,
  'source': 'local_sqlite',
  'datasheet_url': 'https://example.com/panel.pdf',
};

AssistantApiService _service(dynamic response, {int statusCode = 200}) {
  final dio = Dio();
  addTearDown(() => dio.close(force: true));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
    handler.resolve(Response(
      requestOptions: request,
      statusCode: statusCode,
      data: response,
    ));
  }));
  return AssistantApiService(dio: dio);
}

AssistantApiService _errorService(DioExceptionType type, {int? statusCode}) {
  final dio = Dio();
  addTearDown(() => dio.close(force: true));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
    handler.reject(DioException(
      requestOptions: request,
      type: type,
      response: statusCode == null
          ? null
          : Response(
              requestOptions: request,
              statusCode: statusCode,
              data: 'Traceback in private_server_file.py',
            ),
    ));
  }));
  return AssistantApiService(dio: dio);
}

void main() {
  test('structured reply preserves catalogue facts and the official quote',
      () async {
    final service = _service(jsonEncode({
      'content': 'Votre sélection.',
      'suggested_products': [_product],
      'devis': {'reference': 'H-TEST', 'total_ttc': 12000},
    }));
    final reply = await service.sendReply(history: [
      {'role': 'user', 'content': 'Je souhaite des panneaux'}
    ]);

    expect(reply.suggestedProducts, hasLength(1));
    expect(reply.offerWhatsApp, isFalse);
    final product = reply.suggestedProducts.single;
    expect(product.name, 'Panneau solaire 590 Wc');
    expect(product.localId, '2');
    expect(product.reference, 'CS6W-590TB-AG');
    expect(product.price, 1135.20);
    expect(product.priceTax, 'HT');
    expect(product.inStock, isTrue);
    expect(product.datasheetUri?.scheme, 'https');
    final parsed = ChatDevisData.extract(reply.text);
    expect(parsed.cleanedText, 'Votre sélection.');
    expect(parsed.devisData?.reference, 'H-TEST');
    expect(parsed.devisData?.totalTtc, 12000);
  });

  test('text callers and quote-only replies retain the previous contract',
      () async {
    final quote = await _service({
      'quote': {'reference': 'H-LEGACY', 'total_ttc': 5000},
    }).sendMessage(history: [
      {'role': 'user', 'content': 'Devis'}
    ]);
    expect(ChatDevisData.extract(quote).devisData?.reference, 'H-LEGACY');
    final text = await _service('Conseil en texte brut.').sendReply(history: [
      {'role': 'user', 'content': 'Bonjour'}
    ]);
    expect(text.text, 'Conseil en texte brut.');
    expect(text.suggestedProducts, isEmpty);
  });

  test('product-only and malformed suggestions do not hide a valid response',
      () async {
    final reply = await _service({
      'suggested_products': [
        null,
        'invalid',
        {'price': 10},
        _product
      ],
    }).sendReply(history: [
      {'role': 'user', 'content': 'Produits'}
    ]);
    expect(reply.text, contains('produits'));
    expect(reply.suggestedProducts, hasLength(1));
    final text = await _service({
      'content': 'Réponse sans fiche.',
      'suggested_products': 'not a list',
    }).sendReply(history: [
      {'role': 'user', 'content': 'Bonjour'}
    ]);
    expect(text.text, 'Réponse sans fiche.');
    expect(text.suggestedProducts, isEmpty);
  });

  test(
      'missing stock and invalid prices stay unconfirmed; unsafe links ignored',
      () {
    final product = AssistantProduct.fromJson({
      'name': 'Panneau',
      'price': '-1',
      'datasheet_url': 'javascript:alert(1)',
    })!;
    expect(product.price, isNull);
    expect(product.inStock, isNull);
    expect(product.datasheetUri, isNull);
    final valid = AssistantProduct.fromJson({
      'name': 'Panneau',
      'price': '1 135,20',
      'currency': 'MAD',
      'en_stock': 'false',
    })!;
    expect(valid.price, 1135.20);
    expect(valid.currency, 'DH');
    expect(valid.inStock, isFalse);
  });

  test('server and connection failures offer a short WhatsApp fallback',
      () async {
    for (final type in [
      DioExceptionType.badResponse,
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      final reply = await _errorService(type,
              statusCode: type == DioExceptionType.badResponse ? 500 : null)
          .sendReply(history: [
        {'role': 'user', 'content': 'Bonjour'}
      ]);
      expect(reply.offerWhatsApp, isTrue);
      expect(reply.text, AssistantReply.unavailable.text);
      expect(reply.text, isNot(contains('Traceback')));
      expect(reply.suggestedProducts, isEmpty);
    }
    final legacyText =
        await _service('Internal server details', statusCode: 500)
            .sendMessage(history: [
      {'role': 'user', 'content': 'Bonjour'}
    ]);
    expect(legacyText, AssistantReply.unavailable.text);
  });

  test('429 keeps the patience message without a WhatsApp action', () async {
    final reply =
        await _errorService(DioExceptionType.badResponse, statusCode: 429)
            .sendReply(history: [
      {'role': 'user', 'content': 'Bonjour'}
    ]);
    expect(reply.offerWhatsApp, isFalse);
    expect(reply.text, contains('patienter quelques instants'));
    expect(reply.text, isNot(contains('Traceback')));
  });

  test('unusable response bodies offer the same fallback', () async {
    for (final raw in [
      '',
      '{"content":',
      '<html>Server error</html>',
      {
        'content': {'error': 'Internal details'}
      },
      <String>[],
    ]) {
      final reply = await _service(raw).sendReply(history: [
        {'role': 'user', 'content': 'Bonjour'}
      ]);
      expect(reply.offerWhatsApp, isTrue);
      expect(reply.text, AssistantReply.unavailable.text);
    }
  });

  test('only an explicit backend flag offers WhatsApp on a successful reply',
      () async {
    for (final flag in [null, false, 'true', true]) {
      final reply = await _service({
        'content': 'Vous pouvez aussi contacter un conseiller sur WhatsApp.',
        'offer_whatsapp': flag,
        'suggested_products': [_product],
      }).sendReply(history: [
        {'role': 'user', 'content': 'Bonjour'}
      ]);
      expect(reply.offerWhatsApp, flag == true);
      expect(reply.suggestedProducts, hasLength(1));
    }
  });
}
