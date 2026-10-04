import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/home_slide.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/api_url.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../providers/home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static bool _welcomeShownThisSession = false;

  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    if (!_welcomeShownThisSession) {
      _welcomeShownThisSession = true;
      _showWelcome = true;
    }
  }

  void _dismissWelcome() {
    if (!_showWelcome || !mounted) {
      return;
    }
    setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final slides = ref.watch(homeSlidesProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final firstname = user?['firstname']?.toString().trim();

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: "Leader de l'énergie solaire au Maroc",
        actions: [NotificationBell()],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoriesProvider);
              ref.invalidate(homeSlidesProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                ResponsivePagePadding(
                  bottom: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SearchSurface(
                        onSubmitted: (value) {
                          final query = value.trim();
                          if (query.isEmpty) {
                            context.go('/catalog');
                            return;
                          }
                          context.push(
                            '/catalog?q=${Uri.encodeQueryComponent(query)}',
                          );
                        },
                        onFilter: () => context.go('/catalog'),
                      ),
                      const SizedBox(height: 16),
                      slides.when(
                        loading: () => const _HomeSliderLoading(),
                        error: (_, __) => const _HomeSliderFallback(),
                        data: (items) => HomeSlider(
                          slides: items,
                          onOpenProduct: (productId) {
                            context.push('/product/$productId');
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      // 1. ENCART CTA DEVIS SLIM & PRESTIGE (Marine & Or Translucide)
                      const _QuotePromoCtaCard(),
                      const SizedBox(height: 24),
                      // 2. EN-TÊTE ET GRILLE DYNAMIQUE DES UNIVERS SOLAIRES EN 3 COLONNES
                      AppSectionHeader(
                        title: 'Nos Univers Solaires',
                        subtitle: 'Explorez nos équipements par domaine.',
                        actionLabel: 'Voir tout',
                        onAction: () => context.go('/catalog'),
                      ),
                      const SizedBox(height: 14),
                      categories.when(
                        loading: () => const _SolarCategoriesGridSkeleton(),
                        error: (_, __) => const _SolarUniverseGrid(
                          categories: _fallbackSolarCategories,
                        ),
                        data: (items) => _SolarUniverseGrid(
                          categories: items.isNotEmpty
                              ? items
                              : _fallbackSolarCategories,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // 3. SUPPORT WHATSAPP EN PIED DE PAGE
                      const _SupportPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showWelcome)
            _WelcomeSplashOverlay(
              firstname: firstname?.isNotEmpty == true ? firstname : null,
              onDismissed: _dismissWelcome,
            ),
        ],
      ),
    );
  }
}

class _WelcomeSplashOverlay extends StatefulWidget {
  const _WelcomeSplashOverlay({
    required this.firstname,
    required this.onDismissed,
  });

  final String? firstname;
  final VoidCallback onDismissed;

  @override
  State<_WelcomeSplashOverlay> createState() => _WelcomeSplashOverlayState();
}

class _WelcomeSplashOverlayState extends State<_WelcomeSplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _textFade;
  late final Animation<double> _sheen;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2350),
    );
    _fade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 64),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeInOutCubic),
        ),
        weight: 18,
      ),
    ]).animate(_controller);
    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.32, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.46, curve: Curves.easeOutCubic),
    );
    _sheen = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.48, curve: Curves.easeInOutCubic),
    );
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDismissed();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.firstname == null
        ? 'Marhaba 👋'
        : 'Marhaba ${widget.firstname} 👋';

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismiss,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fade.value,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
                child: ColoredBox(
                  color: AppColors.ink.withValues(alpha: 0.08),
                  child: Center(
                    child: Transform.scale(
                      scale: _scale.value,
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surface.withValues(alpha: 0.96),
                      AppColors.surfaceGlow.withValues(alpha: 0.94),
                      const Color(0xFFF6FBFD).withValues(alpha: 0.94),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.premiumLine.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WelcomeLogo(sheen: _sheen),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bienvenue sur Heliantha',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Heureux de vous retrouver ✨',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeLogo extends StatelessWidget {
  const _WelcomeLogo({required this.sheen});

  final Animation<double> sheen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.sun.withValues(alpha: 0.18),
            blurRadius: 34,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: AppColors.sky.withValues(alpha: 0.10),
            blurRadius: 26,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const HelianthaLogo(size: 72, padding: 5, showShadow: true),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: SizedBox(
              width: 72,
              height: 72,
              child: AnimatedBuilder(
                animation: sheen,
                builder: (context, _) {
                  final x = -1.2 + sheen.value * 2.4;
                  return IgnorePointer(
                    child: Align(
                      alignment: Alignment(x, 0),
                      child: Transform.rotate(
                        angle: -0.55,
                        child: Container(
                          width: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.34),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSurface extends StatelessWidget {
  const _SearchSurface({
    required this.onSubmitted,
    required this.onFilter,
  });

  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      hintText: 'Rechercher un produit...',
      leading: const Icon(Icons.search_rounded, color: AppColors.muted),
      trailing: [
        IconButton(
          tooltip: 'Filtres',
          onPressed: onFilter,
          icon: const Icon(Icons.tune_rounded, color: AppColors.blue),
        ),
      ],
      onSubmitted: onSubmitted,
    );
  }
}

class HomeSlider extends StatefulWidget {
  const HomeSlider({
    super.key,
    required this.slides,
    required this.onOpenProduct,
  });

  final List<HomeSlide> slides;
  final ValueChanged<int> onOpenProduct;

  @override
  State<HomeSlider> createState() => _HomeSliderState();
}

class _HomeSliderState extends State<HomeSlider> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;
  final Set<String> _failedSlideIds = {};

  List<HomeSlide> get _visibleSlides => widget.slides
      .where(
        (slide) =>
            slide.imageUrl.trim().isNotEmpty &&
            !_failedSlideIds.contains(slide.id),
      )
      .take(8)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant HomeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length) {
      _index = 0;
      _failedSlideIds.clear();
      _timer?.cancel();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_visibleSlides.length < 2) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final slides = _visibleSlides;
      if (slides.length < 2) {
        return;
      }
      final next = (_index + 1) % slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final slides = _visibleSlides;
    if (slides.isEmpty) {
      return const _HomeSliderFallback();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 380 ? 218.0 : 244.0;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _HomeSlideCard(
                      slide: slide,
                      onImageError: () => _removeSlide(slide.id),
                      onTap: slide.isProduct
                          ? () => widget.onOpenProduct(slide.productId!)
                          : null,
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _SliderDots(
                  count: slides.length,
                  index: _index.clamp(0, slides.length - 1).toInt(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeSlide(String id) {
    if (_failedSlideIds.contains(id)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _failedSlideIds.contains(id)) {
        return;
      }
      setState(() {
        _failedSlideIds.add(id);
        final slides = _visibleSlides;
        if (slides.isEmpty) {
          _index = 0;
        } else if (_index >= slides.length) {
          _index = slides.length - 1;
        }
      });
    });
  }
}

class _HomeSlideCard extends StatelessWidget {
  const _HomeSlideCard({
    required this.slide,
    required this.onTap,
    required this.onImageError,
  });

  final HomeSlide slide;
  final VoidCallback? onTap;
  final VoidCallback onImageError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface,
                AppColors.surfaceGlow,
                Color(0xFFF7FBFD),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.premiumLine),
            boxShadow: AppShadows.soft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                slide.type == 'banner'
                    ? _SlideImage(
                        imageUrl: slide.imageUrl,
                        fit: BoxFit.contain,
                        onError: onImageError,
                      )
                    : _ProductSlide(slide: slide, onImageError: onImageError),
                const _StaticSheen(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductSlide extends StatelessWidget {
  const _ProductSlide({
    required this.slide,
    required this.onImageError,
  });

  final HomeSlide slide;
  final VoidCallback onImageError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: ColoredBox(
                color: AppColors.surface,
                child: _SlideImage(
                  imageUrl: slide.imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  onError: onImageError,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slide.title ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  slide.subtitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Voir',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.sun,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.navy,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlideImage extends StatelessWidget {
  const _SlideImage({
    required this.imageUrl,
    required this.fit,
    this.alignment = Alignment.center,
    this.onError,
  });

  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    final url = absoluteApiUrl(imageUrl);
    if (url.isEmpty) {
      onError?.call();
      return const SizedBox.shrink();
    }

    if (kIsWeb) {
      return Image.network(
        url,
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        headers: const {'Accept': 'image/*'},
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const _SlideImageLoading();
        },
        errorBuilder: (_, __, ___) {
          onError?.call();
          return const SizedBox.shrink();
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: const {'Accept': 'image/*'},
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const _SlideImageLoading(),
      errorWidget: (_, __, ___) {
        onError?.call();
        return const SizedBox.shrink();
      },
    );
  }
}

class _HomeSliderFallback extends StatelessWidget {
  const _HomeSliderFallback();

  @override
  Widget build(BuildContext context) {
    return AppStatusPanel(
      icon: Icons.solar_power_rounded,
      title: 'Découvrez nos solutions solaires',
      message:
          'Parcourez notre catalogue et trouvez les équipements adaptés à votre projet.',
      action: FilledButton.icon(
        onPressed: () => context.go('/catalog'),
        icon: const Icon(Icons.storefront_rounded),
        label: const Text('Voir le catalogue'),
      ),
    );
  }
}

class _SliderDots extends StatelessWidget {
  const _SliderDots({
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == index ? 18 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == index ? AppColors.blue : AppColors.border,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
          ),
      ],
    );
  }
}

class _HomeSliderLoading extends StatelessWidget {
  const _HomeSliderLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 244,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceGlow,
            Color(0xFFF7FBFD),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.premiumLine),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SlideImageLoading extends StatelessWidget {
  const _SlideImageLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _QuotePromoCtaCard extends StatefulWidget {
  const _QuotePromoCtaCard();

  @override
  State<_QuotePromoCtaCard> createState() => _QuotePromoCtaCardState();
}

class _QuotePromoCtaCardState extends State<_QuotePromoCtaCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 0.985 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A192F).withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFFE5A93C).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0A192F).withValues(alpha: 0.92),
                    const Color(0xFF132F5B).withValues(alpha: 0.86),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFE5A93C).withValues(alpha: 0.38),
                  width: 1.1,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -24,
                    right: -20,
                    child: IgnorePointer(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFE5A93C).withValues(alpha: 0.20),
                              const Color(0xFFE5A93C).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5A93C)
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFE5A93C)
                                          .withValues(alpha: 0.45),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Color(0xFFE5A93C),
                                        size: 11.5,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'ÉTUDE & ESTIMATION OFFERTE',
                                        style: TextStyle(
                                          color: Color(0xFFE5A93C),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      color: Color(0xFF94A3B8),
                                      size: 13,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      '~ 2 min',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Besoin d'un dimensionnement personnalisé ?",
                                        maxLines: 2,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                          height: 1.2,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Calculez votre devis en 2 minutes',
                                        style: TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onHighlightChanged: (val) =>
                                        setState(() => _pressed = val),
                                    onTap: () => context.go('/quote'),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFE5A93C),
                                            Color(0xFFF59E0B),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE5A93C)
                                                .withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Calculer mon devis',
                                            style: TextStyle(
                                              color: Color(0xFF0A192F),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              letterSpacing: -0.1,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Color(0xFF0A192F),
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
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

const _fallbackSolarCategories = <Category>[
  Category(id: 3, name: 'Panneaux solaires'),
  Category(id: 4, name: 'Onduleurs hybrides'),
  Category(id: 5, name: 'Pompage solaire'),
  Category(id: 6, name: 'Batteries lithium'),
  Category(id: 7, name: 'Groupes électrogènes'),
  Category(id: 8, name: 'Coffrets de protection'),
];

class _CategoryVisualMeta {
  const _CategoryVisualMeta({
    required this.displayName,
    required this.icon,
    required this.gradient,
    required this.iconColor,
  });

  final String displayName;
  final IconData icon;
  final List<Color> gradient;
  final Color iconColor;
}

_CategoryVisualMeta _getCategoryVisual(Category category) {
  final rawName = category.name.trim();
  final lower = rawName.toLowerCase();

  String displayName = rawName;
  IconData icon = Icons.solar_power_outlined;
  List<Color> gradient = const [Color(0xFFFEF3C7), Color(0xFFFDE68A)];
  Color iconColor = const Color(0xFFB45309);

  if (lower.contains('onduleur')) {
    displayName = 'Onduleurs & Hybrides';
    icon = Icons.electric_bolt_outlined;
    gradient = const [Color(0xFFE0E7FF), Color(0xFFC7D2FE)];
    iconColor = const Color(0xFF3730A3);
  } else if (lower.contains('panneau')) {
    displayName = 'Panneaux Solaires';
    icon = Icons.solar_power_outlined;
    gradient = const [Color(0xFFFEF3C7), Color(0xFFFCD34D)];
    iconColor = const Color(0xFFB45309);
  } else if (lower.contains('off-grid') || lower.contains('off grid')) {
    displayName = 'Hybride Off-Grid';
    icon = Icons.power_off_outlined;
    gradient = const [Color(0xFFEDE9FE), Color(0xFFDDD6FE)];
    iconColor = const Color(0xFF5B21B6);
  } else if (lower.contains('on-grid') || lower.contains('on grid')) {
    displayName = lower.contains('hybride') ? 'Hybride On-Grid' : 'Réseau On-Grid';
    icon = Icons.sync_alt_rounded;
    gradient = const [Color(0xFFEDE9FE), Color(0xFFDDD6FE)];
    iconColor = const Color(0xFF5B21B6);
  } else if (lower.contains('lithium')) {
    displayName = 'Batteries Lithium';
    icon = Icons.battery_saver_rounded;
    gradient = const [Color(0xFFCCFBF1), Color(0xFF99F6E4)];
    iconColor = const Color(0xFF0F766E);
  } else if (lower == 'gel' || lower.contains('batterie gel')) {
    displayName = 'Batteries Gel';
    icon = Icons.battery_std_rounded;
    gradient = const [Color(0xFFCCFBF1), Color(0xFF99F6E4)];
    iconColor = const Color(0xFF0F766E);
  } else if (lower.contains('batterie')) {
    displayName = 'Batteries & Stockage';
    icon = Icons.battery_charging_full_outlined;
    gradient = const [Color(0xFFD1FAE5), Color(0xFFA7F3D0)];
    iconColor = const Color(0xFF065F46);
  } else if (lower.contains('variateurs et pompes')) {
    displayName = 'Pompes & Variateurs';
    icon = Icons.water_drop_outlined;
    gradient = const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)];
    iconColor = const Color(0xFF0284C7);
  } else if (lower.contains('pomp')) {
    displayName = 'Pompage Solaire';
    icon = Icons.water_drop_outlined;
    gradient = const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)];
    iconColor = const Color(0xFF0284C7);
  } else if (lower.contains('variateur')) {
    displayName = 'Variateurs Solaires';
    icon = Icons.speed_outlined;
    gradient = const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)];
    iconColor = const Color(0xFF0284C7);
  } else if (lower.contains('groupe') || lower.contains('electrogene') || lower.contains('électrogène')) {
    displayName = lower.contains('maroc') ? 'Groupes Maroc' : 'Groupes Électrogènes';
    icon = Icons.precision_manufacturing_outlined;
    gradient = const [Color(0xFFFFEDD5), Color(0xFFFED7AA)];
    iconColor = const Color(0xFFC2410C);
  } else if (lower.contains('eclairage') || lower.contains('éclairage')) {
    displayName = lower.contains('eclairages') ? 'Éclairage Extérieur' : 'Éclairage Solaire';
    icon = Icons.wb_incandescent_outlined;
    gradient = const [Color(0xFFFEF9C3), Color(0xFFFEF08A)];
    iconColor = const Color(0xFFA16207);
  } else if (lower.contains('monitoring')) {
    displayName = 'Monitoring & Sécurité';
    icon = Icons.query_stats_outlined;
    gradient = const [Color(0xFFF1F5F9), Color(0xFFE2E8F0)];
    iconColor = const Color(0xFF334155);
  } else if (lower.contains('gadget') || lower.contains('protection') || lower.contains('outillage') || lower.contains('coffret')) {
    displayName = 'Coffrets & Protection';
    icon = Icons.shield_outlined;
    gradient = const [Color(0xFFF1F5F9), Color(0xFFE2E8F0)];
    iconColor = const Color(0xFF334155);
  } else if (lower.contains('goodies')) {
    displayName = 'Goodies & Cadeaux';
    icon = Icons.card_giftcard_outlined;
    gradient = const [Color(0xFFFCE7F3), Color(0xFFFBCFE8)];
    iconColor = const Color(0xFFBE185D);
  } else {
    displayName = rawName.isNotEmpty
        ? rawName[0].toUpperCase() + rawName.substring(1)
        : 'Catégorie';
    icon = Icons.solar_power_outlined;
  }

  return _CategoryVisualMeta(
    displayName: displayName,
    icon: icon,
    gradient: gradient,
    iconColor: iconColor,
  );
}

class _SolarUniverseGrid extends StatelessWidget {
  const _SolarUniverseGrid({
    required this.categories,
  });

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryGlassCard(
          category: category,
          onTap: () => context.push('/catalog?category=${category.id}'),
        );
      },
    );
  }
}

class _CategoryGlassCard extends StatefulWidget {
  const _CategoryGlassCard({
    required this.category,
    required this.onTap,
  });

  final Category category;
  final VoidCallback onTap;

  @override
  State<_CategoryGlassCard> createState() => _CategoryGlassCardState();
}

class _CategoryGlassCardState extends State<_CategoryGlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final meta = _getCategoryVisual(widget.category);

    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 0.96 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.70),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onHighlightChanged: (val) => setState(() => _pressed = val),
                onTap: widget.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: 1.1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: meta.gradient,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: meta.iconColor.withValues(alpha: 0.16),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            meta.icon,
                            size: 22,
                            color: meta.iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              meta.displayName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: 1.16,
                                letterSpacing: -0.2,
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
        ),
      ),
    );
  }
}

class _SolarCategoriesGridSkeleton extends StatelessWidget {
  const _SolarCategoriesGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1.1,
                ),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SupportPanel extends StatefulWidget {
  const _SupportPanel();

  @override
  State<_SupportPanel> createState() => _SupportPanelState();
}

class _SupportPanelState extends State<_SupportPanel> {
  static final Uri _whatsappUrl = Uri.https(
    'wa.me',
    '/212661575128',
    {
      'text':
          'Bonjour Heliantha, je souhaite avoir des informations sur vos solutions énergétiques.',
    },
  );

  bool _hovered = false;

  Future<void> _openWhatsApp() async {
    final opened = await launchUrl(
      _whatsappUrl,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      AppFeedback.error(context, 'Impossible d’ouvrir WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.005 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A192F).withValues(
                  alpha: _hovered ? 0.20 : 0.12,
                ),
                blurRadius: _hovered ? 20 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _openWhatsApp,
                  splashColor: Colors.white.withValues(alpha: 0.08),
                  highlightColor: Colors.white.withValues(alpha: 0.05),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0A192F).withValues(alpha: 0.90),
                          const Color(0xFF132F5B).withValues(alpha: 0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _hovered
                            ? const Color(0xFF25D366).withValues(alpha: 0.60)
                            : Colors.white.withValues(alpha: 0.15),
                        width: 1.1,
                      ),
                    ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final button = _WhatsAppCtaButton(
                    hovered: _hovered,
                    expand: compact,
                  );

                  if (compact) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SupportIcon(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SupportPanelText(),
                              const SizedBox(height: 12),
                              button,
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      const _SupportIcon(),
                      const SizedBox(width: 14),
                      const Expanded(child: _SupportPanelText()),
                      const SizedBox(width: 16),
                      button,
                    ],
                  );
                },
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

class _SupportIcon extends StatelessWidget {
  const _SupportIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: const Icon(
        Icons.support_agent_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _SupportPanelText extends StatelessWidget {
  const _SupportPanelText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Besoin de conseils ?',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Nos équipes vous accompagnent dans votre projet énergétique.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFC9D7E2),
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _WhatsAppCtaButton extends StatelessWidget {
  const _WhatsAppCtaButton({
    required this.hovered,
    required this.expand,
  });

  final bool hovered;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: expand ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: hovered ? AppColors.sun : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: hovered ? AppColors.sun : Colors.white.withValues(alpha: 0.78),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: hovered ? 0.18 : 0.10),
            blurRadius: hovered ? 16 : 10,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_rounded,
            size: 18,
            color: hovered ? AppColors.navy : AppColors.leaf,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Nous contacter sur WhatsApp',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
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
              Color(0x55FFFFFF),
              Color(0x0FFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, 0.3, 0.62],
          ),
        ),
      ),
    );
  }
}
