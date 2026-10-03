import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';

final assistantApiServiceProvider = Provider<AssistantApiService>((ref) {
  return AssistantApiService();
});

class AssistantApiService {
  AssistantApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
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
      return 'Bonjour ! Comment puis-je vous accompagner dans votre projet solaire ?';
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
          return rawData.trim();
        }
      }

      if (json != null) {
        final answer = json['content'] ??
            json['reply'] ??
            json['message'] ??
            json['text'];
        final devisMap = json['devis'] ?? json['quote'];
        if (answer != null && answer.toString().trim().isNotEmpty) {
          var text = answer.toString().trim();
          if (devisMap is Map && !text.contains('<<<DEVIS_DATA:')) {
            text += '\n\n<<<DEVIS_DATA: ${jsonEncode(devisMap)}>>>';
          }
          return text;
        } else if (devisMap is Map) {
          return '<<<DEVIS_DATA: ${jsonEncode(devisMap)}>>>';
        }
      }

      if (rawData is String && rawData.trim().isNotEmpty) {
        return rawData.trim();
      }

      return "Je n'ai pas pu traiter votre demande.";
    } on TimeoutException {
      return 'Le serveur d\'intelligence artificielle met trop de temps à répondre (timeout 15s). Veuillez réessayer.';
    } on DioException catch (dioError) {
      if (dioError.type == DioExceptionType.connectionTimeout ||
          dioError.type == DioExceptionType.receiveTimeout ||
          dioError.type == DioExceptionType.sendTimeout) {
        return 'Délai d\'attente dépassé (15s). Le conseiller IA est temporairement occupé, merci de relancer votre question.';
      }
      if (dioError.type == DioExceptionType.connectionError) {
        return 'Connexion au serveur IA impossible. Vérifiez votre accès réseau.';
      }
      return 'Une erreur de communication est survenue. Nos conseillers techniques restent joignables directement par téléphone ou WhatsApp.';
    } catch (_) {
      return 'Une erreur inattendue est survenue lors de l\'échange avec l\'assistant.';
    }
  }
}

