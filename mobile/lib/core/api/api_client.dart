import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

class ApiClient {
  static String get apiBaseUrl => AppConfig.apiBaseUrl;
  static String resolvePdfUrl(String? rawUrl) =>
      AppConfig.resolvePdfUrl(rawUrl);

  ApiClient(this._tokenStorage)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 18),
            sendTimeout: const Duration(seconds: 12),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;
}
