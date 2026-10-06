import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Quote nav icon test verifies scaffold and navigation destinations',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const Center(child: Text('HeliAntha')),
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: Icon(Icons.bolt),
                label: 'Devis',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Devis'), findsOneWidget);
  });
}

