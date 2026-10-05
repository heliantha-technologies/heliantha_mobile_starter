import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_api_service.dart';

void main() {
  test('assistant quota gives a polite message without technical server details',
      () async {
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: 429,
          data: 'Traceback in rate_limit.py',
        ),
      ));
    }));
    final reply = await AssistantApiService(dio: dio).sendMessage(
      history: [
        {'role': 'user', 'content': 'Bonjour'}
      ],
    );
    expect(reply, contains('patienter quelques instants'));
    expect(reply, isNot(contains('Traceback')));
    expect(reply, isNot(contains('429')));
  });
}
