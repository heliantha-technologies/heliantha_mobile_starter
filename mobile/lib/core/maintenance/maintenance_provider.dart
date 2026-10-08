import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

enum MaintenanceStatus { checking, available, maintenance, unavailable }

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  final repository = MaintenanceRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final maintenanceProvider =
    StateNotifierProvider.autoDispose<MaintenanceNotifier, MaintenanceStatus>(
        (ref) {
  return MaintenanceNotifier(ref.watch(maintenanceRepositoryProvider));
});

class MaintenanceRepository {
  MaintenanceRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 32),
              headers: const {'Accept': 'application/json'},
              extra: const {'withCredentials': true},
            ));

  final Dio _dio;

  Future<bool> check({bool? previous, required CancelToken cancelToken}) async {
    final response = await _dio.get<dynamic>(
      '/v1/maintenance/status',
      queryParameters: {
        if (previous != null) 'since': previous,
        'wait': previous == null ? 0 : 25,
        // Avoid intermediary/browser caching even on a misconfigured proxy.
        '_': DateTime.now().millisecondsSinceEpoch,
      },
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map || data['maintenance'] is! bool) {
      throw const FormatException('Invalid maintenance response');
    }
    return data['maintenance'] as bool;
  }

  void dispose() => _dio.close(force: true);
}

class MaintenanceNotifier extends StateNotifier<MaintenanceStatus> {
  MaintenanceNotifier(this.repository) : super(MaintenanceStatus.checking);

  final MaintenanceRepository repository;
  Timer? _timer;
  CancelToken? _cancel;
  bool _running = false;
  int _generation = 0;

  void resume() {
    if (_running) return;
    _running = true;
    if (state == MaintenanceStatus.available) {
      state = MaintenanceStatus.checking;
    }
    unawaited(_check(initial: true));
  }

  void pause() {
    _running = false;
    _generation++;
    _timer?.cancel();
    _cancel?.cancel();
  }

  void retry() {
    pause();
    resume();
  }

  void reportMaintenance() {
    // Invalidate an older in-flight "available" response before displaying.
    final running = _running;
    pause();
    state = MaintenanceStatus.maintenance;
    if (running) resume();
  }

  Future<void> _check({bool initial = false}) async {
    if (!_running || !mounted) return;
    final generation = ++_generation;
    final token = _cancel = CancelToken();
    var delay = const Duration(milliseconds: 200);
    try {
      final enabled = await repository.check(
        previous: initial ||
                state == MaintenanceStatus.checking ||
                state == MaintenanceStatus.unavailable
            ? null
            : state == MaintenanceStatus.maintenance,
        cancelToken: token,
      );
      if (!mounted || !_running || generation != _generation) return;
      state =
          enabled ? MaintenanceStatus.maintenance : MaintenanceStatus.available;
    } catch (_) {
      if (!mounted || !_running || generation != _generation) return;
      // Never reopen a known maintenance window after a network timeout.
      if (state != MaintenanceStatus.maintenance) {
        state = MaintenanceStatus.unavailable;
      }
      delay = const Duration(seconds: 5);
    }
    if (mounted && _running && generation == _generation) {
      _timer = Timer(delay, _check);
    }
  }

  @override
  void dispose() {
    pause();
    super.dispose();
  }
}

class MaintenanceInterceptor extends Interceptor {
  MaintenanceInterceptor(this.onMaintenance);
  final void Function() onMaintenance;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 503) {
      dynamic data = err.response?.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      if (data is Map &&
          data['maintenance'] == true &&
          data['error_code'] == 'maintenance') {
        onMaintenance();
      }
    }
    handler.next(err);
  }
}
