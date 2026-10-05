import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/quote/presentation/quote_form_screen.dart';

void main() {
  testWidgets('QuoteFormScreen renders WhatsApp phone input with Morocco +212 badge by default',
      (tester) async {
    tester.view.physicalSize = const Size(414 * 2, 896 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuoteFormScreen(projectType: 'pompage'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Step 0: Pompe existante
    expect(find.text('Avez-vous déjà une pompe ?'), findsOneWidget);
    await tester.tap(find.text('Oui, une pompe existe déjà'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Next step -> puissance
    await tester.tap(find.text('Suivant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Select 5.5 CV
    expect(find.text('5.5 CV'), findsOneWidget);
    await tester.tap(find.text('5.5 CV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Next step -> Vos coordonnées
    await tester.tap(find.text('Suivant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Step 3: Vos coordonnées
    expect(find.text('Vos coordonnées'), findsOneWidget);
    expect(find.text('Nom complet'), findsOneWidget);
    expect(find.text('Numéro WhatsApp'), findsOneWidget);
    expect(find.text('Ville'), findsOneWidget);

    // Verify default Morocco badge: Flag 🇲🇦 and +212
    expect(find.text('🇲🇦'), findsOneWidget);
    expect(find.text('+212'), findsOneWidget);

    // Tap country picker badge to open bottom sheet
    await tester.tap(find.text('+212'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify modal bottom sheet opened
    expect(find.text('Indicatif WhatsApp'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
    expect(find.text('+33'), findsOneWidget);

    // Select France
    await tester.tap(find.text('France'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now country badge is France 🇫🇷 and +33
    expect(find.text('🇫🇷'), findsOneWidget);
    expect(find.text('+33'), findsOneWidget);
  });
}
