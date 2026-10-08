import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'api_client.dart';
import '../maintenance/maintenance_provider.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(tokenStorageProvider));
  client.dio.interceptors.add(MaintenanceInterceptor(
    () => ref.read(maintenanceProvider.notifier).reportMaintenance(),
  ));
  ref.onDispose(() => client.dio.close(force: true));
  return client;
});
