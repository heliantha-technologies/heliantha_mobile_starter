import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/core/config/app_config.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_api_service.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_reply.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/assistant_product_card.dart';

const _product = AssistantProduct(
  localId: '2',
  name: 'Panneau solaire 590 Wc',
  reference: 'CS6W-590TB-AG',
  description: '590 Wc',
  price: 1135.20,
  inStock: true,
);

class _ProductAssistantService extends AssistantApiService {
  @override
  Future<AssistantReply> sendReply({
    required List<Map<String, String>> history,
    String? contextPrompt,
  }) async =>
      const AssistantReply(
        text: 'Voici votre sélection.\n'
            '<<<DEVIS_DATA: {"reference":"H-TEST","total_ttc":12000}>>>',
        suggestedProducts: [_product],
      );
}

void main() {
  testWidgets('compact card opens its local product details on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launches = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      launches.add(call);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final product = AssistantProduct(
      name: _product.name,
      localId: _product.localId,
      reference: _product.reference,
      description: _product.description,
      price: _product.price,
      inStock: true,
      datasheetUri: Uri.parse('https://example.com/panel.pdf'),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: AssistantProductCard(product: product),
        ),
      ),
    ));
    expect(find.textContaining('DH HT'), findsOneWidget);
    expect(find.text('En stock'), findsOneWidget);
    await tester.tap(find.text('Voir la fiche produit'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantProductDetailsSheet), findsOneWidget);
    expect(find.text('Référence : CS6W-590TB-AG'), findsOneWidget);
    expect(find.text('Fiche technique'), findsOneWidget);
    expect(find.text('Conseiller sur WhatsApp'), findsOneWidget);
    await tester.tap(find.text('Fiche technique'));
    await tester.pump();
    expect((launches.single.arguments as Map)['url'],
        'https://example.com/panel.pdf');
    await tester.tap(find.text('Conseiller sur WhatsApp'));
    await tester.pump();
    final contactUri =
        Uri.parse((launches.last.arguments as Map)['url'] as String);
    expect(contactUri.host, 'wa.me');
    expect(contactUri.path, '/${AppConfig.supportWhatsAppNumber}');
    expect(contactUri.queryParameters['text'], contains('CS6W-590TB-AG'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Fermer la fiche produit'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantProductDetailsSheet), findsNothing);
  });

  testWidgets('chat displays suggested products alongside the official quote',
      (tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        assistantApiServiceProvider
            .overrideWithValue(_ProductAssistantService()),
      ],
      child: const MaterialApp(
        home:
            Scaffold(body: AiChatBottomSheet(initialQuestion: 'Des panneaux')),
      ),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('H-TEST'), findsOneWidget);
    expect(find.byType(AssistantProductCard), findsOneWidget);
    final productCard = find.byType(AssistantProductCard);
    await tester.ensureVisible(productCard);
    await tester.pumpAndSettle();
    await tester.tap(productCard);
    await tester.pumpAndSettle();
    expect(find.byType(AssistantProductDetailsSheet), findsOneWidget);
    expect(find.text('Référence : CS6W-590TB-AG'), findsOneWidget);
    expect(find.text('Fiche technique'), findsNothing,
        reason: 'No datasheet URL should result in no download action.');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
