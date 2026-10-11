import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/core/api/api_client.dart';
import 'package:heliantha_mobile/core/storage/token_storage.dart';
import 'package:heliantha_mobile/features/quote/data/quote_repository.dart';
import 'package:heliantha_mobile/shared/utils/api_url.dart';

class _EmptyTokenStorage extends TokenStorage {
  @override
  Future<String?> read() async => null;
}

void main() {
  group('PDF access URLs', () {
    test('preserves existing token, repeated query values and fragment', () {
      const url =
          '/v1/devis/1/pdf?lang=fr&tag=a&tag=b&token=engine-token#page=2';
      final resolved = resolvePdfUrl(url, accessToken: 'other-token');
      expect(resolved, 'https://app.heliantha.ma$url');
      final uri = Uri.parse(resolved);
      expect(uri.queryParametersAll['token'], ['engine-token']);
      expect(uri.queryParametersAll['tag'], ['a', 'b']);
      expect(uri.fragment, 'page=2');
    });

    test('adds encoded access token without rewriting the original query', () {
      final resolved = resolvePdfUrl(
        '/v1/devis/1/pdf?lang=fr&tag=a&tag=b#page=2',
        accessToken: 'quote+/&=? token',
      );
      final uri = Uri.parse(resolved);
      expect(uri.query, startsWith('lang=fr&tag=a&tag=b&token='));
      expect(uri.queryParameters['token'], 'quote+/&=? token');
      expect(uri.queryParametersAll['tag'], ['a', 'b']);
      expect(uri.fragment, 'page=2');
    });

    test('does not create a URL or token when the required data is absent', () {
      expect(resolvePdfUrl(null, accessToken: 'token'), '');
      expect(resolvePdfUrl('/v1/devis/1/pdf', accessToken: ' '),
          'https://app.heliantha.ma/v1/devis/1/pdf');
    });

    test('quote result includes access token in a reconstructed PDF URL', () {
      const result = QuoteCalculationResult({
        'quote_number': 'DEV 42',
        'access_token': 'generated-quote-token',
      });
      final uri = Uri.parse(result.resolvedPdfUrl);
      expect(uri.pathSegments, ['v1', 'devis', 'DEV 42', 'pdf']);
      expect(uri.queryParameters['token'], 'generated-quote-token');
    });

    test('quote result includes access token in a supplied PDF URL', () {
      const result = QuoteCalculationResult({
        'quote_number': 'DEV-42',
        'pdf_url': '/v1/devis/42/pdf?download=1',
        'access_token': 'generated-quote-token',
      });
      final uri = Uri.parse(result.resolvedPdfUrl);
      expect(uri.queryParameters['download'], '1');
      expect(uri.queryParameters['token'], 'generated-quote-token');
    });
  });

  for (final useLegacyRoute in [false, true]) {
    test(
        'PDF download forwards access token ${useLegacyRoute ? 'to the fallback' : 'to the API'}',
        () async {
      final api = ApiClient(_EmptyTokenStorage());
      addTearDown(() => api.dio.close(force: true));
      final requests = <RequestOptions>[];
      api.dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: useLegacyRoute && requests.length == 1 ? 404 : 403,
            ),
          ));
        },
      ));

      await expectLater(
        QuoteRepository(api)
            .downloadAndOpenPdf('DEV 42', accessToken: 'generated-quote-token'),
        throwsA(isA<QuoteApiException>()),
      );
      expect(requests.length, useLegacyRoute ? 2 : 1);
      expect(requests.first.path, '/v1/devis/DEV%2042/pdf');
      if (useLegacyRoute) {
        expect(requests.last.path, '/api/devis/pdf/DEV%2042');
      }
      for (final request in requests) {
        expect(request.uri.queryParameters['token'], 'generated-quote-token');
        expect(request.headers['Accept'], 'application/pdf');
      }
    });
  }
}
