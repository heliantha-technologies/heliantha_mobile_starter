import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/navigation_helpers.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/cart/providers/cart_provider.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../models/product.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/api_url.dart';
import '../utils/money.dart';
import 'app_feedback.dart';
import 'app_ui.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(
      favoritesProvider.select((favorites) => favorites.contains(product.id)),
    );
    final isLoggedIn = ref.watch(
      currentUserProvider.select((user) => user.valueOrNull != null),
    );
    final price = formatMoney(
      product.price,
      currency: product.currency,
      symbol: product.currencySymbol,
    );

    return AppSurface(
      padding: EdgeInsets.zero,
      radius: AppRadii.lg,
      shadow: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.surface,
                            AppColors.surfaceMuted,
                            AppColors.softBlue,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _ProductCardImage(imageUrl: product.imageUrl),
                          const _StaticSheen(),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 7,
                    top: 7,
                    child: _RoundIconButton(
                      tooltip: isFavorite
                          ? 'Retirer des favoris'
                          : 'Ajouter aux favoris',
                      icon: isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? AppColors.danger : AppColors.navy,
                      onPressed: () {
                        if (!isLoggedIn) {
                          openLoginForCurrentLocation(context);
                          return;
                        }
                        HapticFeedback.selectionClick();
                        ref.read(favoritesProvider.notifier).toggle(product.id);
                        AppFeedback.info(
                          context,
                          isFavorite
                              ? 'Retiré des favoris'
                              : 'Ajouté aux favoris',
                          action: SnackBarAction(
                            label: 'Voir',
                            onPressed: () => context.go('/favorites'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              price,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final canShowStatus = width >= 88;
                final showStatusLabel = width >= 138;

                if (!canShowStatus) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: _CartButton(
                      enabled: product.available,
                      onPressed: () => _addToCart(context, ref),
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _AvailabilityPill(
                        available: product.available,
                        showLabel: showStatusLabel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CartButton(
                      enabled: product.available,
                      onPressed: () => _addToCart(context, ref),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    ref.read(cartProvider.notifier).add(product);
    AppFeedback.success(
      context,
      'Ajouté au panier',
      action: SnackBarAction(
        label: 'Voir',
        onPressed: () => context.go('/cart'),
      ),
    );
  }
}

class _StaticSheen extends StatelessWidget {
  const _StaticSheen();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0x66FFFFFF),
              Color(0x11FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, 0.34, 0.68],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({
    required this.available,
    required this.showLabel,
  });

  final bool available;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.leaf : AppColors.danger;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: available ? AppColors.softLeaf : const Color(0xFFFFEFEF),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: color,
          ),
          if (showLabel) ...[
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                available ? 'En stock' : 'Rupture',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductCardImage extends StatelessWidget {
  const _ProductCardImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = absoluteApiUrl(imageUrl);
    if (url.isEmpty) {
      return const _FallbackProductImage();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Transform.scale(
        scale: 1.00,
        child: kIsWeb
            ? Image.network(
                url,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 400,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                alignment: Alignment.center,
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
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const _ImageLoading();
                },
                errorBuilder: (_, __, ___) => const _FallbackProductImage(),
              )
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: const {'Accept': 'image/*'},
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: 400,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                alignment: Alignment.center,
                placeholder: (_, __) => const _ImageLoading(),
                fadeInDuration: const Duration(milliseconds: 180),
                fadeOutDuration: const Duration(milliseconds: 100),
                errorWidget: (_, __, ___) => const _FallbackProductImage(),
              ),
      ),
    );
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return const _FallbackProductImage(soft: true);
  }
}

class _CartButton extends StatefulWidget {
  const _CartButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<_CartButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.enabled ? AppColors.blue : AppColors.border;
    final foregroundColor = widget.enabled ? Colors.white : AppColors.muted;

    return Tooltip(
      message: 'Ajouter au panier',
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.98 : (_hovered && widget.enabled ? 1.01 : 1),
          child: SizedBox.square(
            dimension: 44,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                onTap: widget.enabled ? widget.onPressed : null,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) => setState(() => _pressed = false),
                splashColor: Colors.white.withValues(alpha: 0.12),
                highlightColor: Colors.white.withValues(alpha: 0.06),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      boxShadow: _hovered && widget.enabled
                          ? [
                              BoxShadow(
                                color: AppColors.blue.withValues(alpha: 0.20),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.add_shopping_cart_rounded,
                      size: 19,
                      color: foregroundColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatefulWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.98 : (_hovered ? 1.01 : 1),
          child: SizedBox.square(
            dimension: 44,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: widget.onPressed,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) => setState(() => _pressed = false),
                splashColor: AppColors.blue.withValues(alpha: 0.08),
                highlightColor: AppColors.blue.withValues(alpha: 0.04),
                child: Align(
                  alignment: Alignment.topRight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      boxShadow: _hovered ? AppShadows.soft : null,
                    ),
                    child: Icon(widget.icon, size: 19, color: widget.color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackProductImage extends StatelessWidget {
  const _FallbackProductImage({this.soft = false});

  final bool soft;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: soft ? AppColors.surfaceMuted : Colors.transparent,
      child: const Center(
        child: Icon(
          Icons.solar_power_rounded,
          size: 54,
          color: AppColors.blue,
        ),
      ),
    );
  }
}
