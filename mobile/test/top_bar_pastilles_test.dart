import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/cart/domain/cart_item.dart';
import 'package:heliantha_mobile/features/cart/providers/cart_provider.dart';
import 'package:heliantha_mobile/features/notifications/data/notifications_repository.dart';
import 'package:heliantha_mobile/features/notifications/presentation/notification_bell.dart';
import 'package:heliantha_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:heliantha_mobile/shared/models/product.dart';
import 'package:heliantha_mobile/shared/widgets/brand_widgets.dart';

class _FakeCartNotifier extends CartNotifier {
  _FakeCartNotifier(List<CartItem> items) {
    state = items;
  }
}

void main() {
  group('TopBar Action Pastilles Tests', () {
    testWidgets(
        'AppCartButton renders TopBarActionPastille with cart icon and badge',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartProvider.overrideWith(
              (ref) => _FakeCartNotifier([
                const CartItem(
                  product: Product(
                    id: 1,
                    name: 'Panneau Solaire 550W',
                    price: 1800,
                    available: true,
                    currency: 'MAD',
                    currencySymbol: 'DH',
                  ),
                  quantity: 3,
                ),
              ]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: AppTopBar(
                subtitle: 'Test TopBar',
              ),
            ),
          ),
        ),
      );

      // Verify the cart action pastille is present
      expect(find.byType(TopBarActionPastille), findsWidgets);
      expect(find.byIcon(Icons.shopping_cart_rounded), findsOneWidget);
      // Verify the badge counter displays '3'
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('Devise TopBarActionPastille renders with payments icon',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TopBarActionPastille(
              tooltip: 'Devise',
              icon: Icons.payments_rounded,
              iconColor: Color(0xFFD97706),
              backgroundColor: Color(0xFFFEF3C7),
              borderColor: Color(0xFFF59E0B),
            ),
          ),
        ),
      );

      expect(find.byType(TopBarActionPastille), findsOneWidget);
      expect(find.byIcon(Icons.payments_rounded), findsOneWidget);
      expect(find.byTooltip('Devise'), findsOneWidget);
    });

    testWidgets('NotificationBell renders with notifications icon and pastille',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsProvider.overrideWith(
              (ref) async => const NotificationsResult(items: [], unread: 2),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: AppTopBar(
                subtitle: 'Test',
                actions: [NotificationBell()],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(NotificationBell), findsOneWidget);
      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });
}
