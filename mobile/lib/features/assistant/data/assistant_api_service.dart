import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import 'assistant_reply.dart';

final assistantApiServiceProvider = Provider<AssistantApiService>((ref) {
  return AssistantApiService();
});

class AssistantApiService {
  AssistantApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 45),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 45),
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  static const _quotaReply = AssistantReply(
    text:
        'Vous avez beaucoup échangé avec notre conseiller solaire. Merci de patienter quelques instants avant de poursuivre votre conversation.',
  );

  static String get endpoint {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return '/api/assistant/chat';
      }
    }
    final base = AppConfig.appBaseUrl.trim();
    if (base.isNotEmpty) {
      return '${base.replaceAll(RegExp(r'/$'), '')}/api/assistant/chat';
    }
    return 'https://app.heliantha.ma/api/assistant/chat';
  }

  Future<String> sendMessage({
    required List<Map<String, String>> history,
    String? contextPrompt,
  }) async =>
      (await sendReply(history: history, contextPrompt: contextPrompt)).text;

  Future<AssistantReply> sendReply({
    required List<Map<String, String>> history,
    String? contextPrompt,
  }) async {
    final formattedMessages = <Map<String, String>>[];

    if (contextPrompt != null && contextPrompt.trim().isNotEmpty) {
      formattedMessages.add({
        'role': 'system',
        'content': contextPrompt.trim(),
      });
    }

    for (final item in history) {
      final role = (item['role'] ?? 'user').trim();
      final content = (item['content'] ?? '').trim();
      if (content.isNotEmpty) {
        formattedMessages.add({
          'role': role.isEmpty ? 'user' : role,
          'content': content,
        });
      }
    }

    if (formattedMessages.isEmpty) {
      return const AssistantReply(
        text:
            'Bonjour ! Comment puis-je vous accompagner dans votre projet solaire ?',
      );
    }

    try {
      final payload = jsonEncode({'messages': formattedMessages});

      final response = await _dio.post<dynamic>(
        endpoint,
        data: payload,
        options: Options(
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 429) return _quotaReply;
      if ((response.statusCode ?? 200) >= 400) {
        return AssistantReply.unavailable;
      }

      final rawData = response.data;
      Map<String, dynamic>? json;

      if (rawData is Map<String, dynamic>) {
        json = rawData;
      } else if (rawData is String && rawData.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawData);
          if (decoded is Map<String, dynamic>) {
            json = decoded;
          } else {
            return AssistantReply.unavailable;
          }
        } catch (_) {
          final text = rawData.trim();
          final contentType = response.headers
                  .value(Headers.contentTypeHeader)
                  ?.toLowerCase() ??
              '';
          if (contentType.contains('json') ||
              text.startsWith('{') ||
              text.startsWith('[') ||
              (text.startsWith('<') && !text.startsWith('<<<DEVIS_DATA:'))) {
            return AssistantReply.unavailable;
          }
          return AssistantReply(text: text);
        }
      }

      if (json != null) {
        final products =
            AssistantReply.parseProducts(json['suggested_products']);
        final answer =
            json['content'] ?? json['reply'] ?? json['message'] ?? json['text'];
        final devisMap = json['devis'] ?? json['quote'];
        final offerWhatsApp = json['offer_whatsapp'] == true;
        final rawAction = json['action'];
        final actionMap = rawAction is Map<String, dynamic>
            ? rawAction
            : (rawAction is Map ? Map<String, dynamic>.from(rawAction) : null);
        if (answer is String && answer.trim().isNotEmpty) {
          var text = answer.trim();
          if (devisMap is Map && !text.contains('<<<DEVIS_DATA:')) {
            text += '\n\n<<<DEVIS_DATA: ${jsonEncode(devisMap)}>>>';
          }
          return AssistantReply(
            text: text,
            suggestedProducts: products,
            offerWhatsApp: offerWhatsApp,
            action: actionMap,
          );
        } else if (devisMap is Map) {
          return AssistantReply(
            text: '<<<DEVIS_DATA: ${jsonEncode(devisMap)}>>>',
            suggestedProducts: products,
            offerWhatsApp: offerWhatsApp,
            action: actionMap,
          );
        } else if (products.isNotEmpty) {
          return AssistantReply(
            text: 'Voici les produits proposés pour votre demande :',
            suggestedProducts: products,
            offerWhatsApp: offerWhatsApp,
            action: actionMap,
          );
        }
      }

      if (json == null && rawData is String && rawData.trim().isNotEmpty) {
        return AssistantReply(text: rawData.trim());
      }

      return AssistantReply.unavailable;
    } on TimeoutException {
      return AssistantReply.unavailable;
    } on DioException catch (dioError) {
      if (dioError.response?.statusCode == 429) {
        return _quotaReply;
      }
      return AssistantReply.unavailable;
    } catch (_) {
      return AssistantReply.unavailable;
    }
  }
}
