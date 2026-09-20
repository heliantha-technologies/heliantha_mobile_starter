import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/auth/presentation/login_screen.dart';
import 'package:heliantha_mobile/features/auth/presentation/register_screen.dart';
import 'package:heliantha_mobile/features/checkout/presentation/checkout_screen.dart';

void main() {
  group('Password Visibility Toggle Tests', () {
    testWidgets('LoginScreen: password hidden by default, toggles on click, retains text', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump();

      // Find password TextField
      final passwordFieldFinder = find.widgetWithText(TextField, 'Mot de passe');
      expect(passwordFieldFinder, findsOneWidget);

      TextField passwordField = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordField.obscureText, isTrue, reason: 'Password should be masked by default');

      // Check initial toggle button (eye icon masked / off)
      final toggleFinder = find.byTooltip('Afficher le mot de passe');
      expect(toggleFinder, findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // Enter text
      await tester.enterText(passwordFieldFinder, 'SecretPassword123!');
      await tester.pump();

      // Click toggle
      await tester.tap(toggleFinder);
      await tester.pump();

      // Now password should be visible
      passwordField = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordField.obscureText, isFalse, reason: 'Password should now be visible');
      expect(passwordField.controller?.text, 'SecretPassword123!', reason: 'Entered text must be preserved');
      expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Click again to hide
      await tester.tap(find.byTooltip('Masquer le mot de passe'));
      await tester.pump();

      passwordField = tester.widget<TextField>(passwordFieldFinder);
      expect(passwordField.obscureText, isTrue, reason: 'Password should be masked again');
      expect(passwordField.controller?.text, 'SecretPassword123!');
      expect(find.byTooltip('Afficher le mot de passe'), findsOneWidget);
    });

    testWidgets('RegisterScreen: independent toggles for password and confirm password', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );
      await tester.pump();

      final passwordFieldFinder = find.widgetWithText(TextFormField, 'Mot de passe');
      final confirmFieldFinder = find.widgetWithText(TextFormField, 'Confirmer le mot de passe');

      expect(passwordFieldFinder, findsOneWidget);
      expect(confirmFieldFinder, findsOneWidget);

      TextField getInnerTextField(Finder formField) =>
          tester.widget<TextField>(find.descendant(of: formField, matching: find.byType(TextField)));

      expect(getInnerTextField(passwordFieldFinder).obscureText, isTrue, reason: 'Password should be masked by default');
      expect(getInnerTextField(confirmFieldFinder).obscureText, isTrue, reason: 'Confirm password should be masked by default');

      // Both show 'Afficher le mot de passe'
      expect(find.byTooltip('Afficher le mot de passe'), findsNWidgets(2));

      // Tap first toggle (password)
      final toggleButtons = find.byTooltip('Afficher le mot de passe');
      await tester.tap(toggleButtons.first);
      await tester.pump();

      // Password should be visible, confirm should still be masked
      expect(getInnerTextField(passwordFieldFinder).obscureText, isFalse, reason: 'Password field toggled to visible');
      expect(getInnerTextField(confirmFieldFinder).obscureText, isTrue, reason: 'Confirm password must remain masked');

      // Tap second toggle (confirm password)
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();

      expect(getInnerTextField(passwordFieldFinder).obscureText, isFalse);
      expect(getInnerTextField(confirmFieldFinder).obscureText, isFalse, reason: 'Confirm password toggled to visible');

      // Both are visible -> both tooltips are 'Masquer le mot de passe'
      expect(find.byTooltip('Masquer le mot de passe'), findsNWidgets(2));
    });

    testWidgets('CheckoutLoginStep: password toggle in checkout login step works correctly', (tester) async {
      final emailController = TextEditingController();
      final passwordController = TextEditingController();
      addTearDown(emailController.dispose);
      addTearDown(passwordController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckoutLoginStep(
              email: emailController,
              password: passwordController,
              loading: false,
              onLogin: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final passwordFieldFinder = find.widgetWithText(TextFormField, 'Mot de passe');
      expect(passwordFieldFinder, findsOneWidget);

      final innerTextField = tester.widget<TextField>(
          find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)));
      expect(innerTextField.obscureText, isTrue, reason: 'Checkout password should be masked by default');

      final toggleFinder = find.byTooltip('Afficher le mot de passe');
      expect(toggleFinder, findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.enterText(passwordFieldFinder, 'CheckoutPass123');
      await tester.pump();

      await tester.tap(toggleFinder);
      await tester.pump();

      final innerTextFieldAfter = tester.widget<TextField>(
          find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)));
      expect(innerTextFieldAfter.obscureText, isFalse, reason: 'Checkout password should now be visible');
      expect(innerTextFieldAfter.controller?.text, 'CheckoutPass123');
      expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byTooltip('Masquer le mot de passe'));
      await tester.pump();

      final innerTextFieldHiddenAgain = tester.widget<TextField>(
          find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)));
      expect(innerTextFieldHiddenAgain.obscureText, isTrue);
    });
  });
}

