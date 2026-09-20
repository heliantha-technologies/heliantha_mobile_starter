import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heliantha_mobile/app.dart';
import 'package:heliantha_mobile/core/router/app_router.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/catalog/providers/store_context_provider.dart';

void main() {
  testWidgets('renders Heliantha app shell without live services', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    appRouter.go('/privacy');

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) async => null),
            storeContextProvider.overrideWith(
              (ref) async => throw StateError('Store context disabled in widget test'),
            ),
          ],
          child: const HelianthaApp(),
        ),
      );

      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    } finally {
      appRouter.go('/');
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
