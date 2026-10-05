import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/quote/presentation/quote_project_selector_screen.dart';

void main() {
  testWidgets('QuoteProjectSelectorScreen renders 6 projects without scroll on mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(414, 550);
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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Quel est votre projet ?'), findsOneWidget);
    expect(find.text('Choisissez votre solution solaire.'), findsOneWidget);

    expect(find.text('Pompage solaire'), findsOneWidget);
    expect(find.text('Site sans réseau'), findsOneWidget);
    expect(find.text('Réduire ma facture'), findsOneWidget);
    expect(find.text('Solaire avec batteries'), findsOneWidget);
    expect(find.text('Chauffage solaire'), findsOneWidget);
    expect(find.text('Recharge électrique'), findsOneWidget);

    expect(find.text('Estimer mon pompage'), findsOneWidget);
    expect(find.text('Estimer mes économies'), findsOneWidget);
    expect(find.text('Estimer mon installation'), findsOneWidget);
    expect(find.text('Bientôt disponible'), findsNWidgets(3));

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.physics, isA<NeverScrollableScrollPhysics>());
  });
}
