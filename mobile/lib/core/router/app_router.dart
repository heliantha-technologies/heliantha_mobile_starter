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
        child: SizedBox.expand(child: shell),
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
            child: NavigationBar(
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
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteNavIcon extends StatelessWidget {
  const _QuoteNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.sun : AppColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.premiumLine : AppColors.navy,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: selected ? 0.16 : 0.10),
            blurRadius: selected ? 14 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        selected ? Icons.solar_power_rounded : Icons.calculate_outlined,
        color: selected ? AppColors.navy : Colors.white,
        size: 22,
      ),
    );
  }
}
