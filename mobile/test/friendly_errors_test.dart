import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/shared/utils/friendly_errors.dart';

void main() {
  group('Security & Technical Leak Sanitizer (containsTechnicalLeak)', () {
    test('Détecte et bloque les balises HTML et pages d\'erreur 502/500', () {
      expect(
        containsTechnicalLeak(
          '<!DOCTYPE html><html><body>502 Bad Gateway</body></html>',
        ),
        isTrue,
      );
      expect(containsTechnicalLeak('<div>Internal Server Error</div>'), isTrue);
    });

    test('Détecte et bloque les exceptions et traces techniques', () {
      expect(
        containsTechnicalLeak(
          'Traceback (most recent call last):\n  File "main.py", line 42',
        ),
        isTrue,
      );
      expect(
        containsTechnicalLeak(
          'DioException [connection error]: SocketException: OS Error',
        ),
        isTrue,
      );
    });

    test('Détecte et bloque les adresses IP et ports', () {
      expect(containsTechnicalLeak('Refused 192.168.1.45:8000'), isTrue);
    });

    test('Détecte et bloque les dumps JSON bruts', () {
      expect(
        containsTechnicalLeak('{"detail": [{"loc": ["body"], "msg": "x"}]}'),
        isTrue,
      );
    });

    test('Autorise les messages commerciaux propres', () {
      expect(
        containsTechnicalLeak(
          'Votre facture mensuelle doit être un montant supérieur à zéro.',
        ),
        isFalse,
      );
      expect(containsTechnicalLeak('Votre budget est de 5000 MAD.'), isFalse);
      expect(containsTechnicalLeak(null), isFalse);
      expect(containsTechnicalLeak(''), isFalse);
    });

    test(
        'Filtre tous les marqueurs techniques demandés sans tenir compte de la casse',
        () {
      for (final message in [
        'DIOEXCEPTION',
        'SocketException',
        'NullPointerException',
        'null pointer',
        'connection refused',
        'Stack trace',
        'Traceback',
        'HTTP 500',
        '502',
        'Erreur dans checkout.dart:42',
        'Erreur dans engine.py:10',
        'Exception: connection failed',
        '[{"detail":"error"}]',
      ]) {
        expect(containsTechnicalLeak(message), isTrue, reason: message);
      }
    });
  });

  group('Messages commerciaux (friendlyQuoteErrorMessage)', () {
    test('Erreur serveur 500 → message chaleureux', () {
      final dio500 = DioException(
        requestOptions: RequestOptions(path: '/v1/devis/calculer'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/devis/calculer'),
          statusCode: 500,
          data: 'Traceback crash at engine.py:100',
        ),
      );
      final message = friendlyQuoteErrorMessage(dio500);
      expect(containsTechnicalLeak(message), isFalse);
      expect(message, contains('Notre outil de dimensionnement solaire'));
    });

    test('Coupure réseau → message rassurant', () {
      final dioTimeout = DioException(
        requestOptions: RequestOptions(path: '/v1/devis/calculer'),
        type: DioExceptionType.connectionTimeout,
      );
      final message = friendlyQuoteErrorMessage(dioTimeout);
      expect(message, contains('Votre connexion Internet semble ralentie'));
    });

    test('Message brut technique → masqué', () {
      final message = friendlyQuoteErrorMessage(
        'Exception: database connection failed on port 5432',
      );
      expect(containsTechnicalLeak(message), isFalse);
      expect(message, contains('simulateur solaire'));
    });

    test('Message métier propre → conservé', () {
      const clean = 'Merci de renseigner une ville au Maroc.';
      expect(friendlyQuoteErrorMessage(clean), clean);
    });

    test('Validation du projet → demande de correction sans exposer la réponse',
        () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/v1/devis/calculer'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/devis/calculer'),
          statusCode: 422,
          data: {'detail': 'Exception: database failure'},
        ),
      );
      final message = friendlyQuoteErrorMessage(error);
      expect(message, contains('projet solaire'));
      expect(message, contains('Vérifiez les champs'));
      expect(containsTechnicalLeak(message), isFalse);
    });

    test('Les délais d’envoi et de réception proposent de relancer le devis',
        () {
      for (final type in [
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        final message = friendlyQuoteErrorMessage(
          DioException(
            requestOptions: RequestOptions(path: '/v1/devis/calculer'),
            type: type,
          ),
        );
        expect(message, contains('Votre connexion Internet semble ralentie'));
        expect(containsTechnicalLeak(message), isFalse);
      }
    });

    test(
        'Les erreurs inconnues et chaînes vides utilisent le message de secours',
        () {
      for (final error in [
        null,
        '',
        StateError('engine.py:10'),
        '<html>500</html>'
      ]) {
        final message = friendlyQuoteErrorMessage(error);
        expect(message, contains('simulateur solaire'));
        expect(containsTechnicalLeak(message), isFalse);
      }
    });
  });

  test('friendlyPdfErrorMessage propose WhatsApp ou email', () {
    expect(friendlyPdfErrorMessage(), contains('WhatsApp ou email'));
    final message = friendlyPdfErrorMessage(Exception('HTTP 500: engine.py'));
    expect(message, contains('WhatsApp ou email'));
    expect(containsTechnicalLeak(message), isFalse);
  });
}
