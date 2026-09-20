import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/app.dart';

void main() {
  testWidgets('renders Heliantha app shell', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HelianthaApp(),
      ),
    );

    expect(find.text('HELIANTHA'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
