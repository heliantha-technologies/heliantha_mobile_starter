import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_api_service.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_reply.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/assistant_product_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingAssistantService extends AssistantApiService {
  final result = Completer<AssistantReply>();

  @override
  Future<AssistantReply> sendReply({
    required List<Map<String, String>> history,
    String? contextPrompt,
  }) =>
      result.future;
}

void main() {
  testWidgets('long reply, quote and products appear without a typing delay',
      (tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final service = _PendingAssistantService();
    await tester.pumpWidget(ProviderScope(
      overrides: [assistantApiServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        home: Scaffold(body: AiChatBottomSheet(initialQuestion: 'Mon projet')),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('spinning_sun_send')), findsOneWidget);
    // Finish the initial scroll while the API is still pending, so the lazy
    // conversation list has mounted the reply placeholder before reception.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final longText =
        '${List.filled(80, 'Votre installation solaire est dimensionnée. ').join()}'
        'Fin de la réponse complète.';
    final receivedAt = tester.binding.clock.now();
    service.result.complete(AssistantReply(
      text: '$longText\n'
          '<<<DEVIS_DATA: {"ref":"DEV-INSTANT","total_ttc":12000,'
          '"access_token":"quote-access-token"}>>>',
      suggestedProducts: const [
        AssistantProduct(name: 'Panneau recommandé', price: 480),
      ],
    ));
    // Render the completed Future without advancing the simulated clock.
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Envoyer le message'), findsOneWidget);
    expect(find.byKey(const ValueKey('send_arrow')), findsOneWidget);

    final list = tester.widget<ListView>(find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
    ));
    // Mount the lazy final message without waiting for the scroll animation.
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pump();

    expect(tester.binding.clock.now(), receivedAt);
    expect(find.text(longText), findsOneWidget);
    expect(find.text('DEV-INSTANT'), findsOneWidget);
    expect(find.byType(AssistantProductCard), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('spinning_sun_send')), findsNothing);
    final position = list.controller!.position;
    expect(position.pixels, closeTo(position.maxScrollExtent, 4));

    final prefs = await SharedPreferences.getInstance();
    final history =
        jsonDecode(prefs.getString('heliantha_chat_history')!) as List;
    final message = history.last as Map;
    expect(message['text'], longText);
    expect(
        (message['devis_data'] as Map)['access_token'], 'quote-access-token');
    expect(
      Uri.parse((message['devis_data'] as Map)['pdf_url'] as String)
          .queryParameters['token'],
      'quote-access-token',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
