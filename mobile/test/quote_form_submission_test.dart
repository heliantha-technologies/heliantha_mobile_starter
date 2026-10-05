import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heliantha_mobile/features/quote/data/quote_repository.dart';
import 'package:heliantha_mobile/features/quote/presentation/quote_form_screen.dart';
import 'package:heliantha_mobile/features/quote/presentation/widgets/quote_generating_overlay.dart';
import 'package:heliantha_mobile/features/quote/providers/quote_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingQuoteRepository implements QuoteRepository {
  final result = Completer<QuoteCalculationResult>();
  QuoteRequestPayload? submitted;

  @override
  Future<QuoteCalculationResult> calculate(QuoteRequestPayload payload) {
    submitted = payload;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  // The assistant orb animates continuously while the form is visible.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final fails in [false, true]) {
    testWidgets(
        'quote blocks all navigation then releases it on '
        '${fails ? 'failure' : 'success'}', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _PendingQuoteRepository();
      final router = GoRouter(
        initialLocation: '/quote',
        routes: [
          ShellRoute(
            builder: (context, state, child) => Scaffold(
              body: child,
              bottomNavigationBar: TextButton(
                onPressed: () => context.go('/away'),
                child: const Text('Autre écran'),
              ),
            ),
            routes: [
              GoRoute(
                path: '/quote',
                builder: (_, __) =>
                    const Scaffold(body: Text('Projets solaires')),
              ),
              GoRoute(
                path: '/quote/form/pompage',
                builder: (_, __) =>
                    const QuoteFormScreen(projectType: 'pompage'),
              ),
              GoRoute(
                path: '/away',
                builder: (_, __) => const Scaffold(body: Text('Destination')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [quoteRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await _pumpUi(tester);
      unawaited(router.push<void>('/quote/form/pompage'));
      await _pumpUi(tester);
      await tester.tap(find.text('Oui, une pompe existe déjà'));
      await _pumpUi(tester);
      await tester.tap(find.text('Suivant'));
      await _pumpUi(tester);
      await tester.tap(find.text('5.5 CV'));
      await _pumpUi(tester);
      await tester.tap(find.text('Suivant'));
      await _pumpUi(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom complet'),
        'Sara Heliantha',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numéro WhatsApp'),
        '0661575128',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ville'),
        'Casablanca',
      );
      tester.testTextInput.hide();
      await _pumpUi(tester);
      await tester.tap(find.text('Calculer mon devis'));
      await tester.pump();
      expect(repository.submitted?.contact.phone, '+212661575128');
      expect(find.byType(QuoteGeneratingOverlay), findsOneWidget);
      await tester.tap(find.text('Autre écran'), warnIfMissed: false);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(QuoteFormScreen), findsOneWidget);
      expect(find.byType(QuoteGeneratingOverlay), findsOneWidget);

      if (fails) {
        repository.result
            .completeError(const QuoteApiException('HTTP 500 main.py'));
      } else {
        repository.result.complete(const QuoteCalculationResult({
          'quote_number': 'DEV-TEST',
          'total_ttc': 12345.67,
        }));
      }
      await _pumpUi(tester);
      expect(find.byType(QuoteGeneratingOverlay), findsNothing);
      expect(find.textContaining('HTTP 500'), findsNothing);
      expect(tester.takeException(), isNull);
      if (!fails) {
        final amount = tester.widget<Text>(find.textContaining('345,67'));
        expect(amount.data, isNot(contains('MAD')));
      }
      await tester.tap(find.text('Autre écran'));
      await _pumpUi(tester);
      expect(find.text('Destination'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
