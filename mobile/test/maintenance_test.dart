import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/core/maintenance/maintenance_gate.dart';
import 'package:heliantha_mobile/core/maintenance/maintenance_provider.dart';

class _Repository extends MaintenanceRepository {
  final calls = <Completer<bool>>[];
  final tokens = <CancelToken>[];
  @override
  Future<bool> check({bool? previous, required CancelToken cancelToken}) {
    tokens.add(cancelToken);
    final result = Completer<bool>();
    calls.add(result);
    return result.future;
  }
}

void main() {
  testWidgets(
      'opening page switches to maintenance and back without losing input',
      (tester) async {
    final repository = _Repository();
    final controller = TextEditingController(text: 'Mon projet solaire');
    await tester.pumpWidget(ProviderScope(
      overrides: [maintenanceRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
          home: MaintenanceGate(
              child: Scaffold(
        body: TextField(controller: controller),
      ))),
    ));
    expect(find.text('Connexion à votre espace solaire…'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    repository.calls[0].complete(false);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 210));
    repository.calls[1].complete(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Maintenance en cours'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.pump(const Duration(milliseconds: 210));
    repository.calls[2].complete(false);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'Mon projet solaire');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    repository.dispose();
  });

  testWidgets('stale available response cannot undo a maintenance error',
      (tester) async {
    final repository = _Repository();
    final notifier = MaintenanceNotifier(repository);
    notifier.resume();
    notifier.reportMaintenance();
    expect(repository.tokens.first.isCancelled, isTrue);
    repository.calls.first.complete(false);
    await tester.pump();
    expect(notifier.state, MaintenanceStatus.maintenance);
    repository.calls.last.completeError(Exception('offline'));
    await tester.pump();
    expect(notifier.state, MaintenanceStatus.maintenance);
    notifier.dispose();
    repository.dispose();
  });

  testWidgets('pause stops requests and resume verifies again', (tester) async {
    final repository = _Repository();
    final notifier = MaintenanceNotifier(repository);
    notifier.resume();
    notifier.resume();
    expect(repository.calls.length, 1);
    notifier.pause();
    expect(repository.tokens.first.isCancelled, isTrue);
    repository.calls.first.complete(false);
    await tester.pump(const Duration(seconds: 30));
    expect(repository.calls.length, 1);
    notifier.resume();
    expect(repository.calls.length, 2);
    notifier.dispose();
    repository.dispose();
  });

  testWidgets('maintenance layout fits a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: MaintenanceScreen(
          status: MaintenanceStatus.maintenance, onRetry: () {}),
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('Maintenance en cours'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('only an explicit maintenance response triggers the global gate',
      () async {
    var reports = 0;
    final dio = Dio();
    var data = <String, dynamic>{'error_code': 'server_error'};
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(
          DioException(
              requestOptions: options,
              response: Response(
                  requestOptions: options, statusCode: 503, data: data)),
          true);
    }));
    dio.interceptors.add(MaintenanceInterceptor(() => reports++));
    try {
      await dio.get('/test');
    } catch (_) {}
    expect(reports, 0);
    data = {'error_code': 'maintenance', 'maintenance': true};
    try {
      await dio.get('/test');
    } catch (_) {}
    expect(reports, 1);
    dio.close(force: true);
  });
}
