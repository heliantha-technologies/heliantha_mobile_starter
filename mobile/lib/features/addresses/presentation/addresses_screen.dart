import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/navigation_helpers.dart';
import '../../../shared/models/address.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/friendly_errors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/addresses_provider.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({
    super.key,
    this.from,
  });

  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentUserProvider);
    if (authState.isLoading ||
        authState.hasError ||
        authState.valueOrNull == null) {
      return Scaffold(
        appBar: AppTopBar(
          subtitle: 'Mes adresses',
          showBack: true,
          backFallbackLocation: from == 'checkout' ? '/checkout' : '/account',
        ),
        body: SafeArea(
          child: authState.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const _AddressesSkeleton(),
            error: (error, _) {
              final friendly = friendlyLoadError(error);
              return ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.cloud_off_rounded,
                  title: friendly.title,
                  message: friendly.message,
                  action: OutlinedButton.icon(
                    onPressed: () => ref.invalidate(currentUserProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ),
              );
            },
            data: (_) => _GuestAddressesPanel(
              onLogin: () => context.push(
                loginLocationFor(
                  from == 'checkout'
                      ? '/addresses?from=checkout'
                      : '/addresses',
                ),
              ),
            ),
          ),
        ),
      );
    }

    final addresses = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppTopBar(
        subtitle: 'Mes adresses',
        showBack: true,
        backFallbackLocation: from == 'checkout' ? '/checkout' : '/account',
      ),
      body: SafeArea(
        child: addresses.when(
          loading: () => const _AddressesSkeleton(),
          error: (error, __) {
            final friendly = friendlyLoadError(error);
            return ResponsivePagePadding(
                child: AppStatusPanel(
              icon: Icons.cloud_off_rounded,
              title: friendly.title,
              message: friendly.message,
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(addressesProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ));
          },
          data: (items) {
            if (items.isEmpty) {
              return ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.location_on_outlined,
                  title: 'Aucune adresse enregistrée',
                  message:
                      'Ajoutez une adresse pour faciliter vos prochaines commandes.',
                  action: FilledButton.icon(
                    onPressed: () => _openAddressForm(context, ref),
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Ajouter une adresse'),
                  ),
                ),
              );
            }

            return Scrollbar(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ResponsivePagePadding(
                    bottom: 104,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _openAddressForm(context, ref),
                            icon: const Icon(Icons.add_location_alt_rounded),
                            label: const Text('Ajouter une adresse'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (var index = 0; index < items.length; index++) ...[
                          _AddressCard(
                            address: items[index],
                            onEdit: () => _openAddressForm(
                              context,
                              ref,
                              address: items[index],
                            ),
                          ),
                          if (index != items.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Future<void> _openAddressForm(
    BuildContext context,
    WidgetRef ref, {
    AddressModel? address,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (_) => _AddressFormSheet(address: address),
    );
    if (saved == true) {
      ref.invalidate(addressesProvider);
    }
  }
}

class _GuestAddressesPanel extends StatelessWidget {
  const _GuestAddressesPanel({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsivePagePadding(
        child: AppSurface(
          padding: const EdgeInsets.all(AppSpacing.xl),
          radius: AppRadii.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.sun,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bienvenue chez HeliAntha',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Connectez-vous pour retrouver vos adresses et faciliter '
                'la livraison de vos prochains équipements solaires.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
  });

  final AddressModel address;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final title = address.alias?.isNotEmpty == true
        ? address.alias!
        : 'Adresse ${address.id}';
    final name = address.fullName;
    final cityLine = [
      address.postcode,
      address.city,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');
    final phone = address.phoneMobile?.isNotEmpty == true
        ? address.phoneMobile
        : address.phone;
    final location = [
      cityLine,
      address.country,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadii.lg,
      onTap: onEdit,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIconBadge(
            icon: Icons.location_on_outlined,
            color: AppColors.blue,
            backgroundColor: AppColors.softBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (name.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (address.company?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    address.company!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  address.address1,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (address.address2?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    address.address2!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (phone?.isNotEmpty == true) ...[
                  const SizedBox(height: 7),
                  InfoPill(
                    icon: Icons.phone_rounded,
                    label: phone!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.edit_location_alt_outlined,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _AddressesSkeleton extends StatelessWidget {
  const _AddressesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsivePagePadding(
            bottom: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: _SkeletonBox(width: 170, height: 46),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < 3; i++) ...[
                  const AppSurface(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    radius: AppRadii.lg,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(width: 44, height: 44),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SkeletonBox(width: 150, height: 16),
                              SizedBox(height: 8),
                              _SkeletonBox(height: 14),
                              SizedBox(height: 7),
                              _SkeletonBox(width: 220, height: 14),
                              SizedBox(height: 10),
                              _SkeletonBox(width: 130, height: 30),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != 2) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  const _AddressFormSheet({this.address});

  final AddressModel? address;

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _alias;
  late final TextEditingController _company;
  late final TextEditingController _address1;
  late final TextEditingController _address2;
  late final TextEditingController _postcode;
  late final TextEditingController _city;
  late final TextEditingController _phone;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.address != null;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    _alias = TextEditingController(text: address?.alias ?? 'Adresse');
    _company = TextEditingController(text: address?.company ?? '');
    _address1 = TextEditingController(text: address?.address1 ?? '');
    _address2 = TextEditingController(text: address?.address2 ?? '');
    _postcode = TextEditingController(text: address?.postcode ?? '');
    _city = TextEditingController(text: address?.city ?? '');
    _phone = TextEditingController(
      text: address?.phoneMobile ?? address?.phone ?? '',
    );
  }

  @override
  void dispose() {
    _alias.dispose();
    _company.dispose();
    _address1.dispose();
    _address2.dispose();
    _postcode.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = {
      'alias': _alias.text.trim(),
      if (_company.text.trim().isNotEmpty) 'company': _company.text.trim(),
      'address1': _address1.text.trim(),
      if (_address2.text.trim().isNotEmpty) 'address2': _address2.text.trim(),
      if (_postcode.text.trim().isNotEmpty) 'postcode': _postcode.text.trim(),
      'city': _city.text.trim(),
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
    };

    try {
      final user = await ref.read(currentUserProvider.future);
      if (!mounted) return;
      if (user == null) {
        const message = 'Connectez-vous pour enregistrer votre adresse.';
        setState(() => _error = message);
        AppFeedback.info(context, message);
        return;
      }
      final repository = ref.read(addressesRepositoryProvider);
      if (_editing) {
        await repository.update(widget.address!.id, payload);
      } else {
        await repository.create(payload);
      }
      if (!mounted) return;
      AppFeedback.success(context, 'Adresse enregistrée');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyAddressSaveMessage(e);
      setState(() => _error = msg);
      AppFeedback.error(context, msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: AppSurface(
        radius: AppRadii.lg,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIconBadge(
                      icon: _editing
                          ? Icons.edit_location_alt_rounded
                          : Icons.add_location_alt_rounded,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _editing ? 'Modifier l’adresse' : 'Ajouter une adresse',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _RequiredField(controller: _alias, label: 'Alias'),
                const SizedBox(height: 12),
                _OptionalField(controller: _company, label: 'Société'),
                const SizedBox(height: 12),
                _AddressField(controller: _address1, label: 'Adresse'),
                const SizedBox(height: 12),
                _AddressField(
                  controller: _address2,
                  label: 'Complément',
                  required: false,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OptionalField(
                        controller: _postcode,
                        label: 'Code postal',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RequiredField(controller: _city, label: 'Ville'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _MoroccoCountryLock(),
                const SizedBox(height: 12),
                _OptionalField(
                  controller: _phone,
                  label: 'Téléphone',
                  keyboardType: TextInputType.phone,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
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

class _MoroccoCountryLock extends StatelessWidget {
  const _MoroccoCountryLock();

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.verified_rounded,
            color: AppColors.leaf,
            backgroundColor: AppColors.softLeaf,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pays',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Maroc',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredField extends StatelessWidget {
  const _RequiredField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Champ obligatoire' : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}

/// Champ adresse tolérant : accepte tout format courant marocain.
/// Validation : non vide après trim + longueur maximale 128 caractères.
/// Aucune regex, aucun format imposé.
class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.controller,
    required this.label,
    this.required = true,
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      validator: (value) {
        final trimmed = (value ?? '').trim();
        if (required && trimmed.isEmpty) {
          return '$label obligatoire';
        }
        if (trimmed.isNotEmpty && trimmed.length > 128) {
          return '$label trop long (max 128 caractères)';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Ex: RTE KENITRA RESIDENCE MHADRA',
        hintStyle: TextStyle(
          color: AppColors.muted.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _OptionalField extends StatelessWidget {
  const _OptionalField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
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
