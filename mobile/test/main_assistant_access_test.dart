import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/core/router/app_router.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_api_service.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_floating_orb.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/catalog/data/catalog_repository.dart';
import 'package:heliantha_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:heliantha_mobile/features/catalog/providers/store_context_provider.dart';
import 'package:heliantha_mobile/features/home/providers/home_provider.dart';
import 'package:heliantha_mobile/features/notifications/data/notifications_repository.dart';
import 'package:heliantha_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:heliantha_mobile/shared/models/category.dart';
import 'package:heliantha_mobile/shared/models/home_slide.dart';
import 'package:heliantha_mobile/shared/models/product.dart';
import 'package:heliantha_mobile/shared/models/store_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _products = [
  Product(
    id: 337,
    name: 'Panneau solaire de test',
    price: 1200,
    currency: 'MAD',
    currencySymbol: 'DH',
    available: true,
  ),
];

class _LocalCatalogRepository implements CatalogRepository {
  @override
  Future<CatalogPage> productsPage({
    int page = 1,
    int pageSize = 30,
    int? category,
    String? query,
    int? languageId,
    int? currencyId,
  }) async =>
      CatalogPage(
          items: page == 1 ? _products : [], page: page, hasMore: false);

  @override
  void prefetchProducts({
    int page = 1,
    int pageSize = 30,
    int? category,
    String? query,
    int? languageId,
    int? currencyId,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAssistantService extends AssistantApiService {
  int calls = 0;

  @override
  Future<String> sendMessage({
    required List<Map<String, String>> history,
    String? contextPrompt,
  }) async {
    calls++;
    return 'Réponse locale de test';
  }
}

Future<void> _pumpTransitions(WidgetTester tester) async {
  // The floating orb repeats its animation continuously.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump();
}

void main() {
  testWidgets(
      'main assistant opens from home and catalog without duplicating quote orb',
      (tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'has_seen_welcome_splash': true,
      'favorite_product_ids': <String>[],
    });
    final assistantService = _RecordingAssistantService();
    const mainOrbKey = ValueKey('main-assistant-orb');
    appRouter.go('/');

    try {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => null),
          homeSlidesProvider.overrideWith((ref) async => <HomeSlide>[]),
          categoriesProvider.overrideWith((ref) async => const <Category>[
                Category(id: 3, name: 'Panneaux solaires'),
              ]),
          productsProvider.overrideWith((ref) async => _products),
          storeContextProvider.overrideWith((ref) async => const StoreContext(
                defaultLanguageId: 1,
                languages: [],
                defaultCurrencyId: 1,
                currencies: [],
              )),
          catalogRepositoryProvider
              .overrideWithValue(_LocalCatalogRepository()),
          notificationsProvider.overrideWith(
              (ref) async => const NotificationsResult(items: [], unread: 0)),
          assistantApiServiceProvider.overrideWithValue(assistantService),
        ],
        child: MaterialApp.router(routerConfig: appRouter),
      ));
      await _pumpTransitions(tester);

      for (final route in ['/', '/catalog']) {
        appRouter.go(route);
        await _pumpTransitions(tester);
        expect(find.byKey(mainOrbKey), findsOneWidget);
        expect(find.byType(AiFloatingOrb), findsOneWidget);
        final action = find.descendant(
          of: find.byKey(mainOrbKey),
          matching: find.byWidgetPredicate(
              (widget) => widget is GestureDetector && widget.onTap != null),
        );
        expect(action, findsOneWidget);
        await tester.tap(action);
        await _pumpTransitions(tester);
        expect(find.byType(AiChatBottomSheet), findsOneWidget);
        expect(assistantService.calls, 0,
            reason:
                'Opening the adviser must not send an initial API request.');

        await tester.tap(find.descendant(
          of: find.byType(AiChatBottomSheet),
          matching: find.byIcon(Icons.close_rounded),
        ));
        await _pumpTransitions(tester);
        expect(find.byType(AiChatBottomSheet), findsNothing);
      }

      appRouter.go('/quote');
      await _pumpTransitions(tester);
      expect(find.byKey(mainOrbKey), findsNothing);
      expect(find.byType(AiFloatingOrb), findsOneWidget);

      appRouter.go('/favorites');
      await _pumpTransitions(tester);
      expect(find.byKey(mainOrbKey), findsNothing);
      expect(find.byType(AiFloatingOrb), findsNothing);
      expect(find.text('Aucun favori pour le moment'), findsOneWidget);
      expect(assistantService.calls, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      appRouter.go('/');
    }
  });
}
