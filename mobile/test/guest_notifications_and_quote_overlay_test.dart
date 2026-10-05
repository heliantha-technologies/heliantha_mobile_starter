import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/quote/presentation/widgets/quote_generating_overlay.dart';

Widget _harness({
  bool visible = true,
  bool reducedMotion = false,
  double textScale = 1,
  VoidCallback? onTap,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: TextButton(
                key: const ValueKey('underlying-action'),
                onPressed: onTap ?? () {},
                child: const Text('Continuer'),
              ),
            ),
            Positioned.fill(
              child: QuoteGeneratingOverlay(isVisible: visible),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('L’overlay masqué laisse le contenu accessible', (tester) async {
    var tapped = false;
    await tester
        .pumpWidget(_harness(visible: false, onTap: () => tapped = true));
    await tester.tap(find.byKey(const ValueKey('underlying-action')));
    await tester.pump();

    expect(tapped, isTrue);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(PopScope), findsNothing);
  });

  testWidgets('L’overlay visible bloque les clics et le retour',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_harness(onTap: () => tapped = true));
    await tester.tap(
      find.byKey(const ValueKey('underlying-action')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(tapped, isFalse);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    final overlayBarrier = find.descendant(
      of: find.byType(QuoteGeneratingOverlay),
      matching: find.byType(ModalBarrier),
    );
    expect(tester.widget<ModalBarrier>(overlayBarrier).dismissible, isFalse);
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Les étapes évoluent et la progression reste inférieure à 100 %',
      (tester) async {
    await tester.pumpWidget(_harness());
    expect(find.text('Analyse de votre profil énergétique'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Évaluation de votre gisement solaire'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Dimensionnement de votre installation'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Préparation de votre devis solaire'), findsOneWidget);
    await tester.pumpAndSettle();

    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, closeTo(0.92, 0.0001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Le mode sans animations reste stable sur petit écran avec texte agrandi',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(reducedMotion: true, textScale: 2));
    await tester.pumpAndSettle();

    expect(find.text('Préparation de votre devis solaire'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Masquer ou supprimer l’overlay libère l’animation et les clics',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_harness(onTap: () => taps++));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(_harness(visible: false, onTap: () => taps++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('underlying-action')));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(_harness());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
