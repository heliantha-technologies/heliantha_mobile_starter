import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/store_context.dart';
import '../data/store_context_repository.dart';

final storeContextRepositoryProvider = Provider<StoreContextRepository>(
  (ref) => StoreContextRepository(ref.watch(apiClientProvider)),
);

final storeContextProvider = FutureProvider<StoreContext>(
  (ref) => ref.watch(storeContextRepositoryProvider).context(),
);

final selectedLanguageIdProvider =
    StateNotifierProvider<SelectedLanguageIdNotifier, int?>(
  (ref) =>
      SelectedLanguageIdNotifier(ref.watch(storeContextRepositoryProvider)),
);

final selectedCurrencyIdProvider =
    StateNotifierProvider<SelectedCurrencyIdNotifier, int?>(
  (ref) =>
      SelectedCurrencyIdNotifier(ref.watch(storeContextRepositoryProvider)),
);

class SelectedLanguageIdNotifier extends StateNotifier<int?> {
  SelectedLanguageIdNotifier(this._repository) : super(null) {
    ready = _load();
  }

  final StoreContextRepository _repository;
  late final Future<void> ready;
  bool _selected = false;

  Future<void> _load() async {
    try {
      final saved = await _repository.readLanguageId();
      if (mounted && !_selected) state = saved;
    } catch (_) {
      // Keep the default selection when local storage is unavailable.
    }
  }

  Future<void> select(int id) async {
    _selected = true;
    state = id;
    await _repository.saveLanguageId(id);
  }
}

class SelectedCurrencyIdNotifier extends StateNotifier<int?> {
  SelectedCurrencyIdNotifier(this._repository) : super(null) {
    ready = _load();
  }

  final StoreContextRepository _repository;
  late final Future<void> ready;
  bool _selected = false;

  Future<void> _load() async {
    try {
      final saved = await _repository.readCurrencyId();
      if (mounted && !_selected) state = saved;
    } catch (_) {
      // Keep the default selection when local storage is unavailable.
    }
  }

  Future<void> select(int id) async {
    _selected = true;
    state = id;
    await _repository.saveCurrencyId(id);
  }
}
