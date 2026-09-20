import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/auth/providers/auth_provider.dart';
import 'package:heliantha_mobile/features/cart/providers/cart_provider.dart';
import 'package:heliantha_mobile/features/checkout/domain/checkout_models.dart';
import 'package:heliantha_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:heliantha_mobile/features/orders/data/orders_repository.dart';
import 'package:heliantha_mobile/features/orders/presentation/orders_screen.dart';
import 'package:heliantha_mobile/features/orders/providers/orders_provider.dart';
import 'package:heliantha_mobile/shared/models/order.dart';
import 'package:heliantha_mobile/shared/models/product.dart';

class _FakeOrdersRepository implements OrdersRepository {
  bool listCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<OrderModel>> list() async {
    listCalled = true;
    return [];
  }
}

void main() {
  group('Guest Checkout & Orders Security Tests', () {
    testWidgets('guest checkout → confirmation correcte, référence affichée, aucun /orders', (tester) async {
      var ordersNavigated = false;
      var homeNavigated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderSuccessDialog(
              result: const CheckoutConfirmResult(
                orderId: 101,
                reference: 'GUEST-REF-123',
                total: 199.0,
                currency: 'MAD',
              ),
              fallbackTotal: 199.0,
              fallbackCurrency: 'MAD',
              isConnected: false,
              onOrders: () => ordersNavigated = true,
              onHome: () => homeNavigated = true,
            ),
          ),
        ),
      );

      // Vérification Titre exact
      expect(find.text('Commande enregistrée'), findsOneWidget);
      expect(find.text('Commande confirmée !'), findsNothing);

      // Vérification Message exact
      expect(
        find.text(
          'Merci pour votre confiance ! Votre commande a bien été enregistrée. Notre équipe va la traiter prochainement.',
        ),
        findsOneWidget,
      );

      // Vérification Référence exacte
      expect(find.text('Commande n°GUEST-REF-123'), findsOneWidget);

      // Vérification qu'il n'y a PAS de mention "Mes commandes" pour l'invité
      expect(find.text('Vous pouvez suivre son état depuis Mes commandes.'), findsNothing);

      // Vérification des boutons : aucun "Voir ma commande"
      expect(find.text('Voir ma commande'), findsNothing);
      expect(find.text('Retour à l’accueil'), findsOneWidget);

      // Clic sur "Retour à l’accueil"
      await tester.tap(find.text('Retour à l’accueil'));
      await tester.pump();

      expect(homeNavigated, isTrue);
      expect(ordersNavigated, isFalse);
    });

    test('guest checkout → panier vidé après confirmation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      const product = Product(
        id: 1,
        name: 'Huile de Tournesol Bio',
        price: 85.0,
        currency: 'MAD',
        currencySymbol: 'DH',
        available: true,
      );
      notifier.add(product);
      notifier.add(product);

      expect(container.read(cartProvider), isNotEmpty);
      expect(container.read(cartProvider).first.quantity, 2);

      // Simulation de la fin de commande
      notifier.clear();

      expect(container.read(cartProvider), isEmpty);
    });

    testWidgets('utilisateur connecté → comportement /orders conservé', (tester) async {
      var ordersNavigated = false;
      var homeNavigated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderSuccessDialog(
              result: const CheckoutConfirmResult(
                orderId: 202,
                reference: 'USER-REF-456',
                total: 450.0,
                currency: 'MAD',
              ),
              fallbackTotal: 450.0,
              fallbackCurrency: 'MAD',
              isConnected: true,
              onOrders: () => ordersNavigated = true,
              onHome: () => homeNavigated = true,
            ),
          ),
        ),
      );

      // Titre connecté
      expect(find.text('Commande confirmée !'), findsOneWidget);
      expect(find.text('Votre commande a bien été enregistrée.'), findsOneWidget);

      // Référence dans la ligne méta standard
      expect(find.text('USER-REF-456'), findsOneWidget);

      // Mention Mes commandes
      expect(find.text('Vous pouvez suivre son état depuis Mes commandes.'), findsOneWidget);

      // Boutons pour client connecté
      expect(find.text('Voir ma commande'), findsOneWidget);
      expect(find.text('Retour à l’accueil'), findsOneWidget);

      // Clic sur "Voir ma commande"
      await tester.tap(find.text('Voir ma commande'));
      await tester.pump();

      expect(ordersNavigated, isTrue);
      expect(homeNavigated, isFalse);
    });

    testWidgets('accès direct invité à /orders → aucun appel API /orders et affiche connexion requise', (tester) async {
      final fakeRepo = _FakeOrdersRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Future.value(null)),
            ordersRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: OrdersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aucun appel vers le repository /orders
      expect(fakeRepo.listCalled, isFalse);

      // Affichage d'un état propre
      expect(find.text('Connexion requise'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.text('Retour à l’accueil'), findsOneWidget);

      // Pas d'erreur "Service momentanément indisponible"
      expect(find.text('Service momentanément indisponible'), findsNothing);
      expect(find.text('Erreur de chargement'), findsNothing);
    });
  });
}

