import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/app.dart';
import 'package:heliantha_mobile/core/maintenance/maintenance_provider.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:heliantha_mobile/features/catalog/providers/store_context_provider.dart';
import 'package:heliantha_mobile/features/home/providers/home_provider.dart';

class _OkMaintenance extends MaintenanceRepository {
  @override
  Future<bool> check(
          {bool? previous, required CancelToken cancelToken}) async =>
      false;
}

void main() {
  testWidgets(
      'Bottom NavigationBar aligns Devis label with other tabs and keeps safe bottom margin on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final maintenance = _OkMaintenance();
    addTearDown(maintenance.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceRepositoryProvider.overrideWithValue(maintenance),
          currentUserProvider.overrideWith((ref) async => null),
          categoriesProvider.overrideWith((ref) async => const []),
          homeSlidesProvider.overrideWith((ref) async => const []),
          storeContextProvider.overrideWith(
            (ref) async => throw StateError('disabled'),
          ),
        ],
        child: const HelianthaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(NavigationBar), findsOneWidget);
    final devisRect = tester.getRect(find.text('Devis'));
    final compteRect = tester.getRect(find.text('Compte'));

    // Le label "Devis" est aligné sur la même ligne horizontale que les autres onglets 1-ligne
    expect((devisRect.top - compteRect.top).abs(), lessThan(1.5));
    expect((devisRect.bottom - compteRect.bottom).abs(), lessThan(1.5));

    // Marge de sécurité basse suffisante sous les labels pour l'indicateur iOS / barre Android
    expect(844.0 - devisRect.bottom, greaterThanOrEqualTo(14.0));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
