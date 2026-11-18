import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heliantha_mobile/core/config/app_config.dart';
import 'package:heliantha_mobile/features/account/presentation/account_screen.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/notifications/data/notifications_repository.dart';
import 'package:heliantha_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:heliantha_mobile/shared/theme/app_vector_icons.dart';

GoRouter _accountRouter() {
  return GoRouter(
    initialLocation: '/account',
    routes: [
      GoRoute(
        path: '/account',
        builder: (_, __) => const AccountScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Route Login')),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const Scaffold(body: Text('Route Register')),
      ),
      GoRoute(
        path: '/orders',
        builder: (_, __) => const Scaffold(body: Text('Route Orders')),
      ),
      GoRoute(
        path: '/addresses',
        builder: (_, __) => const Scaffold(body: Text('Route Addresses')),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, __) => const Scaffold(body: Text('Route Privacy')),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const Scaffold(body: Text('Route Notifications')),
      ),
    ],
  );
}

void main() {
  testWidgets(
      'AccountScreen guest view fits cleanly without scroll on mobile and navigates correctly',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = _accountRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => null),
          notificationsProvider.overrideWith(
            (ref) async => const NotificationsResult(items: [], unread: 0),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Espace client Heliantha'), findsOneWidget);
    // Vérifie un léger dégagement logique sous la barre haute sans descente excessive.
    final heroTop = tester.getTopLeft(find.text('ESPACE HELIANTHA')).dy;
    expect(heroTop, greaterThan(75));
    expect(heroTop, lessThan(115));
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Contact & assistance'), findsOneWidget);
    expect(find.text(AppConfig.supportPhoneDisplay), findsOneWidget);
    expect(find.text(AppConfig.supportWhatsAppDisplay), findsOneWidget);
    expect(find.text(AppConfig.supportEmail), findsOneWidget);
    expect(find.text('Ouvrir Google Maps'), findsOneWidget);
    expect(find.byType(AppSvgIcon), findsOneWidget);
    expect(find.text('Politique de confidentialité & données'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Route Login'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(find.text('Route Register'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Politique de confidentialité & données'));
    await tester.pumpAndSettle();
    expect(find.text('Route Privacy'), findsOneWidget);
  });

  testWidgets(
      'AccountScreen member view fits without scroll on mobile and desktop and routes actions',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = _accountRouter();
    addTearDown(router.dispose);

    Future<void> mountAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) async => {
                'firstname': 'Youssef',
                'lastname': 'El Amrani',
                'email': 'youssef.amrani@heliantha.ma',
              },
            ),
            notificationsProvider.overrideWith(
              (ref) async => const NotificationsResult(items: [], unread: 0),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mountAt(const Size(390, 844));
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('YE'), findsOneWidget);
    expect(find.text('Youssef El Amrani'), findsOneWidget);
    expect(find.text('youssef.amrani@heliantha.ma'), findsOneWidget);
    expect(find.text('Mes commandes'), findsOneWidget);
    expect(find.text('Mes adresses'), findsOneWidget);
    expect(find.text('Confidentialité'), findsOneWidget);
    expect(find.text('Déconnexion'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mes commandes'));
    await tester.pumpAndSettle();
    expect(find.text('Route Orders'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes adresses'));
    await tester.pumpAndSettle();
    expect(find.text('Route Addresses'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Youssef El Amrani'), findsOneWidget);
    expect(find.text('Contact & assistance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'AccountScreen safely enables scroll on 320x640 with 1.5x text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => null),
          notificationsProvider.overrideWith(
            (ref) async => const NotificationsResult(items: [], unread: 0),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: AccountScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Espace client Heliantha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AccountScreen shows friendly retry panel when loading fails',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) {
              throw Exception('network error');
            }
            return null;
          }),
          notificationsProvider.overrideWith(
            (ref) async => const NotificationsResult(items: [], unread: 0),
          ),
        ],
        child: const MaterialApp(home: AccountScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Réessayer'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Espace client Heliantha'), findsOneWidget);
  });

  testWidgets(
      'AccountScreen allows copying contact details via long press and selection without copy buttons',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final launchedUrls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      urlChannel,
      (call) async {
        if (call.method == 'launch' || call.method == 'launchUrl') {
          final args = call.arguments as Map?;
          final url = args?['url']?.toString();
          if (url != null) launchedUrls.add(url);
        }
        return true;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        urlChannel,
        null,
      );
    });

    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map?;
          final text = args?['text']?.toString();
          if (text != null) copied.add(text);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => null),
          notificationsProvider.overrideWith(
            (ref) async => const NotificationsResult(items: [], unread: 0),
          ),
        ],
        child: const MaterialApp(home: AccountScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Aucun bouton "Copier" visible, mais zones de sélection présentes.
    expect(find.text('Copier'), findsNothing);
    expect(find.byIcon(Icons.copy), findsNothing);
    expect(find.byIcon(Icons.copy_rounded), findsNothing);
    expect(find.byType(SelectionArea), findsNWidgets(4));

    await tester.longPress(find.text(AppConfig.supportPhoneDisplay));
    await tester.pumpAndSettle();
    expect(copied, contains(AppConfig.supportPhoneDisplay));
    expect(
      find.text('Numéro copié : ${AppConfig.supportPhoneDisplay}'),
      findsOneWidget,
    );

    await tester.longPress(find.text('WHATSAPP'));
    await tester.pumpAndSettle();
    expect(copied, contains(AppConfig.supportWhatsAppDisplay));

    await tester.longPress(find.text('E-MAIL'));
    await tester.pumpAndSettle();
    expect(copied, contains(AppConfig.supportEmail));

    await tester.longPress(find.text('NOUS TROUVER'));
    await tester.pumpAndSettle();
    expect(
      copied,
      contains('https://maps.app.goo.gl/NjXA6uSfcy4WEFMu6'),
    );

    // Clic simple sur le texte d'un numéro continue d'ouvrir l'action externe.
    await tester.tap(find.text(AppConfig.supportPhoneDisplay));
    await tester.pumpAndSettle();
    expect(launchedUrls, contains('tel:${AppConfig.supportPhoneNumber}'));

    // Un glisser-sélectionner souris sélectionne sans déclencher l'ouverture externe.
    final emailBox = tester.getRect(find.text(AppConfig.supportEmail));
    final countBeforeDrag = launchedUrls.length;
    final gesture = await tester.startGesture(
      Offset(emailBox.left + 2, emailBox.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(Offset(emailBox.right - 2, emailBox.center.dy));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(launchedUrls.length, countBeforeDrag);
  });
}
