import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heliantha_mobile/core/maintenance/maintenance_gate.dart';
import 'package:heliantha_mobile/core/maintenance/maintenance_provider.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/notifications/data/notifications_repository.dart';
import 'package:heliantha_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:heliantha_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:heliantha_mobile/features/quote/presentation/widgets/quote_generating_overlay.dart';
import 'package:heliantha_mobile/shared/models/notification_item.dart';
import 'package:heliantha_mobile/shared/utils/friendly_errors.dart';

class _FakeNotificationsRepository implements NotificationsRepository {
  int listCalls = 0;
  Object? errorToThrow;

  @override
  Future<NotificationsResult> list() async {
    listCalls++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return NotificationsResult(
      items: [
        NotificationItem(
          id: 1,
          type: 'ORDER_STATUS',
          title: 'Commande confirmée',
          body: 'Votre commande solaire est en préparation.',
          createdAt: DateTime(2026, 11, 18, 10, 30),
          metadata: const {},
          orderId: 101,
        ),
      ],
      unread: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedMaintenanceRepository extends MaintenanceRepository {
  final calls = <Completer<bool>>[];
  @override
  Future<bool> check({bool? previous, required CancelToken cancelToken}) {
    final c = Completer<bool>();
    calls.add(c);
    return c.future;
  }
}

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

  testWidgets(
      'guest notifications skip API, show Connexion requise, and auto-load on login without reload',
      (tester) async {
    final repo = _FakeNotificationsRepository();
    Map<String, dynamic>? currentUser;
    Uri? pushedLoginUri;

    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, state) {
            pushedLoginUri = state.uri;
            return const Scaffold(body: Text('Page Connexion'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) async => currentUser),
        notificationsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // En invité : aucun appel API /v1/notifications et pas de faux message "Service indisponible".
    expect(repo.listCalls, 0);
    expect(find.text('Connexion requise'), findsOneWidget);
    expect(find.text('Service momentanément indisponible'), findsNothing);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Page Connexion'), findsOneWidget);
    expect(pushedLoginUri?.queryParameters['redirect'], '/notifications');

    router.pop();
    await tester.pumpAndSettle();

    // Simulation de connexion : l'invalidation de currentUserProvider recharge automatiquement les notifications.
    currentUser = {'id': 7, 'email': 'client@heliantha.ma'};
    container.invalidate(currentUserProvider);
    await tester.pumpAndSettle();

    expect(repo.listCalls, 1);
    expect(find.text('Centre de notifications'), findsOneWidget);
    expect(find.text('Commande confirmée'), findsOneWidget);
  });

  testWidgets(
      'connected notifications distinguish expired session, network outage and server error safely',
      (tester) async {
    final repo = _FakeNotificationsRepository();
    repo.errorToThrow = DioException(
      requestOptions: RequestOptions(path: '/v1/notifications'),
      response: Response(
        requestOptions: RequestOptions(path: '/v1/notifications'),
        statusCode: 401,
        data: {'detail': 'Invalid token at 192.168.1.10:8011'},
      ),
    );

    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) async => {'id': 7}),
        notificationsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 401 -> Session expirée avec bouton Se reconnecter
    expect(find.text('Session expirée'), findsOneWidget);
    expect(find.text('Se reconnecter'), findsOneWidget);
    expect(containsTechnicalLeak('Session expirée'), isFalse);

    // Coupure réseau -> Connexion Internet indisponible
    repo.errorToThrow = DioException(
      requestOptions: RequestOptions(path: '/v1/notifications'),
      type: DioExceptionType.connectionTimeout,
    );
    container.invalidate(notificationsProvider);
    await tester.pumpAndSettle();
    expect(find.text('Connexion Internet indisponible'), findsOneWidget);

    // Erreur 500 -> Actualisation momentanément indisponible sans fuite technique
    repo.errorToThrow = DioException(
      requestOptions: RequestOptions(path: '/v1/notifications'),
      response: Response(
        requestOptions: RequestOptions(path: '/v1/notifications'),
        statusCode: 500,
        data: 'Traceback SQL error on 127.0.0.1:5432',
      ),
    );
    container.invalidate(notificationsProvider);
    await tester.pumpAndSettle();
    expect(
      find.text('Actualisation momentanément indisponible'),
      findsOneWidget,
    );
  });

  testWidgets(
      'MaintenanceGate resume on already available app keeps TextField focused and onscreen',
      (tester) async {
    final repository = _DelayedMaintenanceRepository();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    addTearDown(repository.dispose);

    final container = ProviderContainer(
      overrides: [
        maintenanceRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MaintenanceGate(
            child: Scaffold(
              body: TextField(focusNode: focusNode),
            ),
          ),
        ),
      ),
    );

    repository.calls.first.complete(false);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // Simule une mise en pause puis reprise du cycle de vie (changement d'onglet / retour app).
    final notifier = container.read(maintenanceProvider.notifier);
    notifier.pause();
    notifier.resume();
    await tester.pump();

    // L'état reste `available` pendant la vérification de reprise : le TextField ne passe pas en Offstage et garde son focus.
    expect(container.read(maintenanceProvider), MaintenanceStatus.available);
    expect(find.byType(TextField), findsOneWidget);
    expect(focusNode.hasFocus, isTrue);
  });
}
