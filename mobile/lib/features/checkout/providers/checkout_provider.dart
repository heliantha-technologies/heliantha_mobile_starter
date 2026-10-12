import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/providers.dart';
import '../../cart/providers/cart_provider.dart';
import '../data/checkout_repository.dart';
import '../domain/checkout_models.dart';

final checkoutRepositoryProvider = Provider<CheckoutRepository>(
  (ref) => CheckoutRepository(ref.watch(apiClientProvider)),
);

final checkoutSubmissionProvider =
    StateNotifierProvider<CheckoutSubmissionNotifier, CheckoutSubmissionState>(
        (ref) {
  return CheckoutSubmissionNotifier(
    repository: ref.watch(checkoutRepositoryProvider),
    cart: ref.read(cartProvider.notifier),
  );
});

class CheckoutSubmissionState {
  const CheckoutSubmissionState({
    this.isRestoring = true,
    this.isSubmitting = false,
    this.canSubmit = true,
    this.idempotencyKey,
    this.lastOrderResult,
    this.error,
  });

  final bool isRestoring;
  final bool isSubmitting;
  final bool canSubmit;
  final String? idempotencyKey;
  final CheckoutConfirmResult? lastOrderResult;
  final String? error;
}

class CheckoutSubmissionNotifier
    extends StateNotifier<CheckoutSubmissionState> {
  CheckoutSubmissionNotifier({
    required CheckoutRepository repository,
    required CartNotifier cart,
    Future<SharedPreferences> Function()? preferencesLoader,
  })  : _repository = repository,
        _cart = cart,
        _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        super(const CheckoutSubmissionState()) {
    _restoreFuture = _restore();
  }

  static const _storageKey = 'heliantha_checkout_pending_attempt_v1';
  static final _random = Random.secure();

  final CheckoutRepository _repository;
  final CartNotifier _cart;
  final Future<SharedPreferences> Function() _preferencesLoader;
  late final Future<void> _restoreFuture;
  SharedPreferences? _preferences;
  String? _fingerprint;
  Future<CheckoutConfirmResult>? _activeSubmission;

  Future<void> _restore() async {
    try {
      _preferences = await _preferencesLoader();
      final saved = _preferences!.getString(_storageKey);
      if (saved != null) {
        final record = jsonDecode(saved);
        if (record is Map<String, dynamic> &&
            record['key'] is String &&
            record['fingerprint'] is String) {
          _fingerprint = record['fingerprint'] as String;
          state = CheckoutSubmissionState(
            isRestoring: false,
            idempotencyKey: record['key'] as String,
          );
          return;
        }
      }
      state = const CheckoutSubmissionState(isRestoring: false);
    } catch (_) {
      state = const CheckoutSubmissionState(
        isRestoring: false,
        canSubmit: false,
        error:
            'Impossible de restaurer la tentative de commande sur cet appareil.',
      );
    }
  }

  Future<CheckoutConfirmResult> submit({
    required List<CheckoutLineRequest> lines,
    required String mode,
    required int? currencyId,
    required int? languageId,
    required Map<String, dynamic>? guest,
    required Map<String, dynamic>? address,
    required int? addressId,
    required int? carrierId,
    required String? paymentModule,
  }) {
    final active = _activeSubmission;
    if (active != null) return active;
    final submission = _submit(
      lines: lines,
      mode: mode,
      currencyId: currencyId,
      languageId: languageId,
      guest: guest,
      address: address,
      addressId: addressId,
      carrierId: carrierId,
      paymentModule: paymentModule,
    );
    _activeSubmission = submission;
    return submission.whenComplete(() {
      if (identical(_activeSubmission, submission)) {
        _activeSubmission = null;
      }
    });
  }

  Future<CheckoutConfirmResult> _submit({
    required List<CheckoutLineRequest> lines,
    required String mode,
    required int? currencyId,
    required int? languageId,
    required Map<String, dynamic>? guest,
    required Map<String, dynamic>? address,
    required int? addressId,
    required int? carrierId,
    required String? paymentModule,
  }) async {
    await _restoreFuture;
    if (state.isRestoring || !state.canSubmit || _preferences == null) {
      throw StateError(state.error ?? 'Le checkout n’est pas encore prêt.');
    }

    final sortedLines = [...lines]
      ..sort((a, b) => a.productId.compareTo(b.productId));
    final fingerprint = jsonEncode({
      'currency_id': currencyId,
      'lines': [for (final line in sortedLines) line.toJson()],
    });
    var key = state.idempotencyKey;
    if (key == null || fingerprint != _fingerprint) {
      key = _newIdempotencyKey();
      final saved = await _preferences!.setString(
        _storageKey,
        jsonEncode({'key': key, 'fingerprint': fingerprint}),
      );
      if (!saved) {
        throw StateError('La clé de commande n’a pas pu être sauvegardée.');
      }
      _fingerprint = fingerprint;
    }

    state = CheckoutSubmissionState(
      isRestoring: false,
      isSubmitting: true,
      idempotencyKey: key,
    );
    try {
      final result = await _repository.confirm(
        lines: lines,
        mode: mode,
        idempotencyKey: key,
        currencyId: currencyId,
        languageId: languageId,
        guest: guest,
        address: address,
        addressId: addressId,
        carrierId: carrierId,
        paymentModule: paymentModule,
      );
      if (result.orderId == null || result.orderId! <= 0) {
        throw StateError(
            'La confirmation ne contient pas de numéro de commande.');
      }

      _cart.clear();
      await _cart.flush();
      _fingerprint = null;
      state = CheckoutSubmissionState(
        isRestoring: false,
        lastOrderResult: result,
      );
      try {
        await _preferences!.remove(_storageKey);
      } catch (_) {
        // A retained key is safe: the server has already completed the order.
      }
      return result;
    } catch (error) {
      // A timeout can hide a server-side success; retain the key for retries.
      state = CheckoutSubmissionState(
        isRestoring: false,
        idempotencyKey: key,
        error: error.toString(),
      );
      rethrow;
    }
  }

  String _newIdempotencyKey() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
