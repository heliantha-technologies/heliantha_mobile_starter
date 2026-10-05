import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/product.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/api_url.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favoritesProvider).toList()..sort();

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Vos favoris',
      ),
      body: SafeArea(
        child: ids.isEmpty
            ? ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.favorite_border_rounded,
                  title: 'Aucun favori pour le moment',
                  message:
                      'Ajoutez vos produits préférés pour les retrouver facilement ici.',
                  action: FilledButton.icon(
                    onPressed: () => context.go('/catalog'),
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('Voir les produits'),
                  ),
                ),
              )
            : Scrollbar(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ResponsivePagePadding(
                      bottom: 104,
                      child: Column(
                        children: [
                          for (var index = 0; index < ids.length; index++) ...[
                            _FavoriteProductCard(productId: ids[index]),
                            if (index != ids.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FavoriteProductCard extends ConsumerWidget {
  const _FavoriteProductCard({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));

    return product.when(
      loading: () => const _FavoriteShell(child: _FavoriteSkeletonTile()),
      error: (_, __) => _FavoriteShell(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ce produit n’est plus disponible pour le moment.',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Retirer',
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggle(productId);
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
      data: (item) => _FavoriteProductTile(product: item),
    );
  }
}

class _FavoriteProductTile extends ConsumerWidget {
  const _FavoriteProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = formatMoney(
      product.price,
      currency: product.currency,
      symbol: product.currencySymbol,
    );

    return _FavoriteShell(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => context.push('/product/${product.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _FavoriteImage(
                key: ValueKey('favorite-product-image-${product.id}'),
                imageUrl: product.imageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
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
                            height: 1.22,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      price,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Retirer des favoris',
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggle(product.id);
                  AppFeedback.info(
                    context,
                    'Retiré des favoris',
                    action: SnackBarAction(
                      label: 'Annuler',
                      onPressed: () {
                        ref.read(favoritesProvider.notifier).toggle(product.id);
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.favorite, color: AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteShell extends StatelessWidget {
  const _FavoriteShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: EdgeInsets.zero,
      radius: AppRadii.lg,
      child: child,
    );
  }
}

class _FavoriteImage extends StatelessWidget {
  const _FavoriteImage({super.key, required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = absoluteApiUrl(imageUrl);
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: url.isEmpty
          ? const _FavoriteImagePlaceholder()
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: kIsWeb
                  ? Image.network(
                      url,
                      width: double.infinity,
                      height: double.infinity,
                      cacheWidth: 400,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      headers: const {'Accept': 'image/*'},
                      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: child,
                        );
                      },
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const _FavoriteImagePlaceholder(),
                      errorBuilder: (_, __, ___) =>
                          const _FavoriteImagePlaceholder(),
                    )
                  : CachedNetworkImage(
                      imageUrl: url,
                      httpHeaders: const {'Accept': 'image/*'},
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: 200,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      fadeInDuration: const Duration(milliseconds: 180),
                      fadeOutDuration: const Duration(milliseconds: 100),
                      placeholder: (_, __) => const _FavoriteImagePlaceholder(),
                      errorWidget: (_, __, ___) =>
                          const _FavoriteImagePlaceholder(),
                    ),
            ),
    );
  }
}

class _FavoriteSkeletonTile extends StatelessWidget {
  const _FavoriteSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          _SkeletonBox(width: 72, height: 72),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(height: 16),
                SizedBox(height: 8),
                _SkeletonBox(width: 180, height: 16),
                SizedBox(height: 10),
                _SkeletonBox(width: 110, height: 20),
              ],
            ),
          ),
          SizedBox(width: 12),
          _SkeletonBox(width: 44, height: 44),
        ],
      ),
    );
  }
}

class _FavoriteImagePlaceholder extends StatelessWidget {
  const _FavoriteImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.solar_power_rounded,
          color: AppColors.blue,
          size: 28,
        ),
      ),
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
