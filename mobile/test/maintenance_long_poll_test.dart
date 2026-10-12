import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/core/maintenance/maintenance_provider.dart';

class _PendingRepository extends MaintenanceRepository {
  final previousStates = <bool?>[];
  final responses = <Completer<bool>>[];

  @override
  Future<bool> check({bool? previous, required CancelToken cancelToken}) {
    previousStates.add(previous);
    final response = Completer<bool>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  test('long polls allow response headers to arrive after the 25-second wait',
      () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(
      baseUrl: 'https://example.invalid',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 32),
    ));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'maintenance': options.queryParameters['since'] == true},
      ));
    }));
    final repository = MaintenanceRepository(dio: dio);
    addTearDown(repository.dispose);

    expect(await repository.check(cancelToken: CancelToken()), isFalse);
    expect(
      await repository.check(previous: false, cancelToken: CancelToken()),
      isFalse,
    );
    expect(
      await repository.check(previous: true, cancelToken: CancelToken()),
      isTrue,
    );

    expect(requests, hasLength(3));
    final initial = requests.first;
    expect(initial.path, '/v1/maintenance/status');
    expect(initial.queryParameters, isNot(contains('since')));
    expect(initial.queryParameters['wait'], 0);
    expect(initial.connectTimeout, const Duration(seconds: 5));
    for (var index = 1; index < requests.length; index++) {
      final request = requests[index];
      expect(request.queryParameters['since'], index == 2);
      expect(request.queryParameters['wait'], 25);
      expect(request.connectTimeout, const Duration(seconds: 32));
      expect(
        request.connectTimeout!.inSeconds,
        greaterThan(request.queryParameters['wait'] as int),
      );
    }
    for (final request in requests) {
      expect(request.receiveTimeout, const Duration(seconds: 32));
      expect(request.queryParameters['_'], isA<int>());
    }
  });

  testWidgets('an unchanged pending long poll keeps the application available',
      (tester) async {
    final repository = _PendingRepository();
    final notifier = MaintenanceNotifier(repository);
    addTearDown(notifier.dispose);
    addTearDown(repository.dispose);
    final transitions = <MaintenanceStatus>[];
    notifier.addListener(transitions.add, fireImmediately: false);

    notifier.resume();
    expect(repository.previousStates, [null]);
    repository.responses.first.complete(false);
    await tester.pump();
    expect(notifier.state, MaintenanceStatus.available);

    await tester.pump(const Duration(milliseconds: 210));
    expect(repository.previousStates, [null, false]);
    await tester.pump(const Duration(seconds: 5));
    expect(notifier.state, MaintenanceStatus.available);
    await tester.pump(const Duration(seconds: 20));
    expect(notifier.state, MaintenanceStatus.available);
    expect(repository.previousStates, [null, false]);

    repository.responses[1].complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));
    expect(repository.previousStates, [null, false, false]);
    expect(transitions, [MaintenanceStatus.available]);
  });

  test('invalid status payloads and HTTP failures never report availability',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    dynamic payload = {'maintenance': 'false'};
    var statusCode = 200;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: statusCode,
        data: payload,
      );
      if (statusCode == 503) {
        handler.reject(DioException.badResponse(
          statusCode: statusCode,
          requestOptions: options,
          response: response,
        ));
      } else {
        handler.resolve(response);
      }
    }));
    final repository = MaintenanceRepository(dio: dio);
    addTearDown(repository.dispose);

    await expectLater(
      repository.check(cancelToken: CancelToken()),
      throwsFormatException,
    );
    payload = <dynamic>[];
    await expectLater(
      repository.check(previous: false, cancelToken: CancelToken()),
      throwsFormatException,
    );
    statusCode = 503;
    payload = {'error_code': 'maintenance_status_unavailable'};
    await expectLater(
      repository.check(previous: false, cancelToken: CancelToken()),
      throwsA(isA<DioException>().having(
        (error) => error.response?.statusCode,
        'status code',
        503,
      )),
    );
  });
}
