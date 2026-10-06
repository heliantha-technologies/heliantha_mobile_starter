import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_api_service.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_reply.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAssistantService extends AssistantApiService {
  @override
  Future<AssistantReply> sendReply({
    required List<Map<String, String>> history,
    String? contextPrompt,
  }) async {
    return const AssistantReply(
      text: 'Réponse mémorisée avec succès.',
      suggestedProducts: [
        AssistantProduct(
          name: 'Panneau HeliAntha 585 Wc',
          price: 480,
          currency: 'DH',
          priceTax: 'HT',
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Conversation is persisted to SharedPreferences and restored on reopen',
      (tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});

    // 1. Première session : envoi d'un message
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantApiServiceProvider.overrideWithValue(_FakeAssistantService()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatBottomSheet(initialQuestion: 'Mon projet solaire')),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Mon projet solaire'), findsOneWidget);
    expect(find.text('Réponse mémorisée avec succès.'), findsOneWidget);
    expect(find.text('Panneau HeliAntha 585 Wc'), findsOneWidget);

    // Vérification que le cache SharedPreferences a bien été écrit
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('heliantha_chat_history');
    expect(cached, isNotNull);
    final decoded = jsonDecode(cached!) as List;
    expect(decoded.length, greaterThanOrEqualTo(2));

    // 2. Fermeture du widget (simulation de fermeture de modal ou rafraîchissement)
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    // 3. Deuxième session : réouverture sans initialQuestion
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantApiServiceProvider.overrideWithValue(_FakeAssistantService()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AiChatBottomSheet()),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // L'historique et les produits doivent être immédiatement restaurés
    expect(find.text('Mon projet solaire'), findsOneWidget);
    expect(find.text('Réponse mémorisée avec succès.'), findsOneWidget);
    expect(find.text('Panneau HeliAntha 585 Wc'), findsOneWidget);

    // 4. Test du bouton Réinitialiser / Nouvelle discussion
    final resetButton = find.byKey(const ValueKey('ai_chat_reset_button'));
    expect(resetButton, findsOneWidget);

    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    // L'ancien historique doit être vidé
    expect(find.text('Mon projet solaire'), findsNothing);
    expect(find.text('Réponse mémorisée avec succès.'), findsNothing);
    expect(find.text('Panneau HeliAntha 585 Wc'), findsNothing);

    // Seul le message d'accueil officiel doit être présent
    expect(find.textContaining('Bonjour ! Je suis votre conseiller solaire HeliAntha'), findsOneWidget);

    // Le cache SharedPreferences doit être nettoyé
    final clearedCache = prefs.getString('heliantha_chat_history');
    expect(clearedCache, isNull);
  });
}

