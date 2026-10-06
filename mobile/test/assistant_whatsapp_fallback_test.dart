import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/core/config/app_config.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_api_service.dart';
import 'package:heliantha_mobile/features/assistant/data/assistant_reply.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart';

class _AssistantService extends AssistantApiService {
  _AssistantService(this.reply, {this.throwError = false});

  final AssistantReply reply;
  final bool throwError;

  @override
  Future<AssistantReply> sendReply({
    required List<Map<String, String>> history,
    String? contextPrompt,
  }) async {
    if (throwError) throw StateError('Service unavailable');
    return reply;
  }
}

Future<void> _openChat(
  WidgetTester tester, {
  AssistantReply reply = AssistantReply.unavailable,
  bool throwError = false,
}) async {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      assistantApiServiceProvider.overrideWithValue(
        _AssistantService(reply, throwError: throwError),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: AiChatBottomSheet(initialQuestion: 'Salut')),
    ),
  ));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  const contactButton = ValueKey('assistant_whatsapp_contact');
  const channel = MethodChannel('plugins.flutter.io/url_launcher');

  testWidgets('unavailable assistant offers a direct official WhatsApp link',
      (tester) async {
    final launches = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      launches.add(call);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await _openChat(tester);
    expect(find.text(AssistantReply.unavailable.text), findsOneWidget);
    expect(find.byKey(contactButton), findsOneWidget);
    expect(launches, isEmpty, reason: 'Contact opens only when the user taps.');
    await tester.ensureVisible(find.byKey(contactButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(contactButton));
    await tester.pump();

    final arguments = launches.single.arguments as Map;
    final uri = Uri.parse(arguments['url'] as String);
    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/${AppConfig.supportWhatsAppNumber}');
    expect(uri.queryParameters['text'], contains('conseiller solaire'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed WhatsApp launch leaves the official number visible',
      (tester) async {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await _openChat(tester);
    await tester.ensureVisible(find.byKey(contactButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(contactButton));
    await tester.pump();
    expect(
        find.textContaining(AppConfig.supportWhatsAppDisplay), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('normal replies keep the conversation without an outage action',
      (tester) async {
    await _openChat(tester,
        reply: const AssistantReply(text: 'Bonjour, quel est votre projet ?'));
    expect(find.text('Bonjour, quel est votre projet ?'), findsOneWidget);
    expect(find.byKey(contactButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unexpected service errors also offer contact without blocking',
      (tester) async {
    await _openChat(tester, throwError: true);
    expect(find.text(AssistantReply.unavailable.text), findsOneWidget);
    expect(find.byKey(contactButton), findsOneWidget);
    expect(find.bySemanticsLabel('Envoyer le message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
