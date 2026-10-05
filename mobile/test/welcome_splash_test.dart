import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:heliantha_mobile/features/home/presentation/home_screen.dart';
import 'package:heliantha_mobile/features/home/providers/home_provider.dart';
import 'package:heliantha_mobile/features/notifications/data/notifications_repository.dart';
import 'package:heliantha_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:heliantha_mobile/shared/models/category.dart';
import 'package:heliantha_mobile/shared/models/home_slide.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seenKey = 'has_seen_welcome_splash';
final _overlay = find.byKey(const ValueKey('home-welcome-overlay'));

Future<void> _mountHome(WidgetTester tester,
    {Map<String, dynamic>? user}) async {
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) async => user),
      categoriesProvider.overrideWith((ref) async => <Category>[]),
      homeSlidesProvider.overrideWith((ref) async => <HomeSlide>[]),
      notificationsProvider.overrideWith(
        (ref) async => const NotificationsResult(items: [], unread: 0),
      ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'First visit welcomes guests, persists immediately and lasts 1.35s',
      (tester) async {
    await _mountHome(tester);
    expect(find.text('Marhaba 👋'), findsOneWidget);
    expect(find.text('Bienvenue chez HeliAntha'), findsOneWidget);
    expect(find.text('Heureux de vous retrouver ✨'), findsNothing);
    expect((await SharedPreferences.getInstance()).getBool(_seenKey), isTrue);

    await tester.pump(const Duration(milliseconds: 1340));
    expect(_overlay, findsOneWidget);
    // Allow the next rendered frame to remove the completed overlay.
    await tester.pump(const Duration(milliseconds: 60));
    expect(_overlay, findsNothing);
    expect(find.text('Nos Univers Solaires'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Known users receive a greeting with their trimmed first name',
      (tester) async {
    await _mountHome(tester, user: {'id': 7, 'firstname': '  Salma  '});
    expect(find.text('Marhaba Salma 👋'), findsOneWidget);
    expect(find.text('Heureux de vous retrouver ✨'), findsOneWidget);
    expect(find.text('Bienvenue chez HeliAntha'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Users without a first name receive the guest greeting',
      (tester) async {
    await _mountHome(tester, user: {'id': 7, 'firstname': '  '});
    expect(find.text('Marhaba 👋'), findsOneWidget);
    expect(find.text('Bienvenue chez HeliAntha'), findsOneWidget);
    expect(find.text('Heureux de vous retrouver ✨'), findsNothing);
  });

  testWidgets('Tapping the central card dismisses it with a short fade',
      (tester) async {
    await _mountHome(tester);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.tap(find.text('Marhaba 👋'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    expect(_overlay, findsOneWidget);
    // A repeated tap must not restart the fade or extend the wait.
    await tester.tap(find.text('Marhaba 👋'));
    await tester.pump(const Duration(milliseconds: 95));
    expect(_overlay, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping outside the card closes even during the entrance',
      (tester) async {
    await _mountHome(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(10, 200));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));
    expect(_overlay, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A saved welcome flag gives direct access on app startup',
      (tester) async {
    SharedPreferences.setMockInitialValues({_seenKey: true});
    await _mountHome(tester);
    expect(_overlay, findsNothing);
    expect(find.textContaining('Marhaba'), findsNothing);
    expect(find.text('Nos Univers Solaires'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(_overlay, findsNothing);
  });

  testWidgets('Recreating the home screen keeps the welcome dismissed',
      (tester) async {
    await _mountHome(tester);
    expect(_overlay, findsOneWidget);
    // Recreate the screen and provider scope, keeping only local preferences.
    await tester.pumpWidget(const SizedBox());
    await _mountHome(tester);
    expect(_overlay, findsNothing);
    expect(find.textContaining('Marhaba'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
