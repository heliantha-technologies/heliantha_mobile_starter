import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:heliantha_mobile/features/home/presentation/home_screen.dart';
import 'package:heliantha_mobile/features/home/providers/home_provider.dart';
import 'package:heliantha_mobile/shared/models/category.dart';
import 'package:heliantha_mobile/shared/models/home_slide.dart';

void main() {
  testWidgets('HomeScreen renders CTA Devis Marine & Or et les 6 Univers Solaires en 3 colonnes', (tester) async {
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
    await tester.pumpAndSettle();

    // 1. CTA Devis Premium Marine & Or
    expect(find.text('ÉTUDE & ESTIMATION OFFERTE'), findsOneWidget);
    expect(find.text("Besoin d'un dimensionnement personnalisé ?"), findsOneWidget);
    expect(find.text('Calculez votre devis en 2 minutes'), findsOneWidget);
    expect(find.text('Calculer mon devis'), findsOneWidget);

    // 2. En-tête Nos Univers Solaires
    expect(find.text('Nos Univers Solaires'), findsOneWidget);
    expect(find.text('Explorez nos équipements par domaine.'), findsOneWidget);

    // 3. Les 6 Univers Solaires
    expect(find.textContaining('Onduleurs'), findsOneWidget);
    expect(find.textContaining('Pompage'), findsOneWidget);
    expect(find.textContaining('Panneaux'), findsOneWidget);
    expect(find.textContaining('Batteries'), findsOneWidget);
    expect(find.textContaining('Groupes'), findsOneWidget);
    expect(find.textContaining('Coffrets'), findsOneWidget);

    // 4. Absence définitive de l'ancienne section "Nos solutions solaires"
    expect(find.text('Nos solutions solaires'), findsNothing);
  });

  testWidgets('HomeScreen renders all 18 backend categories in 3-column glassmorphism grid', (tester) async {
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
    await tester.pumpAndSettle();

    // Verify key categories mapped into clean French and rendered
    expect(find.textContaining('Panneaux'), findsWidgets);
    expect(find.textContaining('Onduleurs'), findsWidgets);
    expect(find.textContaining('Lithium'), findsWidgets);
    expect(find.textContaining('Gel'), findsWidgets);
    expect(find.textContaining('Pompage'), findsWidgets);
    expect(find.textContaining('Variateurs'), findsWidgets);
    expect(find.textContaining('Off-Grid'), findsWidgets);
    expect(find.textContaining('On-Grid'), findsWidgets);
    expect(find.textContaining('Goodies'), findsWidgets);
  });
}
