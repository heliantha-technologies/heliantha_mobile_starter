import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:heliantha_mobile/features/home/presentation/home_screen.dart';
import 'package:heliantha_mobile/features/home/providers/home_provider.dart';
import 'package:heliantha_mobile/shared/models/category.dart';
import 'package:heliantha_mobile/shared/models/home_slide.dart';

Future<void> _mountNavigationHome(WidgetTester tester, GoRouter router,
    {bool settleAttention = true}) async {
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) async => null),
      homeSlidesProvider.overrideWith((ref) async => <HomeSlide>[]),
      categoriesProvider.overrideWith((ref) async => const <Category>[
            Category(id: 26, name: 'Batteries Lithium'),
            Category(id: 109, name: 'Batterie'),
          ]),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 4));
  if (settleAttention) {
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Color _quoteBannerBorder(WidgetTester tester) {
  final surface = tester.widget<Container>(
      find.byKey(const ValueKey('home-quote-promo-surface')));
  final decoration = surface.decoration! as BoxDecoration;
  return (decoration.border! as Border).top.color;
}

GoRouter _testRouter() {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/quote',
      builder: (_, __) => const Scaffold(body: Text('Choisir mon projet')),
    ),
    GoRoute(
      path: '/quote/form/:projectType',
      builder: (_, state) => Scaffold(
        body: Text('Formulaire ${state.pathParameters['projectType']}'),
      ),
    ),
    GoRoute(
      path: '/catalog',
      builder: (_, __) => const Scaffold(body: Text('Catalogue complet')),
    ),
  ]);
  addTearDown(router.dispose);
  return router;
}

Future<void> _tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'HomeScreen renders CTA Devis Marine & Or et les 6 Univers Solaires en 3 colonnes',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => null),
          homeSlidesProvider.overrideWith((ref) async => <HomeSlide>[]),
          categoriesProvider.overrideWith((ref) async => <Category>[
                const Category(id: 3, name: 'Panneaux solaires'),
                const Category(id: 4, name: 'Onduleurs hybrides'),
                const Category(id: 5, name: 'Pompage solaire'),
                const Category(id: 6, name: 'Batteries lithium'),
                const Category(id: 7, name: 'Groupes électrogènes'),
                const Category(id: 8, name: 'Coffrets de protection'),
              ]),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    // 1. CTA Devis Premium Marine & Or
    expect(find.text('Étude & dimensionnement'), findsOneWidget);
    expect(find.text('Offert · 2 min'), findsOneWidget);
    expect(find.text('Calculer mon devis'), findsOneWidget);
    expect(find.byType(SearchBar), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Besoin de conseils ?'), findsOneWidget);
    expect(find.text('Échanger sur WhatsApp'), findsOneWidget);

    // 2. En-tête Nos Univers Solaires
    expect(find.text('Nos Univers Solaires'), findsOneWidget);
    expect(find.text('Explorez nos équipements par domaine.'), findsOneWidget);

    // 3. Les 6 Univers Solaires
    expect(find.text('Panneaux Solaires'), findsOneWidget);
    expect(find.text('Onduleurs & Hybrides'), findsOneWidget);
    expect(find.text('Batteries & Stockage'), findsOneWidget);
    expect(find.text('Pompage & Variateurs'), findsOneWidget);
    expect(find.text('Coffrets & Câblage'), findsOneWidget);
    expect(find.text('Éclairage Solaire'), findsOneWidget);
    expect(find.textContaining('Groupes'), findsNothing);

    // 4. Absence définitive de l'ancienne section "Nos solutions solaires"
    expect(find.text('Nos solutions solaires'), findsNothing);
  });

  testWidgets(
      'HomeScreen groups 18 backend categories into exactly six main universes',
      (tester) async {
    final all18Categories = <Category>[
      const Category(id: 3, name: 'Panneau solaire'),
      const Category(id: 6, name: 'Onduleur'),
      const Category(id: 9, name: 'Batterie'),
      const Category(id: 11, name: 'Variateurs et Pompes'),
      const Category(id: 15, name: 'Gadgets, Protections & Outillages'),
      const Category(id: 16, name: 'Eclairages'),
      const Category(id: 17, name: 'Groupes électrogènes'),
      const Category(id: 18, name: 'Monitoring, Protections & Outillages'),
      const Category(id: 19, name: 'Eclairage'),
      const Category(id: 20, name: 'Groupes électrogènes Maroc'),
      const Category(id: 32, name: 'Goodies & Personnalisation'),
      const Category(id: 23, name: 'hybride/off-grid'),
      const Category(id: 24, name: 'hybride/on-grid'),
      const Category(id: 25, name: 'on-grid'),
      const Category(id: 26, name: 'Lithium'),
      const Category(id: 27, name: 'Gel'),
      const Category(id: 28, name: 'Variateurs'),
      const Category(id: 29, name: 'pompes'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => null),
          homeSlidesProvider.overrideWith((ref) async => <HomeSlide>[]),
          categoriesProvider.overrideWith((ref) async => all18Categories),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    for (final label in [
      'Panneaux Solaires',
      'Onduleurs & Hybrides',
      'Batteries & Stockage',
      'Pompage & Variateurs',
      'Coffrets & Câblage',
      'Éclairage Solaire',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.childrenDelegate.estimatedChildCount, 6);
    expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        3);
    expect(find.textContaining('Lithium'), findsNothing);
    expect(find.textContaining('Gel'), findsNothing);
    expect(find.textContaining('Off-Grid'), findsNothing);
    expect(find.textContaining('On-Grid'), findsNothing);
    expect(find.textContaining('Goodies'), findsNothing);
    expect(find.textContaining('Groupes'), findsNothing);
  });

  testWidgets('Quote banner pulses then becomes steady after thirty seconds',
      (tester) async {
    final router = _testRouter();
    await _mountNavigationHome(tester, router, settleAttention: false);
    final initialBorder = _quoteBannerBorder(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_quoteBannerBorder(tester), isNot(initialBorder));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    final steadyBorder = _quoteBannerBorder(tester);
    expect(steadyBorder, initialBorder);
    await tester.pump(const Duration(seconds: 2));
    expect(_quoteBannerBorder(tester), steadyBorder);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quote banner stays steady when animations are disabled',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final router = _testRouter();
    await _mountNavigationHome(tester, router, settleAttention: false);
    final steadyBorder = _quoteBannerBorder(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_quoteBannerBorder(tester), steadyBorder);
    await tester.pump(const Duration(seconds: 31));
    expect(_quoteBannerBorder(tester), steadyBorder);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final shortcut in [
    (label: '🌾 Pompage Agricole', project: 'pompage'),
    (label: '🔋 Solaire avec batteries', project: 'hybride'),
    (label: '📉 Réduire ma facture', project: 'autoconsommation'),
  ]) {
    testWidgets('${shortcut.label} opens its available quote form',
        (tester) async {
      final router = _testRouter();
      await _mountNavigationHome(tester, router);
      final firstShortcut = find.text('🌾 Pompage Agricole');
      expect(find.byType(SearchBar), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(tester.getBottomLeft(firstShortcut).dy,
          lessThan(tester.getTopLeft(find.byType(HomeSlider)).dy));
      await _tapLabel(tester, shortcut.label);
      expect(find.text('Formulaire ${shortcut.project}'), findsOneWidget);
      expect(
          GoRouterState.of(
                  tester.element(find.text('Formulaire ${shortcut.project}')))
              .uri
              .path,
          '/quote/form/${shortcut.project}');
    });
  }

  testWidgets('Pulsing quote banner fills the home width and remains clickable',
      (tester) async {
    final router = _testRouter();
    await _mountNavigationHome(tester, router, settleAttention: false);
    tester.view.physicalSize = const Size(320, 896);
    await tester.pump();
    final banner = find.byKey(const ValueKey('home-quote-promo'));
    expect(tester.getSize(banner).width,
        tester.getSize(find.byType(GridView)).width);
    expect(tester.getTopLeft(banner).dx,
        tester.getTopLeft(find.byType(GridView)).dx);
    expect(tester.takeException(), isNull);
    final label = find.text('Étude & dimensionnement');
    await tester.ensureVisible(label);
    await tester.pump();
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.text('Choisir mon projet'), findsOneWidget);
  });

  testWidgets('Voir tout opens the catalogue categories', (tester) async {
    final router = _testRouter();
    await _mountNavigationHome(tester, router);
    await _tapLabel(tester, 'Voir tout');
    expect(find.text('Catalogue complet'), findsOneWidget);
    expect(GoRouterState.of(tester.element(find.text('Catalogue complet'))).uri,
        Uri.parse('/catalog?categories=1'));
  });

  testWidgets(
      'Battery universe uses the main category instead of a lithium subtype',
      (tester) async {
    final router = _testRouter();
    await _mountNavigationHome(tester, router);
    await _tapLabel(tester, 'Batteries & Stockage');
    expect(
        GoRouterState.of(tester.element(find.text('Catalogue complet')))
            .uri
            .queryParameters,
        {'category': '109'});
  });

  testWidgets('Missing main category opens a search with enlarged text',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = _testRouter();
    await _mountNavigationHome(tester, router);
    await _tapLabel(tester, 'Éclairage Solaire');
    expect(
        GoRouterState.of(tester.element(find.text('Catalogue complet')))
            .uri
            .queryParameters,
        {'q': 'eclairage'});
    expect(tester.takeException(), isNull);
  });
}
