import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:heliantha_mobile/features/favorites/presentation/favorites_screen.dart';
import 'package:heliantha_mobile/shared/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _thumbnail = find.byKey(const ValueKey('favorite-product-image-42'));

Future<void> _mountFavorites(WidgetTester tester, String? imageUrl) async {
  SharedPreferences.setMockInitialValues({
    'favorite_product_ids': ['42'],
  });
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) async => null),
      productProvider(42).overrideWith((ref) async => Product(
            id: 42,
            name: 'Variateur solaire',
            price: 1800,
            currency: 'MAD',
            currencySymbol: 'DH',
            available: true,
            imageUrl: imageUrl,
          )),
    ],
    child: const MaterialApp(home: FavoritesScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final image in [
    (label: 'missing', url: null),
    (label: 'blank', url: ' \n\t '),
  ]) {
    testWidgets('Favorites show a clean placeholder for ${image.label} photos',
        (tester) async {
      await _mountFavorites(tester, image.url);
      expect(
          find.descendant(
              of: _thumbnail, matching: find.byIcon(Icons.solar_power_rounded)),
          findsOneWidget);
      expect(find.descendant(of: _thumbnail, matching: find.byType(Image)),
          findsNothing);
      expect(
          find.descendant(
              of: _thumbnail, matching: find.byType(CachedNetworkImage)),
          findsNothing);
      expect(find.text('Variateur solaire'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Web favorites decode photos with the catalogue image loader',
      (tester) async {
    final bytes = await rootBundle.load('assets/brand/helin.jpeg');
    final url = 'data:image/jpeg;base64,${base64Encode(bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    ))}';
    await _mountFavorites(tester, url);
    expect(
        find.descendant(
            of: _thumbnail, matching: find.byType(CachedNetworkImage)),
        findsNothing);
    final image = tester.widget<Image>(
        find.descendant(of: _thumbnail, matching: find.byType(Image)));
    Object? decodingError;
    await tester.runAsync(() => precacheImage(
          image.image,
          tester.element(_thumbnail),
          onError: (error, _) => decodingError = error,
        ).timeout(const Duration(seconds: 15)));
    await tester.pumpAndSettle();
    expect(decodingError, isNull);
    expect(
        tester
            .widget<RawImage>(find.descendant(
                of: _thumbnail, matching: find.byType(RawImage)))
            .image,
        isNotNull);
    expect(tester.takeException(), isNull);
  }, skip: !kIsWeb);
}
