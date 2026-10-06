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

      final rawData = response.data;
      Map<String, dynamic>? json;

      if (rawData is Map<String, dynamic>) {
        json = rawData;
      } else if (rawData is String && rawData.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawData);
          if (decoded is Map<String, dynamic>) {
            json = decoded;
          }
        } catch (_) {
          return AssistantReply(text: rawData.trim());
        }
      }

      if (json != null) {
        final products =
            AssistantReply.parseProducts(json['suggested_products']);
        final answer =
            json['content'] ?? json['reply'] ?? json['message'] ?? json['text'];
        final devisMap = json['devis'] ?? json['quote'];
        if (answer != null && answer.toString().trim().isNotEmpty) {
          var text = answer.toString().trim();
          if (devisMap is Map && !text.contains('<<<DEVIS_DATA:')) {
            text += '\n\n<<<DEVIS_DATA: ${jsonEncode(devisMap)}>>>';
          }
          return AssistantReply(text: text, suggestedProducts: products);
        } else if (devisMap is Map) {
          return AssistantReply(
            text: '<<<DEVIS_DATA: ${jsonEncode(devisMap)}>>>',
            suggestedProducts: products,
          );
        } else if (products.isNotEmpty) {
          return AssistantReply(
            text: 'Voici les produits proposés pour votre demande :',
            suggestedProducts: products,
          );
        }
      }

      if (json == null && rawData is String && rawData.trim().isNotEmpty) {
        return AssistantReply(text: rawData.trim());
      }

      return const AssistantReply(
          text: "Je n'ai pas pu traiter votre demande.");
    } on TimeoutException {
      return const AssistantReply(
          text:
              'Votre conseiller HeliAntha prend un instant de plus pour affiner son analyse. N’hésitez pas à relancer votre question, nous sommes à votre entière disposition.');
    } on DioException catch (dioError) {
      if (dioError.response?.statusCode == 429) {
        return const AssistantReply(
            text:
                'Vous avez beaucoup échangé avec notre conseiller solaire. Merci de patienter quelques instants avant de poursuivre votre conversation.');
      }
      if (dioError.type == DioExceptionType.connectionTimeout ||
          dioError.type == DioExceptionType.receiveTimeout ||
          dioError.type == DioExceptionType.sendTimeout) {
        return const AssistantReply(
            text:
                'Votre conseiller HeliAntha finalise votre étude personnalisée. Merci de renouveler votre question si elle ne s’affiche pas immédiatement.');
      }
      if (dioError.type == DioExceptionType.connectionError) {
        return const AssistantReply(
            text:
                'Votre connexion réseau semble interrompue. Vérifiez votre accès Internet pour échanger avec notre conseiller.');
      }
      return const AssistantReply(
          text:
              'Nos échanges sont momentanément interrompus. Nos conseillers solaires restent immédiatement à votre écoute par téléphone ou sur WhatsApp.');
    } catch (_) {
      return const AssistantReply(
          text:
              'Un contretemps est survenu lors de l’échange. Nos conseillers solaires se tiennent à votre disposition par WhatsApp ou téléphone pour vous répondre.');
    }
  }
}
