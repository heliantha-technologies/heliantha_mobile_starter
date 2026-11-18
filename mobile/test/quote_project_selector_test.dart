import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_floating_orb.dart';
import 'package:heliantha_mobile/features/quote/presentation/quote_project_selector_screen.dart';
import 'package:heliantha_mobile/features/quote/presentation/widgets/solar_system_3d_background.dart';
import 'package:heliantha_mobile/shared/theme/app_vector_icons.dart';

void main() {
  testWidgets(
      'QuoteProjectSelectorScreen renders 6 equal-size cards (2 per row) without scroll on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuoteProjectSelectorScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Quel est votre projet ?'), findsOneWidget);
    expect(find.text('Choisissez votre solution solaire.'), findsOneWidget);

    for (final title in [
      'Pompage solaire',
      'Site sans réseau',
      'Réduire ma facture',
      'Solaire avec batteries',
      'Chauffage solaire',
      'Recharge électrique',
    ]) {
      expect(find.text(title), findsOneWidget);
    }

    expect(find.text('Estimer mon pompage'), findsOneWidget);
    expect(find.text('Estimer mes économies'), findsOneWidget);
    expect(find.text('Estimer mon installation'), findsOneWidget);
    expect(find.text('Bientôt disponible'), findsNWidgets(3));

    // Single-screen 2-column GridView without scrolling on standard mobile.
    expect(find.byType(SingleChildScrollView), findsNothing);
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.physics, isA<NeverScrollableScrollPhysics>());
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );

    // All 6 cards share the exact same dimensions (2 per row x 3 rows).
    final cardButtons = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(InkWell),
    );
    expect(cardButtons, findsNWidgets(6));
    final firstSize = tester.getSize(cardButtons.at(0));
    for (var i = 1; i < 6; i++) {
      final size = tester.getSize(cardButtons.at(i));
      expect((size.width - firstSize.width).abs(), lessThan(0.5));
      expect((size.height - firstSize.height).abs(), lessThan(0.5));
    }

    // Row alignment: card 0 and card 1 share the same row; card 2 is on row 2.
    expect(
      (tester.getTopLeft(cardButtons.at(0)).dy -
              tester.getTopLeft(cardButtons.at(1)).dy)
          .abs(),
      lessThan(0.5),
    );
    expect(
      tester.getTopLeft(cardButtons.at(2)).dy,
      greaterThan(tester.getBottomLeft(cardButtons.at(0)).dy),
    );

    // Zero raw Unicode emojis; all 6 cards + hero sparkle + 3 active arrows use native SVGs.
    expect(find.byType(AppSvgIcon), findsAtLeastNWidgets(10));
    expect(find.byType(SvgPicture), findsAtLeastNWidgets(10));
    for (final emoji in ['💧', '🏠', '☀️', '🔋', '♨️', '🚗', '⏳']) {
      expect(find.textContaining(emoji), findsNothing);
    }

    // Card 6 stays clear of the floating AI orb on 390x844 mobile.
    final orbCircle = tester.getRect(
      find.descendant(
        of: find.byType(AiFloatingOrb),
        matching: find.byType(GestureDetector),
      ).first,
    );
    final sixthCardRect = tester.getRect(cardButtons.at(5));
    expect(sixthCardRect.bottom, lessThan(orbCircle.top));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'QuoteProjectSelectorScreen renders 3x2 equal cards on desktop (1280x800) and stays safe at 320x640 1.5x text scale',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuoteProjectSelectorScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SingleChildScrollView), findsNothing);
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      3,
    );

    final cardButtons = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(InkWell),
    );
    expect(cardButtons, findsNWidgets(6));
    final desktopFirstSize = tester.getSize(cardButtons.at(0));
    for (var i = 1; i < 6; i++) {
      final size = tester.getSize(cardButtons.at(i));
      expect((size.width - desktopFirstSize.width).abs(), lessThan(0.5));
      expect((size.height - desktopFirstSize.height).abs(), lessThan(0.5));
    }
    expect(tester.takeException(), isNull);

    // Compact mobile with 1.5x accessibility text scale enables scroll cleanly without overflow.
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: QuoteProjectSelectorScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pompage solaire'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Resizing back to desktop re-anchors the AI orb near the right edge.
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuoteProjectSelectorScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final desktopOrbRect = tester.getRect(
      find.descendant(
        of: find.byType(AiFloatingOrb),
        matching: find.byType(GestureDetector),
      ).first,
    );
    expect(desktopOrbRect.right, greaterThan(1200));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'QuoteProjectSelectorScreen opens active quote form and shows feedback for upcoming modules',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/quote',
      routes: [
        GoRoute(
          path: '/quote',
          builder: (_, __) => const QuoteProjectSelectorScreen(),
        ),
        GoRoute(
          path: '/quote/form/:projectType',
          builder: (_, state) => Scaffold(
            body: Text('Formulaire:${state.pathParameters['projectType']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Site sans réseau'));
    await tester.pump();
    expect(
      find.text('Ce module sera disponible très prochainement.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Estimer mon pompage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Formulaire:pompage'), findsOneWidget);
  });

  testWidgets(
      'Hovering an active executive card highlights its matching 3D orbit focusColor',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuoteProjectSelectorScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<SolarSystem3DBackground>(find.byType(SolarSystem3DBackground))
          .focusColor,
      isNull,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.text('Pompage solaire')));
    await tester.pump();
    expect(
      tester
          .widget<SolarSystem3DBackground>(find.byType(SolarSystem3DBackground))
          .focusColor,
      const Color(0xFF0A6097),
    );

    await gesture.moveTo(tester.getCenter(find.text('Réduire ma facture')));
    await tester.pump();
    expect(
      tester
          .widget<SolarSystem3DBackground>(find.byType(SolarSystem3DBackground))
          .focusColor,
      const Color(0xFFB45309),
    );

    await gesture.moveTo(const Offset(2, 2));
    await tester.pump();
    expect(
      tester
          .widget<SolarSystem3DBackground>(find.byType(SolarSystem3DBackground))
          .focusColor,
      isNull,
    );
  });

  testWidgets(
      'SolarSystem3DBackground renders without BackdropFilter and pauses on inactive route or disableAnimations',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuoteProjectSelectorScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SolarSystem3DBackground), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(QuoteProjectSelectorScreen),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );

    // Standalone SolarSystem3DBackground respects disableAnimations and stops scheduling frames.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SolarSystem3DBackground(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    // Restores animations and pauses automatically when GoRouter leaves /quote.
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    final shellRouter = GoRouter(
      initialLocation: '/quote',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const Text('Accueil'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/quote',
                  builder: (_, __) => const SolarSystem3DBackground(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(shellRouter.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: shellRouter));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);

    shellRouter.go('/');
    await tester.pump();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);

    shellRouter.go('/quote');
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
