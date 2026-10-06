import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/navigation_helpers.dart';
import '../../features/cart/providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_vector_icons.dart';

const helianthaLogoAsset = 'assets/brand/helin.jpeg';

class HelianthaLogo extends StatelessWidget {
  const HelianthaLogo({
    super.key,
    this.size = 44,
    this.padding = 4,
    this.showShadow = false,
  });

  final double size;
  final double padding;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surfaceGlow],
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.premiumLine),
        boxShadow: showShadow ? AppShadows.soft : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Image.asset(
          helianthaLogoAsset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: AppSvgIcon(
              AppVectorIcons.logoSun,
              color: AppColors.blue,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.subtitle,
    this.showBack = false,
    this.showCart = true,
    this.actions = const [],
    this.backFallbackLocation,
  });

  final String subtitle;
  final bool showBack;
  final bool showCart;
  final List<Widget> actions;
  final String? backFallbackLocation;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      automaticallyImplyLeading: false,
      flexibleSpace: const _TopBarFinish(),
      shape: const Border(
        bottom: BorderSide(color: AppColors.premiumLine),
      ),
      leading: showBack
          ? IconButton(
              tooltip: 'Retour',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  final fallback = backFallbackLocation;
                  if (fallback != null) {
                    context.go(fallback);
                  }
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      title: HelianthaAppBarTitle(subtitle: subtitle),
      actions: [
        ...actions,
        if (showCart) const AppCartButton(),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _TopBarFinish extends StatelessWidget {
  const _TopBarFinish();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceGlow,
            Color(0xFFF5FBFD),
          ],
        ),
      ),
    );
  }
}

/// Pastille d'action premium pour l'AppBar, stylisée selon l'esthétique
/// chaleureuse, contrastée et vivante des cartes projets de devis solaires.
class TopBarActionPastille extends StatefulWidget {
  const TopBarActionPastille({
    super.key,
    this.icon,
    this.iconWidget,
    this.tooltip,
    this.onTap,
    this.badgeCount = 0,
    this.badgeColor,
    required this.iconColor,
    required this.backgroundColor,
    this.gradientColors,
    required this.borderColor,
    this.shadowColor,
    this.size = 36.0,
    this.iconSize = 19.5,
  }) : assert(icon != null || iconWidget != null, 'Either icon or iconWidget must be provided');

  final IconData? icon;
  final Widget? iconWidget;
  final String? tooltip;
  final VoidCallback? onTap;
  final int badgeCount;
  final Color? badgeColor;
  final Color iconColor;
  final Color backgroundColor;
  final List<Color>? gradientColors;
  final Color borderColor;
  final Color? shadowColor;
  final double size;
  final double iconSize;

  @override
  State<TopBarActionPastille> createState() => _TopBarActionPastilleState();
}

class _TopBarActionPastilleState extends State<TopBarActionPastille> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pastille = AnimatedScale(
      scale: _pressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              gradient: widget.gradientColors != null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.gradientColors!,
                    )
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.borderColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.shadowColor ?? widget.iconColor)
                      .withValues(alpha: 0.16),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: widget.iconWidget ??
                Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: widget.iconSize,
                ),
          ),
          if (widget.badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.5,
                  vertical: 1.5,
                ),
                constraints: const BoxConstraints(
                  minWidth: 17,
                  minHeight: 17,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.badgeColor != null
                        ? [widget.badgeColor!, widget.badgeColor!]
                        : const [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.badgeColor ?? const Color(0xFFEF4444))
                          .withValues(alpha: 0.45),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.badgeCount > 9 ? '9+' : '${widget.badgeCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.onTap == null) {
      final padded = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: pastille,
      );
      if (widget.tooltip != null) {
        return Tooltip(
          message: widget.tooltip!,
          child: padded,
        );
      }
      return padded;
    }

    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: pastille,
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }
    return button;
  }
}

class AppCartButton extends ConsumerWidget {
  const AppCartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      cartProvider.select(
        (items) => items.fold<int>(0, (sum, item) => sum + item.quantity),
      ),
    );

    return TopBarActionPastille(
      tooltip: 'Panier',
      icon: Icons.shopping_cart_rounded,
      iconColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFE0F2FE),
      gradientColors: const [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
      borderColor: const Color(0xFF0284C7).withValues(alpha: 0.35),
      shadowColor: const Color(0xFF0284C7),
      badgeCount: count,
      onTap: () {
        if (Uri.parse(currentLocation(context)).path == '/cart') {
          return;
        }
        context.go('/cart');
      },
    );
  }
}

class HelianthaAppBarTitle extends StatelessWidget {
  const HelianthaAppBarTitle({
    super.key,
    this.subtitle = "Leader de l'énergie solaire au Maroc",
  });

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Accueil',
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: () => context.go('/'),
            child: const HelianthaLogo(size: 38, padding: 3),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HELIANTHA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
