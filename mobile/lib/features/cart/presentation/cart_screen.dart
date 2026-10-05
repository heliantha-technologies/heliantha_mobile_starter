import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/api_url.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/providers/store_context_provider.dart';
import '../domain/cart_item.dart';
import '../providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final total = ref.watch(cartTotalProvider);
    final currency = items.isEmpty ? 'MAD' : items.first.product.currency;
    final sync = ref.watch(cartSyncStateProvider);

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Votre panier',
        showCart: false,
      ),
      body: SafeArea(
        child: items.isEmpty
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
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  if (wide) {
                    return ResponsivePagePadding(
                      bottom: 104,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _CartList(items: items),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 330,
                            child: _OrderSummary(
                              itemCount: items.length,
                              total: total,
                              currency: currency,
                              isAuthenticated: user != null,
                              sync: sync,
                              onRetry: () => ref
                                  .read(cartProvider.notifier)
                                  .refreshCurrency(
                                    ref.read(selectedCurrencyIdProvider),
                                    force: true,
                                  )
                                  .catchError((Object _) {}),
                            ),
                          ),
                        ],
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CartItemsColumn(items: items),
                              const SizedBox(height: 14),
                              _OrderSummary(
                                itemCount: items.length,
                                total: total,
                                currency: currency,
                                isAuthenticated: user != null,
                                sync: sync,
                                onRetry: () => ref
                                    .read(cartProvider.notifier)
                                    .refreshCurrency(
                                      ref.read(selectedCurrencyIdProvider),
                                      force: true,
                                    )
                                    .catchError((Object _) {}),
                              ),
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
}

class _CartList extends StatelessWidget {
  const _CartList({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 104),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _CartItemCard(item: items[index]),
    );
  }
}

class _CartItemsColumn extends StatelessWidget {
  const _CartItemsColumn({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _CartItemCard(item: items[index]),
          if (index != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = item.product;
    final price = formatMoney(
      product.price,
      currency: product.currency,
      symbol: product.currencySymbol,
    );
    final total = formatMoney(
      item.total,
      currency: product.currency,
      symbol: product.currencySymbol,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final productInfo = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                price,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                total,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        );

        return AppSurface(
          padding: const EdgeInsets.all(AppSpacing.md),
          radius: AppRadii.lg,
          child: compact
              ? Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CartProductImage(imageUrl: product.imageUrl),
                        const SizedBox(width: 12),
                        productInfo,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _QuantityStepper(item: item),
                        const Spacer(),
                        _RemoveButton(item: item),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    _CartProductImage(imageUrl: product.imageUrl),
                    const SizedBox(width: 12),
                    productInfo,
                    const SizedBox(width: 10),
                    _QuantityStepper(item: item),
                    _RemoveButton(item: item),
                  ],
                ),
        );
      },
    );
  }
}

class _CartProductImage extends StatelessWidget {
  const _CartProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = absoluteApiUrl(imageUrl);

    return Container(
      width: 74,
      height: 74,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        // Vérification AVANT tout chargement réseau : si URL vide/null,
        // afficher le placeholder directement (évite texImage2D: no image).
        child: url.isEmpty
            ? const _CartImagePlaceholder()
            : kIsWeb
                ? Image.network(
                    url,
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    headers: const {'Accept': 'image/*'},
                    frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) {
                        return child;
                      }
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: child,
                      );
                    },
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const _CartImagePlaceholder(),
                    errorBuilder: (_, __, ___) => const _CartImagePlaceholder(),
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    httpHeaders: const {'Accept': 'image/*'},
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    fadeInDuration: const Duration(milliseconds: 180),
                    fadeOutDuration: const Duration(milliseconds: 100),
                    placeholder: (_, __) => const _CartImagePlaceholder(),
                    errorWidget: (_, __, ___) => const _CartImagePlaceholder(),
                  ),
      ),
    );
  }
}

/// Placeholder panier — cohérent avec le reste de l'app.
class _CartImagePlaceholder extends StatelessWidget {
  const _CartImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.solar_power_rounded,
        size: 36,
        color: AppColors.blue,
      ),
    );
  }
}

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            tooltip: 'Retirer',
            icon: Icons.remove_rounded,
            onPressed: () {
              ref.read(cartProvider.notifier).decrement(item.product.id);
            },
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          _StepButton(
            tooltip: 'Ajouter',
            icon: Icons.add_rounded,
            onPressed: () {
              ref.read(cartProvider.notifier).add(item.product);
            },
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.blue, size: 19),
      ),
    );
  }
}

class _RemoveButton extends ConsumerWidget {
  const _RemoveButton({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Supprimer',
      onPressed: () {
        ref.read(cartProvider.notifier).remove(item.product.id);
        AppFeedback.info(
          context,
          'Produit retiré du panier',
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () {
              for (var i = 0; i < item.quantity; i++) {
                ref.read(cartProvider.notifier).add(item.product);
              }
            },
          ),
        );
      },
      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.itemCount,
    required this.total,
    required this.currency,
    required this.isAuthenticated,
    required this.sync,
    required this.onRetry,
  });

  final int itemCount;
  final double total;
  final String currency;
  final bool isAuthenticated;
  final AsyncValue<void> sync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final totalText = formatMoney(total, currency: currency);

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Produits', value: '$itemCount'),
          const Divider(height: 26),
          _SummaryRow(label: 'Total', value: totalText, strong: true),
          if (sync.isLoading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Actualisation des prix dans votre devise…'),
          ] else if (sync.hasError) ...[
            const SizedBox(height: 14),
            const Text(
                'Nous n’avons pas pu actualiser les prix. Réessayez pour continuer.'),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: sync.isLoading || sync.hasError
                  ? null
                  : () {
                      if (isAuthenticated) {
                        context.push('/checkout');
                      } else {
                        context.push('/checkout/start');
                      }
                    },
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Commander'),
            ),
          ),
        ],
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
