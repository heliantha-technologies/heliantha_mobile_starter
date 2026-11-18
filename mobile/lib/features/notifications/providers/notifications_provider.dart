import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);

final notificationsProvider = FutureProvider<NotificationsResult>(
  (ref) async {
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) {
      return const NotificationsResult(items: [], unread: 0);
    }
    return ref.watch(notificationsRepositoryProvider).list();
  },
);
