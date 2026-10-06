import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/addresses/presentation/addresses_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/checkout/presentation/checkout_start_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/legal/presentation/privacy_policy_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/quote/presentation/quote_form_screen.dart';
import '../../features/quote/presentation/quote_project_selector_screen.dart';
import '../../shared/models/order.dart';
import '../../features/product/presentation/product_screen.dart';
import '../../shared/models/product.dart';
import '../../shared/theme/app_colors.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final _homeNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'homeBranch',
);
final _catalogNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'catalogBranch',
);
final _quoteNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'quoteBranch',
);
final _favoritesNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'favoritesBranch',
);
final _accountNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'accountBranch',
);

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _catalogNavigatorKey,
          routes: [
            GoRoute(
              path: '/catalog',
              builder: (_, state) => CatalogScreen(
                initialCategory: int.tryParse(
                  state.uri.queryParameters['category'] ?? '',
                ),
                initialQuery: state.uri.queryParameters['q'],
                openCategories: state.uri.queryParameters['categories'] == '1',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _quoteNavigatorKey,
          routes: [
            GoRoute(
              path: '/quote',
              builder: (_, __) => const QuoteProjectSelectorScreen(),
              routes: [
                GoRoute(
                  path: 'form/:projectType',
                  builder: (_, state) => QuoteFormScreen(
                    projectType: state.pathParameters['projectType']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _favoritesNavigatorKey,
          routes: [
            GoRoute(
              path: '/favorites',
              builder: (_, __) => const FavoritesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _accountNavigatorKey,
          routes: [
            GoRoute(
              path: '/account',
              builder: (_, __) => const AccountScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/cart',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const CartScreen(),
    ),
    GoRoute(
      path: '/products/:id',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (_, state) => '/product/${state.pathParameters['id']}',
    ),
    GoRoute(
      path: '/product/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) => ProductScreen(
        productId: int.parse(state.pathParameters['id']!),
        initialProduct: state.extra is Product ? state.extra as Product : null,
      ),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) => LoginScreen(
        redirectLocation: state.uri.queryParameters['redirect'],
      ),
    ),
    GoRoute(
      path: '/register',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) => RegisterScreen(
        redirectLocation: state.uri.queryParameters['redirect'],
      ),
    ),
    GoRoute(
      path: '/checkout/start',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const CheckoutStartScreen(),
    ),
    GoRoute(
      path: '/orders',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const OrdersScreen(),
    ),
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/orders/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) => OrderDetailScreen(
        orderId: int.parse(state.pathParameters['id']!),
        initialOrder:
            state.extra is OrderModel ? state.extra as OrderModel : null,
      ),
    ),
    GoRoute(
      path: '/addresses',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) => AddressesScreen(
        from: state.uri.queryParameters['from'],
      ),
    ),
    GoRoute(
      path: '/checkout',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/privacy',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, __) => const PrivacyPolicyScreen(),
    ),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        left: false,
        right: false,
        bottom: false,
        child: shell,
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 0,
        child: SafeArea(
          left: false,
          right: false,
          top: false,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: SizedBox(
              height: 64,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final navigationBar = NavigationBar(
                    selectedIndex: shell.currentIndex,
                    onDestinationSelected: (index) {
                      shell.goBranch(
                        index,
                        initialLocation: index == shell.currentIndex,
                      );
                    },
                    destinations: [
                      const NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Accueil',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.manage_search_rounded),
                        selectedIcon: Icon(Icons.search_rounded),
                        label: 'Catalogue',
                      ),
                      const NavigationDestination(
                        icon: _QuoteNavIcon(selected: false),
                        selectedIcon: _QuoteNavIcon(selected: true),
                        label: 'Devis',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.favorite_border_rounded),
                        selectedIcon: Icon(Icons.favorite_rounded),
                        label: 'Favoris',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: 'Compte',
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 800) {
                    return navigationBar;
                  }

                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: SizedBox(
                        width: double.infinity,
                        child: navigationBar,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteNavIcon extends StatefulWidget {
  const _QuoteNavIcon({required this.selected});

  final bool selected;

  @override
  State<_QuoteNavIcon> createState() => _QuoteNavIconState();
}

class _QuoteNavIconState extends State<_QuoteNavIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7500),
    );
    if (widget.selected) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (widget.selected && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _QuoteNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        if (!MediaQuery.disableAnimationsOf(context)) {
          _controller.repeat();
        }
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return Semantics(
      label: selected ? 'Devis actif' : 'Devis',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFF59E0B)
                : const Color(0xFFCBD5E1).withValues(alpha: 0.35),
            width: selected ? 1.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                  : const Color(0xFF0F172A).withValues(alpha: 0.16),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = selected ? _controller.value : 0.0;
            return CustomPaint(
              size: const Size(26, 26),
              painter: _NavOrbitalSunPainter(
                spin: t,
                pulse: selected ? (math.sin(t * 4 * math.pi) + 1) / 2 : 0.0,
                selected: selected,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavOrbitalSunPainter extends CustomPainter {
  const _NavOrbitalSunPainter({
    required this.spin,
    required this.pulse,
    required this.selected,
  });

  final double spin;
  final double pulse;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final coreRadius = radius * (selected ? (0.34 + 0.04 * pulse) : 0.34);

    // 1. Halo doux doré si actif
    if (selected) {
      canvas.drawCircle(
        center,
        radius * (0.80 + 0.08 * pulse),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFDE68A).withValues(alpha: 0.50),
              const Color(0xFFFDE68A).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // 2. Anneau d'orbite pointillé bleu cyan
    final orbitRadius = radius * 0.88;
    final orbitPaint = Paint()
      ..color = selected
          ? const Color(0xFF38BDF8).withValues(alpha: 0.55)
          : const Color(0xFF94A3B8).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const dashCount = 18;
    for (var i = 0; i < dashCount; i += 2) {
      final a0 = (i / dashCount) * 2 * math.pi;
      final a1 = ((i + 1) / dashCount) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: orbitRadius),
        a0,
        a1 - a0,
        false,
        orbitPaint,
      );
    }

    // 3. Rayons solaires dorés (en rotation douce si actif, fixes si inactif)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin * 2 * math.pi);
    const rayCount = 8;
    for (var i = 0; i < rayCount; i++) {
      final isLong = i.isEven;
      final inner = coreRadius + 1.2;
      final outer = coreRadius + (isLong ? 3.4 : 2.4);
      final rayPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isLong ? 1.8 : 1.3
        ..color = selected
            ? (isLong ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24))
                .withValues(alpha: isLong ? 0.95 : 0.80)
            : Colors.white.withValues(alpha: isLong ? 0.85 : 0.65);
      final angle = (i / rayCount) * 2 * math.pi;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(dir * inner, dir * outer, rayPaint);
    }
    canvas.restore();

    // 4. Cœur du soleil dégradé chaud
    final coreRect = Rect.fromCircle(center: center, radius: coreRadius);
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = selected
            ? const RadialGradient(
                center: Alignment(-0.35, -0.35),
                colors: [Color(0xFFFFF7CC), Color(0xFFFCD34D), Color(0xFFF59E0B)],
                stops: [0.0, 0.45, 1.0],
              ).createShader(coreRect)
            : const RadialGradient(
                center: Alignment(-0.35, -0.35),
                colors: [Color(0xFFFFFFFF), Color(0xFFCBD5E1)],
                stops: [0.0, 1.0],
              ).createShader(coreRect),
    );

    // 5. Petit satellite d'énergie en orbite
    final satAngle = selected
        ? (-spin * 2 * math.pi * 2 - math.pi / 2)
        : -math.pi / 4;
    final satPos = center +
        Offset(math.cos(satAngle), math.sin(satAngle)) * orbitRadius;
    if (selected) {
      canvas.drawCircle(
        satPos,
        3.2,
        Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        satPos,
        2.0,
        Paint()..color = const Color(0xFF0EA5E9),
      );
      canvas.drawCircle(
        satPos,
        0.9,
        Paint()..color = Colors.white,
      );
    } else {
      canvas.drawCircle(
        satPos,
        1.8,
        Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.70),
      );
    }
  }

  @override
  bool shouldRepaint(_NavOrbitalSunPainter oldDelegate) =>
      oldDelegate.spin != spin ||
      oldDelegate.pulse != pulse ||
      oldDelegate.selected != selected;
}
