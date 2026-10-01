import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../shared/models/product.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/api_url.dart';
import '../../../shared/utils/friendly_errors.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../favorites/providers/favorites_provider.dart';

class ProductScreen extends ConsumerWidget {
  const ProductScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  final int productId;
  final Product? initialProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productProvider(productId));

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Détail produit',
        showBack: true,
        backFallbackLocation: '/catalog',
      ),
      body: productAsync.when(
        loading: () => initialProduct == null
            ? const _ProductScreenSkeleton()
            : _ProductBody(
                product: initialProduct!,
                isLoadingDetails: true,
              ),
        error: (error, __) {
          if (initialProduct != null) {
            return _ProductBody(product: initialProduct!);
          }

          final friendly = friendlyLoadError(error);
          return ResponsivePagePadding(
            child: AppStatusPanel(
              icon: Icons.cloud_off_rounded,
              title: 'Produit indisponible',
              message: friendly.message,
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(productProvider(productId)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ),
          );
        },
        data: (product) => _ProductBody(product: product),
      ),
    );
  }
}

class _ProductBody extends ConsumerWidget {
  const _ProductBody({
    required this.product,
    this.isLoadingDetails = false,
  });

  final Product product;
  final bool isLoadingDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isFavorite = favorites.contains(product.id);
    final price = formatMoney(
      product.price,
      currency: product.currency,
      symbol: product.currencySymbol,
    );
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePagePadding(
          bottom: 96,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final image = _ProductImage(
                imageUrl: product.imageUrl,
                height: wide ? 430 : 310,
              );
              final summary = _ProductSummary(
                name: product.name,
                reference: product.reference,
                price: price,
                available: product.available,
                isFavorite: isFavorite,
                onToggleFavorite: () {
                  if (user == null) {
                    openLoginForCurrentLocation(context);
                    return;
                  }
                  ref.read(favoritesProvider.notifier).toggle(product.id);
                  AppFeedback.info(
                    context,
                    isFavorite ? 'Retiré des favoris' : 'Ajouté aux favoris',
                    action: SnackBarAction(
                      label: 'Voir',
                      onPressed: () => context.go('/favorites'),
                    ),
                  );
                },
                onAddToCart: () {
                  ref.read(cartProvider.notifier).add(product);
                  AppFeedback.success(
                    context,
                    'Ajouté au panier',
                    action: SnackBarAction(
                      label: 'Voir',
                      onPressed: () => context.go('/cart'),
                    ),
                  );
                },
                onShare: () => _shareProduct(context, product, price),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: image),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              summary,
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    image,
                    const SizedBox(height: 14),
                    summary,
                  ],
                  const SizedBox(height: 16),
                  _ProductInformationTabs(
                    product: product,
                    isLoadingDetails: isLoadingDetails,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.height,
  });

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = absoluteApiUrl(imageUrl);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: AppSurface(
        padding: const EdgeInsets.all(14),
        radius: AppRadii.lg,
        child: url.isEmpty
            ? const _ProductImageFallback()
            : ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: _ProductImagePreview(url: url),
              ),
      ),
    );
  }
}

class _ProductImagePreview extends StatefulWidget {
  const _ProductImagePreview({required this.url});

  final String url;

  @override
  State<_ProductImagePreview> createState() => _ProductImagePreviewState();
}

class _ProductImagePreviewState extends State<_ProductImagePreview> {
  bool _hovered = false;

  Future<void> _openViewer() {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.86),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => _ProductImageViewer(url: widget.url),
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        label: 'Agrandir l’image produit',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openViewer,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ProductNetworkImage(url: widget.url),
              Positioned(
                right: 10,
                bottom: 10,
                child: Tooltip(
                  message: 'Agrandir',
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _hovered ? 1 : 0.82,
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.74),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: const Icon(
                        Icons.zoom_in_rounded,
                        size: 21,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImageViewer extends StatefulWidget {
  const _ProductImageViewer({required this.url});

  final String url;

  @override
  State<_ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<_ProductImageViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _controller;
  Animation<Matrix4>? _animation;
  late final AnimationController _animationController;
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        final animation = _animation;
        if (animation != null) {
          _controller.value = animation.value;
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _animationController.stop();
    _animation = Matrix4Tween(
      begin: _controller.value,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward(from: 0);
  }

  void _resetZoom() {
    _animateTo(Matrix4.identity());
  }

  void _zoomBy(double delta) {
    final current = _controller.value.getMaxScaleOnAxis();
    final next = (current + delta).clamp(1.0, 5.0);
    final matrix = Matrix4.copy(_controller.value);
    final factor = next / current;
    matrix.storage[0] *= factor;
    matrix.storage[5] *= factor;
    matrix.storage[10] *= factor;
    _animateTo(matrix);
  }

  void _toggleDoubleTapZoom() {
    final current = _controller.value.getMaxScaleOnAxis();
    if (current > 1.01) {
      _resetZoom();
      return;
    }

    const targetScale = 2.5;
    final position = _doubleTapPosition;
    final matrix = Matrix4.identity();
    matrix.storage[0] = targetScale;
    matrix.storage[5] = targetScale;
    matrix.storage[10] = targetScale;
    matrix.storage[12] = -position.dx * (targetScale - 1);
    matrix.storage[13] = -position.dy * (targetScale - 1);
    _animateTo(matrix);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTapDown: (details) {
                        _doubleTapPosition = details.localPosition;
                      },
                      onDoubleTap: _toggleDoubleTapZoom,
                      child: InteractiveViewer(
                        transformationController: _controller,
                        minScale: 1,
                        maxScale: 5,
                        boundaryMargin: const EdgeInsets.all(80),
                        child: Center(
                          child: _ProductNetworkImage(url: widget.url),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Tooltip(
                      message: 'Fermer',
                      child: _ViewerIconButton(
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                  if (kIsWeb)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: 'Zoom arrière',
                                  child: _ViewerIconButton(
                                    icon: Icons.remove_rounded,
                                    onPressed: () => _zoomBy(-0.5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Réinitialiser',
                                  child: _ViewerIconButton(
                                    icon: Icons.center_focus_strong_rounded,
                                    onPressed: _resetZoom,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Zoom avant',
                                  child: _ViewerIconButton(
                                    icon: Icons.add_rounded,
                                    onPressed: () => _zoomBy(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerIconButton extends StatelessWidget {
  const _ViewerIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: IconButton(
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

class _ProductNetworkImage extends StatelessWidget {
  const _ProductNetworkImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
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
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const _ProductImageLoading();
        },
        errorBuilder: (_, __, ___) => const _ProductImageFallback(),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: const {'Accept': 'image/*'},
      fit: BoxFit.contain,
      placeholder: (_, __) => const _ProductImageLoading(),
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 100),
      errorWidget: (_, __, ___) => const _ProductImageFallback(),
    );
  }
}

class _ProductImageLoading extends StatelessWidget {
  const _ProductImageLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: const Icon(
            Icons.solar_power_rounded,
            color: AppColors.blue,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.solar_power_rounded,
        color: AppColors.blue,
        size: 72,
      ),
    );
  }
}

class _ProductScreenSkeleton extends StatelessWidget {
  const _ProductScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePagePadding(
          bottom: 96,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final image = AppSurface(
                padding: const EdgeInsets.all(14),
                radius: AppRadii.lg,
                child: _SkeletonBox(height: wide ? 402 : 282),
              );
              final summary = AppSurface(
                padding: const EdgeInsets.all(AppSpacing.xl),
                radius: AppRadii.lg,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 110, height: 28),
                    SizedBox(height: 12),
                    _SkeletonBox(height: 24),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 220, height: 24),
                    SizedBox(height: 16),
                    _SkeletonBox(width: 130, height: 28),
                    SizedBox(height: 18),
                    _SkeletonBox(width: 168, height: 46),
                    SizedBox(height: 10),
                    _SkeletonBox(width: 168, height: 46),
                  ],
                ),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: image),
                        const SizedBox(width: 20),
                        Expanded(child: summary),
                      ],
                    )
                  else ...[
                    image,
                    const SizedBox(height: 14),
                    summary,
                  ],
                  const SizedBox(height: 16),
                  const AppSurface(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    radius: AppRadii.lg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _SkeletonBox(width: 118, height: 44),
                            SizedBox(width: 8),
                            _SkeletonBox(width: 150, height: 44),
                          ],
                        ),
                        SizedBox(height: 18),
                        _SkeletonBox(height: 16),
                        SizedBox(height: 8),
                        _SkeletonBox(height: 16),
                        SizedBox(height: 8),
                        _SkeletonBox(width: 240, height: 16),
                      ],
                    ),
                  ),
                ],
              );
            },
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

const _productShareChannel = MethodChannel('ma.heliantha.mobile/share');

Future<void> _shareProduct(
  BuildContext context,
  Product product,
  String price,
) async {
  final productUrl = AppConfig.productShareUrl(product.id);
  final reference = product.reference?.trim();
  final text = [
    'Découvrez ce produit Heliantha :',
    product.name.trim(),
    if (reference != null && reference.isNotEmpty) 'Réf. $reference',
    price,
    productUrl,
  ].join('\n');

  try {
    await _productShareChannel.invokeMethod<void>('shareText', {
      'subject': '${product.name} - Heliantha',
      'text': text,
    });
  } on PlatformException {
    await Clipboard.setData(ClipboardData(text: productUrl));
    if (context.mounted) {
      AppFeedback.info(context, 'Lien produit copié');
    }
  } on MissingPluginException {
    await Clipboard.setData(ClipboardData(text: productUrl));
    if (context.mounted) {
      AppFeedback.info(context, 'Lien produit copié');
    }
  }
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({
    required this.name,
    required this.reference,
    required this.price,
    required this.available,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToCart,
    required this.onShare,
  });

  final String name;
  final String? reference;
  final String price;
  final bool available;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToCart;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(
                icon: available
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                label: available ? 'En stock' : 'Indisponible',
                backgroundColor:
                    available ? AppColors.softLeaf : const Color(0xFFFFEFEF),
                foregroundColor: available ? AppColors.leaf : AppColors.danger,
              ),
              if (reference?.isNotEmpty == true)
                InfoPill(
                  icon: Icons.tag_rounded,
                  label: 'Réf. $reference',
                  backgroundColor: AppColors.softBlue,
                  foregroundColor: AppColors.blue,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            price,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: available ? onAddToCart : null,
                icon: const Icon(Icons.shopping_cart_rounded),
                label: const Text('Ajouter au panier'),
              ),
              OutlinedButton.icon(
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                ),
                label: Text(isFavorite ? 'Favori' : 'Ajouter aux favoris'),
              ),
              Tooltip(
                message: 'Partager le produit',
                child: SizedBox.square(
                  dimension: 44,
                  child: OutlinedButton(
                    onPressed: onShare,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: const Icon(Icons.share_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductInformationTabs extends StatefulWidget {
  const _ProductInformationTabs({
    required this.product,
    required this.isLoadingDetails,
  });

  final Product product;
  final bool isLoadingDetails;

  @override
  State<_ProductInformationTabs> createState() =>
      _ProductInformationTabsState();
}

class _ProductInformationTabsState extends State<_ProductInformationTabs> {
  int _index = 0;

  Product get product => widget.product;

  @override
  Widget build(BuildContext context) {
    final description = product.description?.trim().isNotEmpty == true
        ? product.description!.trim()
        : product.descriptionShort?.trim();
    final technicalDetails = product.technicalDetails?.trim();
    const tabs = ['Description', 'Détails techniques'];
    final effectiveIndex = _index.clamp(0, tabs.length - 1).toInt();
    final content = effectiveIndex == 0
        ? _tabContent(
            html: description,
            contentKey: 'description',
            loadingKey: 'description-loading',
            emptyKey: 'description-empty',
            emptyMessage:
                'La description n’est pas disponible pour ce produit.',
          )
        : _tabContent(
            html: technicalDetails,
            contentKey: 'technical-details',
            loadingKey: 'technical-details-loading',
            emptyKey: 'technical-details-empty',
            emptyMessage:
                'Les détails techniques ne sont pas disponibles pour ce produit.',
          );

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _ProductInfoTabButton(
                  label: tabs[i],
                  icon: i == 0 ? Icons.article_outlined : Icons.tune_rounded,
                  selected: effectiveIndex == i,
                  onTap: () => setState(() => _index = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _tabContent({
    required String? html,
    required String contentKey,
    required String loadingKey,
    required String emptyKey,
    required String emptyMessage,
  }) {
    if (html?.isNotEmpty == true) {
      return _HtmlDescription(
        key: ValueKey(contentKey),
        html: html!,
      );
    }
    if (widget.isLoadingDetails) {
      return _ProductInfoLoading(key: ValueKey(loadingKey));
    }
    return _EmptyProductInfoMessage(
      key: ValueKey(emptyKey),
      message: emptyMessage,
    );
  }
}

class _ProductInfoLoading extends StatelessWidget {
  const _ProductInfoLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(
          'Chargement des informations produit...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.5,
              ),
        ),
      ],
    );
  }
}

class _ProductInfoTabButton extends StatefulWidget {
  const _ProductInfoTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ProductInfoTabButton> createState() => _ProductInfoTabButtonState();
}

class _ProductInfoTabButtonState extends State<_ProductInfoTabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final foreground = selected ? Colors.white : AppColors.navy;
    final background = selected
        ? AppColors.blue
        : _hovered
            ? AppColors.softBlue
            : AppColors.surface;
    final borderColor = selected
        ? AppColors.blue
        : _hovered
            ? AppColors.blue.withValues(alpha: 0.48)
            : AppColors.premiumLine;
    final shadowColor = selected
        ? AppColors.blue.withValues(alpha: 0.22)
        : AppColors.navy.withValues(alpha: _hovered ? 0.10 : 0.06);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.01 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: widget.onTap,
                splashColor: AppColors.blue.withValues(alpha: 0.10),
                highlightColor: AppColors.blue.withValues(alpha: 0.06),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 190),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: borderColor, width: 1.15),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: selected || _hovered ? 14 : 9,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: 17,
                        color: foreground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 190),
              curve: Curves.easeOutCubic,
              width: selected ? 22 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.sun,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProductInfoMessage extends StatelessWidget {
  const _EmptyProductInfoMessage({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      key: key,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
            height: 1.5,
          ),
    );
  }
}

class _HtmlDescription extends StatelessWidget {
  const _HtmlDescription({
    super.key,
    required this.html,
  });

  final String html;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseHtmlBlocks(html);
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          _HtmlBlockView(block: blocks[i]),
          if (i != blocks.length - 1) SizedBox(height: blocks[i].spacingAfter),
        ],
      ],
    );
  }
}

class _HtmlBlockView extends StatelessWidget {
  const _HtmlBlockView({required this.block});

  final _HtmlBlock block;

  @override
  Widget build(BuildContext context) {
    final style = switch (block.type) {
      _HtmlBlockType.heading => Theme.of(context).textTheme.titleMedium,
      _ => Theme.of(context).textTheme.bodyMedium,
    };
    final textStyle = style?.copyWith(
      color: block.type == _HtmlBlockType.heading
          ? AppColors.ink
          : AppColors.muted,
      fontWeight: block.type == _HtmlBlockType.heading ? FontWeight.w900 : null,
      height: block.type == _HtmlBlockType.heading ? 1.25 : 1.5,
    );
    final richText = Text.rich(
      TextSpan(
        style: textStyle,
        children: _parseInlineSpans(block.html, textStyle),
      ),
    );

    if (block.type != _HtmlBlockType.listItem &&
        block.type != _HtmlBlockType.orderedListItem) {
      return richText;
    }

    final marker = block.type == _HtmlBlockType.orderedListItem
        ? '${block.order ?? 1}.'
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 16,
          child: marker == null
              ? Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : Text(
                  marker,
                  style: textStyle?.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(child: richText),
      ],
    );
  }
}

enum _HtmlBlockType { paragraph, heading, listItem, orderedListItem }

class _HtmlBlock {
  const _HtmlBlock({
    required this.type,
    required this.html,
    this.order,
  });

  final _HtmlBlockType type;
  final String html;
  final int? order;

  double get spacingAfter => type == _HtmlBlockType.heading ? 10 : 8;
}

List<_HtmlBlock> _parseHtmlBlocks(String html) {
  final normalized = html.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  final blocks = <_HtmlBlock>[];
  final pattern = RegExp(
    r'<ul[^>]*>(.*?)</ul>|<ol[^>]*>(.*?)</ol>|<h[1-6][^>]*>(.*?)</h[1-6]>|<li[^>]*>(.*?)</li>|<p[^>]*>(.*?)</p>',
    caseSensitive: false,
    dotAll: true,
  );
  var lastEnd = 0;

  for (final match in pattern.allMatches(normalized)) {
    _addPlainTextBlocks(blocks, normalized.substring(lastEnd, match.start));
    if (match.group(1) != null) {
      _addListBlocks(blocks, match.group(1)!, ordered: false);
    } else if (match.group(2) != null) {
      _addListBlocks(blocks, match.group(2)!, ordered: true);
    } else if (match.group(3) != null) {
      blocks.add(
        _HtmlBlock(type: _HtmlBlockType.heading, html: match.group(3)!),
      );
    } else if (match.group(4) != null) {
      blocks.add(
        _HtmlBlock(type: _HtmlBlockType.listItem, html: match.group(4)!),
      );
    } else if (match.group(5) != null) {
      _addParagraphBlocks(blocks, match.group(5)!);
    }
    lastEnd = match.end;
  }

  _addPlainTextBlocks(blocks, normalized.substring(lastEnd));
  return blocks
      .where((block) => _cleanText(block.html).isNotEmpty)
      .toList(growable: false);
}

void _addListBlocks(
  List<_HtmlBlock> blocks,
  String html, {
  required bool ordered,
}) {
  final itemPattern = RegExp(
    r'<li[^>]*>(.*?)</li>',
    caseSensitive: false,
    dotAll: true,
  );
  var index = 1;
  for (final match in itemPattern.allMatches(html)) {
    final item = match.group(1);
    if (_cleanText(item).isEmpty) {
      continue;
    }
    blocks.add(
      _HtmlBlock(
        type:
            ordered ? _HtmlBlockType.orderedListItem : _HtmlBlockType.listItem,
        html: item!,
        order: ordered ? index : null,
      ),
    );
    index++;
  }
}

void _addParagraphBlocks(List<_HtmlBlock> blocks, String html) {
  for (final line in html.split('\n')) {
    _addLineBlock(blocks, line);
  }
}

void _addPlainTextBlocks(List<_HtmlBlock> blocks, String value) {
  for (final line in value.split('\n')) {
    _addLineBlock(blocks, line);
  }
}

void _addLineBlock(List<_HtmlBlock> blocks, String line) {
  if (_cleanText(line).isEmpty) {
    return;
  }

  final trimmed = line.trimLeft();
  final listMarker = RegExp(r'^(?:[-*]|\u2022|\u25E6|\u25AA|\u25AB)\s+');
  if (listMarker.hasMatch(_cleanText(trimmed))) {
    blocks.add(
      _HtmlBlock(
        type: _HtmlBlockType.listItem,
        html: trimmed.replaceFirst(listMarker, ''),
      ),
    );
    return;
  }

  blocks.add(_HtmlBlock(type: _HtmlBlockType.paragraph, html: line));
}

List<InlineSpan> _parseInlineSpans(String html, TextStyle? baseStyle) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(
    r'<(?:strong|b)[^>]*>(.*?)</(?:strong|b)>|<(?:em|i)[^>]*>(.*?)</(?:em|i)>',
    caseSensitive: false,
    dotAll: true,
  );
  var lastEnd = 0;

  for (final match in pattern.allMatches(html)) {
    final before = _cleanText(html.substring(lastEnd, match.start));
    if (before.isNotEmpty) {
      spans.add(TextSpan(text: before));
    }
    final strongText = _cleanText(match.group(1));
    if (strongText.isNotEmpty) {
      spans.add(
        TextSpan(
          text: strongText,
          style: baseStyle?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    final emphasizedText = _cleanText(match.group(2));
    if (emphasizedText.isNotEmpty) {
      spans.add(
        TextSpan(
          text: emphasizedText,
          style: baseStyle?.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }
    lastEnd = match.end;
  }

  final tail = _cleanText(html.substring(lastEnd));
  if (tail.isNotEmpty) {
    spans.add(TextSpan(text: tail));
  }
  return spans;
}

String _cleanText(String? value) {
  if (value == null) {
    return '';
  }

  return _decodeHtmlEntities(value)
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _decodeHtmlEntities(String value) {
  final named = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&quot;': '"',
    '&apos;': "'",
    '&#039;': "'",
    '&rsquo;': "'",
    '&lsquo;': "'",
    '&ldquo;': '"',
    '&rdquo;': '"',
    '&eacute;': 'é',
    '&egrave;': 'è',
    '&ecirc;': 'ê',
    '&agrave;': 'à',
    '&ccedil;': 'ç',
    '&ocirc;': 'ô',
    '&ugrave;': 'ù',
    '&deg;': '°',
    '&ndash;': '-',
    '&mdash;': '-',
    '&times;': '×',
    '&le;': '≤',
    '&ge;': '≥',
  };
  var output = value.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (match) {
      final codePoint = int.tryParse(match.group(1)!, radix: 16);
      return codePoint == null
          ? match.group(0)!
          : String.fromCharCode(codePoint);
    },
  );
  output = output.replaceAllMapped(
    RegExp(r'&#([0-9]+);'),
    (match) {
      final codePoint = int.tryParse(match.group(1)!);
      return codePoint == null
          ? match.group(0)!
          : String.fromCharCode(codePoint);
    },
  );
  for (final entry in named.entries) {
    output = output.replaceAll(entry.key, entry.value);
  }
  return output;
}
