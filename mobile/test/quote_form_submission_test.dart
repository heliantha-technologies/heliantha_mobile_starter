import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_floating_orb.dart';
import 'package:heliantha_mobile/features/quote/data/quote_repository.dart';
import 'package:heliantha_mobile/features/quote/presentation/quote_form_screen.dart';
import 'package:heliantha_mobile/features/quote/presentation/widgets/quote_generating_overlay.dart';
import 'package:heliantha_mobile/features/quote/providers/quote_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingQuoteRepository implements QuoteRepository {
  final result = Completer<QuoteCalculationResult>();
  QuoteRequestPayload? submitted;
  int calls = 0;

  @override
  Future<QuoteCalculationResult> calculate(QuoteRequestPayload payload) {
    calls += 1;
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

Future<void> _fillQuoteForm(WidgetTester tester) async {
  await tester.tap(find.text('Oui, une pompe existe déjà'));
  await _pumpUi(tester);
  await tester.tap(find.text('Suivant'));
  await _pumpUi(tester);
  await tester.tap(find.text('5.5 CV'));
  await _pumpUi(tester);
  await tester.tap(find.text('Suivant'));
  await _pumpUi(tester);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom complet'), 'Sara Heliantha');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Numéro WhatsApp'), '0661575128');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Ville'), 'Casablanca');
  tester.testTextInput.hide();
  await _pumpUi(tester);
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
      await _fillQuoteForm(tester);
      final calculateAction = find.ancestor(
        of: find.text('Calculer mon devis'),
        matching: find.byType(InkWell),
      );
      final onTap = tester.widget<InkWell>(calculateAction).onTap!;
      // Two taps can reach the old callback before the next rendered frame.
      onTap();
      onTap();
      await tester.pump();
      expect(repository.calls, 1);
      expect(
        tester.widget<InkWell>(find.ancestor(
          of: find.text('Calcul en cours...'),
          matching: find.byType(InkWell),
        )).onTap,
        isNull,
      );
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
      if (fails) {
        expect(tester.widget<InkWell>(calculateAction).onTap, isNotNull);
      }
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

  for (final scenario in [
    'normal',
    'unavailable',
    'platform error',
    'large text'
  ]) {
    testWidgets('quote actions stay in the page and handle $scenario',
        (tester) async {
      tester.view.physicalSize =
          Size(scenario == 'large text' ? 320 : 414, 896);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
      final launches = <MethodCall>[];
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, (call) async {
        launches.add(call);
        if (scenario == 'platform error') {
          throw PlatformException(code: 'unavailable');
        }
        return scenario != 'unavailable';
      });
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(launcherChannel, null);
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final textScale = ValueNotifier<double>(1);
      addTearDown(textScale.dispose);
      final repository = _PendingQuoteRepository();
      final router = GoRouter(initialLocation: '/quote/form/pompage', routes: [
        GoRoute(
            path: '/quote/form/pompage',
            builder: (_, __) => const QuoteFormScreen(projectType: 'pompage')),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [quoteRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => ValueListenableBuilder<double>(
            valueListenable: textScale,
            builder: (_, scale, __) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ));
      await _pumpUi(tester);
      await _fillQuoteForm(tester);
      await tester.tap(find.text('Calculer mon devis'));
      await tester.pump();
      repository.result.complete(const QuoteCalculationResult({
        'quote_number': 'DEV-FR & 42',
        'total_ttc': 12345.67,
        'power_kwc': 5.85,
        'pdf_url': '/v1/devis/DEV-FR-42/pdf',
      }));
      await _pumpUi(tester);
      if (scenario == 'large text') {
        textScale.value = 2;
        await _pumpUi(tester);
      }
      final whatsApp = find.byKey(const ValueKey('quote-whatsapp-action'));
      final pdf = find.byKey(const ValueKey('quote-pdf-action'));
      await tester.ensureVisible(whatsApp);
      await _pumpUi(tester);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.getSize(whatsApp).height, greaterThanOrEqualTo(52));
      expect(tester.getSize(pdf).height, greaterThanOrEqualTo(48));
      expect(
          tester.getTopLeft(whatsApp).dy, lessThan(tester.getTopLeft(pdf).dy));
      expect(tester.getTopLeft(pdf).dy - tester.getBottomLeft(whatsApp).dy,
          closeTo(10, 0.1));
      final assistantAction = find
          .descendant(
            of: find.byType(AiFloatingOrb),
            matching: find.byType(GestureDetector),
          )
          .first;
      expect(tester.getRect(assistantAction).overlaps(tester.getRect(whatsApp)),
          isFalse);
      expect(tester.getRect(assistantAction).overlaps(tester.getRect(pdf)),
          isFalse);
      expect(tester.getTopLeft(pdf).dy,
          lessThan(tester.getTopLeft(find.text('Refaire une estimation')).dy));
      expect(tester.takeException(), isNull);
      await tester.tap(whatsApp);
      await _pumpUi(tester);
      expect(haptics, contains('HapticFeedbackType.lightImpact'));
      final args = launches.single.arguments as Map;
      final uri = Uri.parse(args['url'] as String);
      expect(uri.host, 'wa.me');
      expect(uri.path, '/212661575128');
      final message = uri.queryParameters['text']!;
      expect(message, contains('devis n° DEV-FR & 42'));
      expect(message, contains('Puissance : 5.85 kWc'));
      expect(message.replaceAll(RegExp(r'\s|\u00a0|\u202f'), ''),
          contains('Montant:12345,67DH'));
      expect(message, contains('concrétiser mon installation.'));
      expect(args['useWebView'], isFalse);
      expect(args['useSafariVC'], isFalse);
      if (scenario == 'unavailable' || scenario == 'platform error') {
        expect(find.textContaining('+212 661 57 51 28'), findsOneWidget);
      } else {
        await tester.ensureVisible(pdf);
        await _pumpUi(tester);
        await tester.tap(pdf);
        await _pumpUi(tester);
        expect((launches.last.arguments as Map)['url'],
            'https://app.heliantha.ma/v1/devis/DEV-FR-42/pdf');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
