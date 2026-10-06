import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
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
  static const _welcomeSeenKey = 'has_seen_welcome_splash';

  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    unawaited(_showWelcomeIfNeeded());
  }

  Future<void> _showWelcomeIfNeeded() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted || preferences.getBool(_welcomeSeenKey) == true) {
        return;
      }
      setState(() => _showWelcome = true);
      await preferences.setBool(_welcomeSeenKey, true);
    } catch (_) {
      // L'accueil reste accessible même si le stockage local est indisponible.
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
                      const _QuoteUsageShortcuts(),
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
                      // Six univers principaux, indépendants des sous-catégories.
                      AppSectionHeader(
                        title: 'Nos Univers Solaires',
                        subtitle: 'Explorez nos équipements par domaine.',
                        actionLabel: 'Voir tout',
                        onAction: () => context.go('/catalog?categories=1'),
                      ),
                      const SizedBox(height: 14),
                      categories.when(
                        loading: () => const _SolarCategoriesGridSkeleton(),
                        error: (_, __) => const _SolarUniverseGrid(
                          categories: [],
                        ),
                        data: (items) => _SolarUniverseGrid(
                          categories: items,
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

class _QuoteUsageShortcuts extends StatelessWidget {
  const _QuoteUsageShortcuts();

  static const _shortcuts = [
    (label: '🌾 Pompage Agricole', projectType: 'pompage'),
    (label: '🔋 Solaire avec batteries', projectType: 'hybride'),
    (label: '📉 Réduire ma facture', projectType: 'autoconsommation'),
  ];

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < _shortcuts.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Semantics(
              button: true,
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: borderRadius,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: InkWell(
                  borderRadius: borderRadius,
                  onTap: () => context.push(
                    '/quote/form/${_shortcuts[index].projectType}',
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        _shortcuts[index].label,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
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
    if (_dismissing) {
      return;
    }
    _controller.stop();
    setState(() => _dismissing = true);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.firstname == null
        ? 'Marhaba 👋'
        : 'Marhaba ${widget.firstname} 👋';
    final subtitle = widget.firstname == null
        ? 'Bienvenue chez HeliAntha'
        : 'Heureux de vous retrouver ✨';

    return Positioned.fill(
      child: AnimatedOpacity(
        key: const ValueKey('home-welcome-overlay'),
        opacity: _dismissing ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        onEnd: () {
          if (_dismissing) {
            widget.onDismissed();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
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
                            subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
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
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(8),
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
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    slide.title ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          height: 1.18,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  slide.subtitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
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
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.sun,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.navy,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
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

class _QuotePromoCtaCardState extends State<_QuotePromoCtaCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _attentionController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _attentionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _attentionController.value = 1;
    } else if (_attentionController.isDismissed) {
      _attentionController.forward();
    }
  }

  @override
  void dispose() {
    _attentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _attentionController,
      builder: (context, _) {
        // Fifteen gentle pulses over thirty seconds, then a steady banner.
        final pulse = _attentionController.isCompleted
            ? 0.0
            : (1 - math.cos(_attentionController.value * math.pi * 30)) / 2;
        return AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.985 : 1.0,
          child: Container(
            key: const ValueKey('home-quote-promo'),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A192F).withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFFE5A93C)
                      .withValues(alpha: 0.08 + pulse * 0.24),
                  blurRadius: 10 + pulse * 10,
                  spreadRadius: pulse,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  key: const ValueKey('home-quote-promo-surface'),
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
                      color: const Color(0xFFE5A93C)
                          .withValues(alpha: 0.38 + pulse * 0.57),
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
                                  const Color(0xFFE5A93C)
                                      .withValues(alpha: 0.20),
                                  const Color(0xFFE5A93C)
                                      .withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onHighlightChanged: (val) =>
                              setState(() => _pressed = val),
                          onTap: () => context.go('/quote'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5A93C)
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE5A93C)
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFFE5A93C),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Étude & dimensionnement',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          height: 1.25,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            'Calculer mon devis',
                                            style: TextStyle(
                                              color: Color(0xFFE5A93C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            'Offert · 2 min',
                                            style: TextStyle(
                                              color: Color(0xFFCBD5E1),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE5A93C),
                                        Color(0xFFF59E0B),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Color(0xFF0A192F),
                                    size: 18,
                                  ),
                                ),
                              ],
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
      },
    );
  }
}

class _SolarUniverse {
  const _SolarUniverse({
    required this.displayName,
    required this.icon,
    required this.gradient,
    required this.iconColor,
    required this.categoryNames,
    required this.query,
  });

  final String displayName;
  final IconData icon;
  final List<Color> gradient;
  final Color iconColor;
  final List<String> categoryNames;
  final String query;

  Category? categoryFrom(List<Category> categories) {
    // Prefer a main category; a battery subtype must not hide other batteries.
    for (final name in categoryNames) {
      for (final category in categories) {
        if (_normalizeCategoryName(category.name) == name) {
          return category;
        }
      }
    }
    return null;
  }
}

String _normalizeCategoryName(String name) {
  var normalized = name.toLowerCase();
  for (final entry in const {
    'à': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ù': 'u',
    'û': 'u',
    'ç': 'c',
  }.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

const _solarUniverses = [
  _SolarUniverse(
    displayName: 'Panneaux Solaires',
    icon: Icons.solar_power_outlined,
    gradient: [Color(0xFFFEF3C7), Color(0xFFFCD34D)],
    iconColor: Color(0xFFB45309),
    categoryNames: [
      'panneaux solaires',
      'panneau solaire',
      'panneaux',
      'panneau'
    ],
    query: 'panneau',
  ),
  _SolarUniverse(
    displayName: 'Onduleurs & Hybrides',
    icon: Icons.electric_bolt_outlined,
    gradient: [Color(0xFFE0E7FF), Color(0xFFC7D2FE)],
    iconColor: Color(0xFF3730A3),
    categoryNames: [
      'onduleurs',
      'onduleur',
      'onduleurs hybrides',
      'onduleurs et hybrides'
    ],
    query: 'onduleur',
  ),
  _SolarUniverse(
    displayName: 'Batteries & Stockage',
    icon: Icons.battery_charging_full_outlined,
    gradient: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
    iconColor: Color(0xFF065F46),
    categoryNames: [
      'batteries',
      'batterie',
      'batteries stockage',
      'batteries et stockage'
    ],
    query: 'batterie',
  ),
  _SolarUniverse(
    displayName: 'Pompage & Variateurs',
    icon: Icons.water_drop_outlined,
    gradient: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
    iconColor: Color(0xFF0284C7),
    categoryNames: [
      'variateurs et pompes',
      'pompage solaire',
      'pompage',
      'pompage variateurs'
    ],
    query: 'pompage',
  ),
  _SolarUniverse(
    displayName: 'Coffrets & Câblage',
    icon: Icons.shield_outlined,
    gradient: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
    iconColor: Color(0xFF334155),
    categoryNames: [
      'coffrets cablage',
      'coffrets et cablage',
      'coffrets de protection',
      'gadgets protections outillages',
      'monitoring protections outillages',
    ],
    query: 'coffret',
  ),
  _SolarUniverse(
    displayName: 'Éclairage Solaire',
    icon: Icons.wb_incandescent_outlined,
    gradient: [Color(0xFFFEF9C3), Color(0xFFFEF08A)],
    iconColor: Color(0xFFA16207),
    categoryNames: [
      'eclairages',
      'eclairage solaire',
      'eclairages solaires',
      'eclairage'
    ],
    query: 'eclairage',
  ),
];

class _CategoryGridConfig {
  const _CategoryGridConfig({
    required this.crossAxisCount,
    required this.mainAxisExtent,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
  });

  final int crossAxisCount;
  final double mainAxisExtent;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  static _CategoryGridConfig of(double width, double textScale) {
    return _CategoryGridConfig(
      crossAxisCount: 3,
      mainAxisExtent:
          (width >= 560 ? 134 : 118) + (textScale - 1).clamp(0.0, 2.0) * 64,
      crossAxisSpacing: width >= 560 ? 14 : 10,
      mainAxisSpacing: width >= 560 ? 14 : 10,
    );
  }
}

class _SolarUniverseGrid extends StatelessWidget {
  const _SolarUniverseGrid({
    required this.categories,
  });

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final config = _CategoryGridConfig.of(
          constraints.maxWidth,
          MediaQuery.textScalerOf(context).scale(12) / 12,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _solarUniverses.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: config.crossAxisCount,
            mainAxisSpacing: config.mainAxisSpacing,
            crossAxisSpacing: config.crossAxisSpacing,
            mainAxisExtent: config.mainAxisExtent,
          ),
          itemBuilder: (context, index) {
            final universe = _solarUniverses[index];
            final category = universe.categoryFrom(categories);
            return _CategoryGlassCard(
              universe: universe,
              onTap: () => context.push(Uri(
                path: '/catalog',
                queryParameters: category != null
                    ? {'category': '${category.id}'}
                    : {'q': universe.query},
              ).toString()),
            );
          },
        );
      },
    );
  }
}

class _CategoryGlassCard extends StatefulWidget {
  const _CategoryGlassCard({
    required this.universe,
    required this.onTap,
  });

  final _SolarUniverse universe;
  final VoidCallback onTap;

  @override
  State<_CategoryGlassCard> createState() => _CategoryGlassCardState();
}

class _CategoryGlassCardState extends State<_CategoryGlassCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final meta = widget.universe;
    final active = _hovered || _pressed;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.96 : (active ? 1.025 : 1.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: active
                    ? meta.iconColor.withValues(alpha: 0.16)
                    : const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: active ? 16 : 10,
                offset: Offset(0, active ? 6 : 4),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: 0.96)
                          : Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: active
                            ? meta.iconColor.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.95),
                        width: active ? 1.4 : 1.1,
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
                        const SizedBox(height: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              meta.displayName,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.18,
                                letterSpacing: -0.2,
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
      ),
    );
  }
}

class _SolarCategoriesGridSkeleton extends StatelessWidget {
  const _SolarCategoriesGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final config = _CategoryGridConfig.of(
          constraints.maxWidth,
          MediaQuery.textScalerOf(context).scale(12) / 12,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _solarUniverses.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: config.crossAxisCount,
            mainAxisSpacing: config.mainAxisSpacing,
            crossAxisSpacing: config.crossAxisSpacing,
            mainAxisExtent: config.mainAxisExtent,
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
  static final Uri _whatsappUrl = AppConfig.supportWhatsAppUri(
    message:
        'Bonjour Heliantha, je souhaite avoir des informations sur vos solutions énergétiques.',
  );

  bool _hovered = false;

  Future<void> _openWhatsApp() async {
    final opened = await launchUrl(
      _whatsappUrl,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      AppFeedback.info(
        context,
        'Nous n’avons pas pu ouvrir WhatsApp directement. Vous pouvez joindre notre service client au ${AppConfig.supportWhatsAppDisplay}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        key: const ValueKey('home-support-panel'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? const Color(0xFF25D366).withValues(alpha: 0.45)
                : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(
                alpha: _hovered ? 0.07 : 0.035,
              ),
              blurRadius: _hovered ? 14 : 8,
              offset: const Offset(0, 2),
            ),
            if (_hovered)
              BoxShadow(
                color: const Color(0xFF25D366).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openWhatsApp,
              splashColor: const Color(0xFF25D366).withValues(alpha: 0.08),
              highlightColor: const Color(0xFF25D366).withValues(alpha: 0.03),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 540 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 16;
                    final button = _WhatsAppCtaButton(
                      hovered: _hovered,
                    );

                    if (isWide) {
                      return Row(
                        children: [
                          const Expanded(child: _SupportPanelText()),
                          const SizedBox(width: 16),
                          SizedBox(width: 210, child: button),
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SupportPanelText(),
                        const SizedBox(height: 9),
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
    );
  }
}

class _SupportIcon extends StatelessWidget {
  const _SupportIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF25D366), Color(0xFF16A34A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.chat_bubble_rounded,
          color: Colors.white,
          size: 17,
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF86EFAC).withValues(alpha: 0.8),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'En direct',
            style: TextStyle(
              color: Color(0xFF047857),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportPanelText extends StatelessWidget {
  const _SupportPanelText();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _SupportIcon(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Besoin de conseils ?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF0F172A),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _LiveBadge(),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Nos experts solaires vous guident dans votre projet.',
                maxLines: 2,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhatsAppCtaButton extends StatelessWidget {
  const _WhatsAppCtaButton({
    required this.hovered,
  });

  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 33,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hovered
              ? const [Color(0xFF2EE673), Color(0xFF1EA755)]
              : const [Color(0xFF25D366), Color(0xFF16A34A)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: hovered ? 0.30 : 0.16),
            blurRadius: hovered ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_rounded,
            size: 13.5,
            color: Colors.white,
          ),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Échanger sur WhatsApp',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
          SizedBox(width: 5),
          Icon(
            Icons.arrow_forward_rounded,
            size: 12.5,
            color: Colors.white,
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
