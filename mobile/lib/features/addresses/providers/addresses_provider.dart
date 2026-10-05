import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/address.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/addresses_repository.dart';

final addressesRepositoryProvider = Provider<AddressesRepository>(
  (ref) => AddressesRepository(ref.watch(apiClientProvider)),
);

final addressesProvider = FutureProvider<List<AddressModel>>(
  (ref) async {
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return const [];
    return ref.watch(addressesRepositoryProvider).list();
  },
);
