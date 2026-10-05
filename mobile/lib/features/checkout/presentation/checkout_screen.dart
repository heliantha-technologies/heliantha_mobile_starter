import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/address.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/friendly_errors.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../addresses/providers/addresses_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../catalog/providers/store_context_provider.dart';
import '../../notifications/services/fcm_service.dart';
import '../domain/checkout_models.dart';
import '../providers/checkout_provider.dart';

const _bankWireModule = 'ps_wirepayment';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstname = TextEditingController();
  final _lastname = TextEditingController();
  final _email = TextEditingController();
  final _loginPassword = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();

  Future<CheckoutPreview>? _previewFuture;
  String _mode = 'guest';
  String _title = 'M.';
  bool _terms = false;
  bool _loginLoading = false;
  bool _confirming = false;
  bool _orderConfirmed = false;
  bool _successHandled = false;
  bool _successNavigationDone = false;
  String? _message;
  int? _selectedCarrierId;
  String? _selectedPaymentModule;
  int? _activeAddressId;
  int? _checkoutCurrencyId;
  int? _checkoutLanguageId;
  int _previewRequestId = 0;
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = DateTime.now().microsecondsSinceEpoch.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        final addresses = ref.read(addressesProvider).valueOrNull;
        final firstAddress = addresses?.firstOrNull;
        if (firstAddress != null) {
          _activeAddressId = firstAddress.id;
        }
      }
      _loadPreview(addressId: _activeAddressId);
    });
  }

  @override
  void dispose() {
    _firstname.dispose();
    _lastname.dispose();
    _email.dispose();
    _loginPassword.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _loadPreview(
      {int? carrierId, int? addressId, bool keepCarrier = false}) {
    if (!mounted) return;
    setState(() {
      if (!keepCarrier) {
        _selectedCarrierId = carrierId;
      }
      if (addressId != null) {
        _activeAddressId = addressId;
      }
      _selectedPaymentModule = null;
      _previewFuture = _requestPreview(
        carrierId: carrierId,
        addressId: addressId ?? _activeAddressId,
      );
    });
  }

  Future<CheckoutPreview> _requestPreview(
      {int? carrierId, int? addressId}) async {
    final requestId = ++_previewRequestId;
    final cart = ref.read(cartProvider.notifier);
    final currencySelection = ref.read(selectedCurrencyIdProvider.notifier);
    final languageSelection = ref.read(selectedLanguageIdProvider.notifier);
    final contextFuture = ref.read(storeContextProvider.future);
    await Future.wait(
        [cart.ready, currencySelection.ready, languageSelection.ready]);
    final store = await contextFuture;
    if (!mounted) throw StateError('Checkout closed');
    final items = ref.read(cartProvider);
    final selectedCurrencyId = ref.read(selectedCurrencyIdProvider);
    final cartCode = items.firstOrNull?.product.currency;
    final savedCurrencyId = cart.currencyId ??
        store.currencies
            .where((currency) => currency.isoCode == cartCode)
            .firstOrNull
            ?.id;
    final currencyId =
        store.effectiveCurrencyId(selectedCurrencyId ?? savedCurrencyId);
    final languageId =
        store.effectiveLanguageId(ref.read(selectedLanguageIdProvider));
    await cart.refreshCurrency(currencyId, force: true);
    if (!mounted) throw StateError('Checkout closed');
    final preview = await ref.read(checkoutRepositoryProvider).preview(
          lines: CheckoutLineRequest.fromCart(ref.read(cartProvider)),
          currencyId: currencyId,
          languageId: languageId,
          carrierId: carrierId,
          addressId: addressId,
        );
    final expectedCurrency = store.currencies
        .where((currency) => currency.id == currencyId)
        .firstOrNull;
    if (expectedCurrency != null &&
        preview.totals.currency != expectedCurrency.isoCode) {
      throw StateError('Unexpected checkout currency');
    }
    if (requestId == _previewRequestId) {
      _checkoutCurrencyId = currencyId;
      _checkoutLanguageId = languageId;
    }
    return preview;
  }

  void _recalculateForCarrier(int carrierId) {
    setState(() {
      _selectedCarrierId = carrierId;
      _message = null;
      _previewFuture = _requestPreview(
        carrierId: carrierId,
        addressId: _activeAddressId,
      );
    });
  }

  void _ensureCheckoutSelections(CheckoutPreview preview) {
    final carrierIds = preview.carriers.map((carrier) => carrier.id).toSet();
    final paymentModules = preview.payments
        .map((payment) => payment.module)
        .where((module) => module.isNotEmpty)
        .toSet();
    final nextCarrierId = carrierIds.contains(_selectedCarrierId)
        ? _selectedCarrierId
        : (carrierIds.contains(preview.selectedCarrierId)
            ? preview.selectedCarrierId
            : null);
    final nextPaymentModule = paymentModules.contains(_selectedPaymentModule)
        ? _selectedPaymentModule
        : (preview.payments.isEmpty ? null : preview.payments.first.module);

    if (nextCarrierId != _selectedCarrierId ||
        nextPaymentModule != _selectedPaymentModule) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedCarrierId = nextCarrierId;
          _selectedPaymentModule = nextPaymentModule;
        });
      });
    }
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _loginPassword.text.isEmpty) {
      setState(() => _message = 'Renseignez votre email et mot de passe.');
      return;
    }

    setState(() {
      _loginLoading = true;
      _message = null;
    });

    try {
      await ref.read(authRepositoryProvider).login(
            email: _email.text.trim(),
            password: _loginPassword.text,
          );
      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      ref.invalidate(addressesProvider);
      await ref.read(fcmServiceProvider).registerForCurrentUser();
      if (!mounted) return;
      setState(() => _message = 'Connexion réussie.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = friendlyLoginMessage());
    } finally {
      if (mounted) {
        setState(() => _loginLoading = false);
      }
    }
  }

  Future<void> _confirm(
    CheckoutPreview preview, {
    required bool isConnected,
    required AddressModel? userAddress,
  }) async {
    if (_confirming || _orderConfirmed) {
      return;
    }
    final sync = ref.read(cartSyncStateProvider);
    if (sync.isLoading ||
        sync.hasError ||
        (ref.read(selectedCurrencyIdProvider) != null &&
            ref.read(selectedCurrencyIdProvider) != _checkoutCurrencyId)) {
      _loadPreview(addressId: _activeAddressId);
      return;
    }
    if (!_terms) {
      setState(() => _message = 'Acceptez les conditions générales.');
      return;
    }
    if (!preview.stockOk) {
      setState(() => _message = 'Stock insuffisant pour confirmer.');
      return;
    }
    final carrierId = _selectedCarrierId;
    final paymentModule = _selectedPaymentModule ??
        (preview.payments.isEmpty ? null : preview.payments.first.module);
    if (preview.carriers.isNotEmpty && carrierId == null) {
      setState(() => _message = 'Sélectionnez un mode de livraison.');
      return;
    }
    if (paymentModule == null || paymentModule.isEmpty) {
      setState(() => _message = 'Sélectionnez un moyen de paiement.');
      return;
    }

    if (isConnected) {
      if (userAddress == null) {
        setState(() => _message =
            'Veuillez ajouter une adresse de livraison pour continuer.');
        return;
      }
    } else {
      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }
    }

    setState(() {
      _confirming = true;
      _message = null;
    });

    try {
      final effectiveMode = isConnected ? 'login' : _mode;
      final result = await ref.read(checkoutRepositoryProvider).confirm(
            lines: CheckoutLineRequest.fromCart(ref.read(cartProvider)),
            mode: effectiveMode,
            idempotencyKey: _idempotencyKey,
            currencyId: _checkoutCurrencyId,
            languageId: _checkoutLanguageId,
            guest: !isConnected && effectiveMode == 'guest'
                ? {
                    'title': _title,
                    'firstname': _firstname.text.trim(),
                    'lastname': _lastname.text.trim(),
                    'email': _email.text.trim(),
                  }
                : null,
            address: isConnected
                ? null
                : {
                    'firstname': _firstname.text.trim(),
                    'lastname': _lastname.text.trim(),
                    'address1': _address.text.trim(),
                    'city': _city.text.trim(),
                    if (_phone.text.trim().isNotEmpty)
                      'phone': _phone.text.trim(),
                  },
            addressId: isConnected ? userAddress?.id : null,
            carrierId: carrierId,
            paymentModule: paymentModule,
          );
      if (!mounted) return;
      setState(() {
        _orderConfirmed = true;
        _confirming = false;
      });
      _handleSuccessfulOrder(
        result,
        preview,
        isConnected: isConnected,
        paymentModule: paymentModule,
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _message = friendlyCheckoutMessage(error),
      );
    } finally {
      if (mounted && !_orderConfirmed) {
        setState(() => _confirming = false);
      }
    }
  }

  Future<void> _handleSuccessfulOrder(
    CheckoutConfirmResult result,
    CheckoutPreview preview, {
    required bool isConnected,
    required String paymentModule,
  }) async {
    if (_successHandled) {
      return;
    }
    _successHandled = true;
    ref.read(cartProvider.notifier).clear();
    await _showOrderSuccessDialog(
      result,
      preview,
      isConnected: isConnected,
      paymentModule: paymentModule,
    );
  }

  Future<void> _showOrderSuccessDialog(
    CheckoutConfirmResult result,
    CheckoutPreview preview, {
    required bool isConnected,
    required String? paymentModule,
  }) async {
    var closedByAction = false;
    Future<void> navigateTo(String location) async {
      if (_successNavigationDone || !mounted) {
        return;
      }
      _successNavigationDone = true;
      closedByAction = true;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      context.go(location);
    }

    final isBankWire =
        paymentModule == _bankWireModule || result.paymentDetails != null;

    if (isConnected && !isBankWire) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!closedByAction && mounted && !_successNavigationDone) {
          navigateTo('/orders');
        }
      });
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => OrderSuccessDialog(
        result: result,
        fallbackTotal: preview.totals.totalTtc,
        fallbackCurrency: preview.totals.currencySymbol,
        isConnected: isConnected,
        isBankWire: isBankWire,
        onOrders: () => navigateTo('/orders'),
        onHome: () => navigateTo('/'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final authState = ref.watch(currentUserProvider);
    final user = authState.valueOrNull;
    final isConnected = user != null;

    final addressesAsync = isConnected ? ref.watch(addressesProvider) : null;
    final userAddresses = addressesAsync?.valueOrNull;
    final userAddress = userAddresses?.firstOrNull;

    ref.listen<int?>(selectedCurrencyIdProvider, (previous, next) {
      if (previous != next &&
          _previewFuture != null &&
          !_confirming &&
          !_orderConfirmed) {
        _loadPreview(
          carrierId: _selectedCarrierId,
          addressId: _activeAddressId,
          keepCarrier: true,
        );
      }
    });

    ref.listen(addressesProvider, (previous, next) {
      final address = next.valueOrNull?.firstOrNull;
      if (address != null && address.id != _activeAddressId) {
        _loadPreview(
          carrierId: _selectedCarrierId,
          addressId: address.id,
          keepCarrier: true,
        );
      }
    });

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Checkout',
        showBack: true,
        backFallbackLocation: '/cart',
      ),
      body: SafeArea(
        child: cartItems.isEmpty
            ? ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Votre panier est vide',
                  message:
                      'Découvrez nos produits et ajoutez ceux qui vous intéressent.',
                  action: FilledButton.icon(
                    onPressed: () => context.go('/catalog'),
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('Découvrir le catalogue'),
                  ),
                ),
              )
            : FutureBuilder<CheckoutPreview>(
                future: _previewFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _CheckoutPreviewSkeleton();
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    final friendly = friendlyLoadError(snapshot.error);
                    return ResponsivePagePadding(
                      child: AppStatusPanel(
                        icon: Icons.cloud_off_rounded,
                        title: friendly.title,
                        message: friendly.message,
                        action: OutlinedButton.icon(
                          onPressed: () =>
                              _loadPreview(addressId: _activeAddressId),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
                      ),
                    );
                  }

                  final preview = snapshot.data!;
                  _ensureCheckoutSelections(preview);
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ResponsivePagePadding(
                        bottom: 96,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isConnected) ...[
                                _ModeSelector(
                                  mode: _mode,
                                  onChanged: (value) {
                                    setState(() {
                                      _mode = value;
                                      _message = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),
                                if (_mode == 'guest')
                                  _GuestStep(
                                    title: _title,
                                    firstname: _firstname,
                                    lastname: _lastname,
                                    email: _email,
                                    onTitleChanged: (value) =>
                                        setState(() => _title = value),
                                  )
                                else
                                  _LoginStep(
                                    email: _email,
                                    password: _loginPassword,
                                    loading: _loginLoading,
                                    onLogin: _login,
                                  ),
                                const SizedBox(height: 14),
                                _AddressStep(
                                  address: _address,
                                  city: _city,
                                  phone: _phone,
                                ),
                              ] else ...[
                                _UsedAddressPanel(
                                  address: userAddress,
                                  isLoading: addressesAsync?.isLoading ?? false,
                                  onManageAddress: () async {
                                    await context.push(
                                      '/addresses?from=checkout',
                                    );
                                    if (mounted) {
                                      ref.invalidate(addressesProvider);
                                    }
                                  },
                                ),
                              ],
                              const SizedBox(height: 14),
                              _CheckoutOptions(
                                preview: preview,
                                selectedCarrierId: _selectedCarrierId,
                                selectedPaymentModule: _selectedPaymentModule,
                                onCarrierChanged: (value) {
                                  if (value != null) {
                                    _recalculateForCarrier(value);
                                  }
                                },
                                onPaymentChanged: (value) => setState(
                                  () => _selectedPaymentModule = value,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _CheckoutSummary(preview: preview),
                              const SizedBox(height: 14),
                              Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  value: _terms,
                                  onChanged: (value) {
                                    setState(() => _terms = value ?? false);
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: const Text(
                                    "J'accepte les conditions générales de vente",
                                  ),
                                ),
                              ),
                              if (_message != null) ...[
                                const SizedBox(height: 8),
                                _Notice(message: _message!),
                              ],
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _confirming || _orderConfirmed
                                      ? null
                                      : () => _confirm(
                                            preview,
                                            isConnected: isConnected,
                                            userAddress: userAddress,
                                          ),
                                  icon: _confirming
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle_rounded),
                                  label: Text(
                                    _confirming
                                        ? 'Confirmation en cours...'
                                        : _orderConfirmed
                                            ? 'Commande confirmée'
                                            : preview.writeEnabled
                                                ? 'Confirmer la commande'
                                                : 'Vérifier la commande',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'guest',
          icon: Icon(Icons.person_add_alt_1_rounded),
          label: Text("Commander en tant qu'invité"),
        ),
        ButtonSegment(
          value: 'login',
          icon: Icon(Icons.login_rounded),
          label: Text('Connexion'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}

class _GuestStep extends StatelessWidget {
  const _GuestStep({
    required this.title,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.onTitleChanged,
  });

  final String title;
  final TextEditingController firstname;
  final TextEditingController lastname;
  final TextEditingController email;
  final ValueChanged<String> onTitleChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Informations personnelles',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: title,
            decoration: const InputDecoration(labelText: 'Titre'),
            items: const [
              DropdownMenuItem(value: 'M.', child: Text('M.')),
              DropdownMenuItem(value: 'Mme', child: Text('Mme')),
            ],
            onChanged: (value) {
              if (value != null) onTitleChanged(value);
            },
          ),
          const SizedBox(height: 12),
          _RequiredField(controller: firstname, label: 'Prénom'),
          const SizedBox(height: 12),
          _RequiredField(controller: lastname, label: 'Nom'),
          const SizedBox(height: 12),
          _RequiredField(
            controller: email,
            label: 'E-mail',
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }
}

class CheckoutLoginStep extends StatefulWidget {
  const CheckoutLoginStep({
    super.key,
    required this.email,
    required this.password,
    required this.loading,
    required this.onLogin,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool loading;
  final VoidCallback onLogin;

  @override
  State<CheckoutLoginStep> createState() => _CheckoutLoginStepState();
}

typedef _LoginStep = CheckoutLoginStep;

class _CheckoutLoginStepState extends State<CheckoutLoginStep> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Connexion',
      child: Column(
        children: [
          _RequiredField(
            controller: widget.email,
            label: 'E-mail',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _RequiredField(
            controller: widget.password,
            label: 'Mot de passe',
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.muted,
              ),
              tooltip: _obscurePassword
                  ? 'Afficher le mot de passe'
                  : 'Masquer le mot de passe',
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.loading ? null : widget.onLogin,
              icon: widget.loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(widget.loading ? 'Connexion...' : 'Connexion'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressStep extends StatelessWidget {
  const _AddressStep({
    required this.address,
    required this.city,
    required this.phone,
  });

  final TextEditingController address;
  final TextEditingController city;
  final TextEditingController phone;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Adresse',
      child: Column(
        children: [
          _RequiredField(controller: address, label: 'Adresse'),
          const SizedBox(height: 12),
          _RequiredField(controller: city, label: 'Ville'),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
        ],
      ),
    );
  }
}

class _CheckoutOptions extends StatelessWidget {
  const _CheckoutOptions({
    required this.preview,
    required this.selectedCarrierId,
    required this.selectedPaymentModule,
    required this.onCarrierChanged,
    required this.onPaymentChanged,
  });

  final CheckoutPreview preview;
  final int? selectedCarrierId;
  final String? selectedPaymentModule;
  final ValueChanged<int?> onCarrierChanged;
  final ValueChanged<String?> onPaymentChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Livraison et paiement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.carriers.isEmpty)
            const _MutedLine(
                'Aucun mode de livraison disponible pour le moment.')
          else
            for (final carrier in preview.carriers)
              _ChoiceLine(
                selected: carrier.id == selectedCarrierId,
                icon: Icons.local_shipping_rounded,
                title: Text(carrier.name),
                subtitle: (carrier.priceLabel ?? carrier.delay) == null
                    ? null
                    : Text((carrier.priceLabel ?? carrier.delay)!),
                onTap: () => onCarrierChanged(carrier.id),
              ),
          const Divider(height: 24),
          if (preview.payments.isEmpty)
            const _MutedLine(
                'Aucun moyen de paiement disponible pour le moment.')
          else
            for (final payment in preview.payments)
              _ChoiceLine(
                selected: payment.module == selectedPaymentModule,
                icon: Icons.payments_rounded,
                title: Text(payment.name),
                subtitle: payment.module == _bankWireModule
                    ? const _BankWirePaymentHint()
                    : const Text('Disponible pour ce panier'),
                onTap: () => onPaymentChanged(payment.module),
              ),
        ],
      ),
    );
  }
}

class _BankWirePaymentHint extends StatelessWidget {
  const _BankWirePaymentHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.softSun,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: AppColors.sun.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppColors.navy,
              size: 16,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Les coordonnées bancaires (RIB, titulaire) vous seront fournies à la validation de la commande.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceLine extends StatelessWidget {
  const _ChoiceLine({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final IconData icon;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.softBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.leaf : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class OrderSuccessDialog extends StatelessWidget {
  const OrderSuccessDialog({
    super.key,
    required this.result,
    required this.fallbackTotal,
    required this.fallbackCurrency,
    required this.isConnected,
    required this.isBankWire,
    required this.onOrders,
    required this.onHome,
  });

  final CheckoutConfirmResult result;
  final double fallbackTotal;
  final String fallbackCurrency;
  final bool isConnected;
  final bool isBankWire;
  final VoidCallback onOrders;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final total = result.total ?? fallbackTotal;
    final currency = result.currency ?? fallbackCurrency;
    final formattedTotal = formatMoney(total, currency: currency);
    final reference = result.reference?.trim();
    final hasReference = reference != null && reference.isNotEmpty;

    if (isBankWire || result.paymentDetails != null) {
      return _BankWireOrderDialog(
        details: result.paymentDetails ?? const BankWireDetails(),
        reference: hasReference ? reference : null,
        formattedTotal: formattedTotal,
        isConnected: isConnected,
        onOrders: onOrders,
        onHome: onHome,
      );
    }

    final title = isConnected ? 'Commande confirmée !' : 'Commande enregistrée';
    final message = isConnected
        ? 'Votre commande a bien été enregistrée.'
        : 'Merci pour votre confiance ! Votre commande a bien été enregistrée. Notre équipe va la traiter prochainement.';

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.softLeaf,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.leaf,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(
                  children: [
                    if (hasReference)
                      if (isConnected)
                        _SuccessMetaRow(
                          label: 'Référence',
                          value: reference,
                        )
                      else ...[
                        Text(
                          'Commande n°$reference',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    _SuccessMetaRow(
                      label: 'Total',
                      value: formattedTotal,
                    ),
                  ],
                ),
              ),
              if (isConnected) ...[
                const SizedBox(height: 12),
                Text(
                  'Vous pouvez suivre son état depuis Mes commandes.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOrders,
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('Voir ma commande'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onHome,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Retour à l’accueil'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onHome,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Retour à l’accueil'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessMetaRow extends StatelessWidget {
  const _SuccessMetaRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({required this.preview});

  final CheckoutPreview preview;

  @override
  Widget build(BuildContext context) {
    final totals = preview.totals;
    return _Panel(
      title: 'Récapitulatif',
      child: Column(
        children: [
          for (final line in preview.lines) _LineStatus(line: line),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Sous-total',
            value: formatMoney(totals.subtotal,
                currency: totals.currency, symbol: totals.currencySymbol),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Livraison', value: totals.shippingLabel),
          if (totals.discounts > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Réductions',
              value: formatMoney(totals.discounts,
                  currency: totals.currency, symbol: totals.currencySymbol),
            ),
          ],
          const Divider(height: 24),
          _SummaryRow(
            label: 'Total TTC',
            value: formatMoney(totals.totalTtc,
                currency: totals.currency, symbol: totals.currencySymbol),
            strong: true,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Taxes incluses',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineStatus extends StatelessWidget {
  const _LineStatus({required this.line});

  final CheckoutLine line;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          line.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('Quantité ${line.quantity}'),
        trailing: Icon(
          line.available ? Icons.check_circle_rounded : Icons.error_rounded,
          color: line.available ? AppColors.leaf : AppColors.danger,
        ),
      ),
    );
  }
}

class _RequiredField extends StatelessWidget {
  const _RequiredField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Champ obligatoire';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MutedLine extends StatelessWidget {
  const _MutedLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softSun,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: strong ? AppColors.ink : AppColors.muted,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: strong ? AppColors.blue : AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _UsedAddressPanel extends StatelessWidget {
  const _UsedAddressPanel({
    required this.address,
    required this.isLoading,
    required this.onManageAddress,
  });

  final AddressModel? address;
  final bool isLoading;
  final VoidCallback onManageAddress;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Adresse de livraison',
      child: isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          : address != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.softBlue,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (address!.fullName.isNotEmpty)
                                Text(
                                  address!.fullName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                ),
                              Text(
                                address!.address1,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                              ),
                              if (address!.address2?.trim().isNotEmpty == true)
                                Text(
                                  address!.address2!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              Text(
                                [address!.postcode, address!.city]
                                    .whereType<String>()
                                    .where((s) => s.trim().isNotEmpty)
                                    .join(' '),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                              ),
                              if (address!.phone?.trim().isNotEmpty == true ||
                                  address!.phoneMobile?.trim().isNotEmpty ==
                                      true) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_rounded,
                                      size: 14,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (address!.phoneMobile
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? address!.phoneMobile
                                              : address!.phone) ??
                                          '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onManageAddress,
                        icon: const Icon(
                          Icons.edit_location_alt_rounded,
                          size: 16,
                        ),
                        label: const Text('Modifier mon adresse'),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.softSun,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.navy,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Aucune adresse enregistrée sur votre compte.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onManageAddress,
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: const Text('Ajouter une adresse de livraison'),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CheckoutPreviewSkeleton extends StatelessWidget {
  const _CheckoutPreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePagePadding(
          bottom: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Panel(
                title: 'Adresse de livraison',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(height: 16),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 240, height: 16),
                    SizedBox(height: 12),
                    _SkeletonBox(width: 180, height: 42),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _Panel(
                title: 'Livraison',
                child: Column(
                  children: [
                    _SkeletonBox(height: 54),
                    SizedBox(height: 8),
                    _SkeletonBox(height: 54),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _Panel(
                title: 'Paiement',
                child: Column(
                  children: [
                    _SkeletonBox(height: 54),
                    SizedBox(height: 8),
                    _SkeletonBox(height: 54),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppSurface(
                padding: const EdgeInsets.all(AppSpacing.xl),
                radius: AppRadii.lg,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 120, height: 18),
                    SizedBox(height: 12),
                    _SkeletonBox(height: 16),
                    SizedBox(height: 8),
                    _SkeletonBox(height: 16),
                    SizedBox(height: 16),
                    _SkeletonBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width,
    required this.height,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    );
  }
}

class _BankWireOrderDialog extends StatelessWidget {
  const _BankWireOrderDialog({
    required this.details,
    required this.reference,
    required this.formattedTotal,
    required this.isConnected,
    required this.onOrders,
    required this.onHome,
  });

  final BankWireDetails details;
  final String? reference;
  final String formattedTotal;
  final bool isConnected;
  final VoidCallback onOrders;
  final VoidCallback onHome;

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label copié dans le presse-papiers.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final owner = details.owner?.trim();
    final rib = details.details?.trim();
    final phone = details.phone?.trim();
    final customText = details.customText?.trim();
    final hasReference = reference != null && reference!.isNotEmpty;
    final hasBankDetails = (owner != null && owner.isNotEmpty) ||
        (rib != null && rib.isNotEmpty) ||
        (phone != null && phone.isNotEmpty) ||
        (customText != null && customText.isNotEmpty);

    Future<void> downloadDetails() async {
      try {
        final pdfData = await rootBundle.load(
          'assets/docs/RIB CIH Heliantha (1).pdf',
        );
        final fileBytes = pdfData.buffer.asUint8List(
          pdfData.offsetInBytes,
          pdfData.lengthInBytes,
        );
        final fileName =
            hasReference ? 'RIB_CIH_Heliantha_$reference' : 'RIB_CIH_Heliantha';
        final savedPath = kIsWeb
            ? await FileSaver.instance.saveFile(
                name: fileName,
                bytes: fileBytes,
                fileExtension: 'pdf',
                mimeType: MimeType.pdf,
              )
            : await FileSaver.instance.saveAs(
                name: fileName,
                bytes: fileBytes,
                fileExtension: 'pdf',
                mimeType: MimeType.pdf,
              );
        if (savedPath != null && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Coordonnées de virement téléchargées.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Telechargement impossible. Reessayez.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
    }

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * 0.94,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Virement bancaire',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: downloadDetails,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Télécharger'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Column(
                    children: [
                      if (hasReference) ...[
                        Text(
                          'Référence de commande',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Text(
                              reference!,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            IconButton(
                              tooltip: 'Copier la référence',
                              onPressed: () => _copy(
                                context,
                                reference!,
                                'Référence de commande',
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 19),
                              color: AppColors.blue,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                      ],
                      _SuccessMetaRow(label: 'Total', value: formattedTotal),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.navy, AppColors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Coordonnées bancaires',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Text(
                              'VIREMENT',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.7,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (owner != null && owner.isNotEmpty)
                        _BankWireField(label: 'Titulaire', value: owner),
                      if (rib != null && rib.isNotEmpty)
                        _BankWireField(
                          label: 'RIB / coordonnées',
                          value: rib,
                          onCopy: () => _copy(context, rib, 'RIB'),
                        ),
                      if (phone != null && phone.isNotEmpty)
                        _BankWireField(label: 'Téléphone', value: phone),
                      if (customText != null && customText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Text(
                            customText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      height: 1.35,
                                    ),
                          ),
                        ),
                      ],
                      if (!hasBankDetails) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.hourglass_top_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Les coordonnées bancaires sont en cours de récupération. Vérifiez votre commande ou contactez Heliantha si elles ne s’affichent pas.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        height: 1.35,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasReference) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softSun,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.navy,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Indiquez impérativement la référence $reference dans le motif de votre virement.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (isConnected) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onOrders,
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('Voir ma commande'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onHome,
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Retour à l’accueil'),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onHome,
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Retour à l’accueil'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BankWireField extends StatelessWidget {
  const _BankWireField({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Copier le RIB',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 19),
              color: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
