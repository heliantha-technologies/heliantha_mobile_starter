import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/providers.dart';
import '../../auth/providers/auth_provider.dart';

class FavoritesNotifier extends StateNotifier<Set<int>> {
  FavoritesNotifier(this.ref) : super(<int>{}) {
    _ready = _load();
  }

  final Ref ref;
  static const _key = 'favorite_product_ids';
  late final Future<void> _ready;

  Future<void> get ready => _ready;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_key) ?? const [];
      if (!mounted) return;
      state = ids.map(int.tryParse).whereType<int>().toSet();
    } catch (_) {
      // Local storage may be unavailable; keep favorites usable this session.
    }
  }

  Future<void> toggle(int productId) async {
    await _ready;
    if (!mounted) return;
    final next = {...state};
    if (!next.add(productId)) {
      next.remove(productId);
    }
    state = next;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        next.map((e) => e.toString()).toList(),
      );
    } catch (_) {
      // Preserve the immediate local selection even if storage is unavailable.
    }

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null || !mounted) return;
      final api = ref.read(apiClientProvider);
      if (next.contains(productId)) {
        await api.dio.post('/v1/favorites/$productId');
      } else {
        await api.dio.delete('/v1/favorites/$productId');
      }
    } catch (_) {
      // Favoris local immédiat; la surveillance stock sera synchronisée au login.
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<int>>(
  (ref) => FavoritesNotifier(ref),
);
