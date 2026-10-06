import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_api_service.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart';

class _FakeAssistantApiService extends AssistantApiService {
  @override
  Future<String> sendMessage({
    required List<Map<String, String>> history,
    String? contextPrompt,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return 'Bonjour ! HeliAntha est ravi de vous accompagner.';
  }
}

void main() {
  testWidgets('Le bouton d’envoi affiche la flèche puis le soleil orbital', (tester) async {
    final fakeService = _FakeAssistantApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantApiServiceProvider.overrideWithValue(fakeService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiChatBottomSheet(),
          ),
        ),
      ),
    );

    await tester.pump();

    // 1. Bouton initialement avec la flèche d'envoi
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    // 2. Saisie
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);
    await tester.enterText(inputFinder, 'Besoin de pompage solaire');
    await tester.pump();

    // 3. Taper sur le bouton d'envoi
    final sendButtonFinder = find.bySemanticsLabel('Envoyer le message');
    expect(sendButtonFinder, findsOneWidget);
    await tester.tap(sendButtonFinder);
    await tester.pump();

    // 4. En cours de réflexion, le soleil orbital est affiché sur le bouton
    expect(find.byKey(const ValueKey('spinning_sun_send')), findsOneWidget);

    // 5. Finalisation du streaming
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    // 6. Retour à l'état prêt
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(find.textContaining('HeliAntha est ravi'), findsOneWidget);
  });
}

