import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/api/api_client.dart';

class QuoteRepository {
  QuoteRepository(this._api);

  final ApiClient _api;

  Future<QuoteCalculationResult> calculate(QuoteRequestPayload payload) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/v1/devis/calculer',
        data: payload.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw const QuoteApiException('Réponse vide du moteur de devis.');
      }
      return QuoteCalculationResult(data);
    } on DioException catch (error) {
      throw QuoteApiException(_readDioError(error));
    }
  }

  Future<String?> downloadAndOpenPdf(String quoteIdentifier) async {
    try {
      final safeIdentifier = Uri.encodeComponent(quoteIdentifier.trim());
      final response = await _api.dio.get<Object>(
        '/v1/devis/$safeIdentifier/pdf',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf'},
        ),
      );
      final bytes = _extractBytes(response.data);
      if (bytes.isEmpty) {
        throw const QuoteApiException('Le PDF reçu est vide.');
      }

      final fileName =
          'Devis_HeliAntha_${_safeFilePart(quoteIdentifier.trim())}';
      final savedPath = kIsWeb
          ? await FileSaver.instance.saveFile(
              name: fileName,
              bytes: bytes,
              fileExtension: 'pdf',
              mimeType: MimeType.pdf,
            )
          : await FileSaver.instance.saveAs(
              name: fileName,
              bytes: bytes,
              fileExtension: 'pdf',
              mimeType: MimeType.pdf,
            );

      if (!kIsWeb && savedPath != null && savedPath.isNotEmpty) {
        final result = await OpenFilex.open(savedPath);
        if (result.type != ResultType.done) {
          throw QuoteApiException(
            result.message.isEmpty
                ? 'PDF enregistré, mais impossible de l’ouvrir automatiquement.'
                : result.message,
          );
        }
      }

      return savedPath;
    } on DioException catch (error) {
      throw QuoteApiException(_readDioError(error));
    }
  }

  static Uint8List _extractBytes(Object? data) {
    if (data is Uint8List) {
      return data;
    }
    if (data is List<int>) {
      return Uint8List.fromList(data);
    }
    return Uint8List(0);
  }

  static String _readDioError(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'];
      if (detail is Map<String, dynamic>) {
        final nestedError = detail['error'] ?? detail['message'];
        if (nestedError != null) {
          return nestedError.toString();
        }
      }
      if (detail != null) {
        return detail.toString();
      }
      final message = responseData['message'] ?? responseData['error'];
      if (message != null) {
        return message.toString();
      }
    }
    if (responseData is String && responseData.trim().isNotEmpty) {
      return responseData.trim();
    }
    return error.message ?? 'Impossible de joindre le moteur de devis.';
  }

  static String _safeFilePart(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'devis' : cleaned;
  }
}

class QuoteRequestPayload {
  const QuoteRequestPayload({
    required this.projectType,
    required this.data,
    required this.contact,
  });

  final String projectType;
  final Map<String, dynamic> data;
  final QuoteContact contact;

  Map<String, dynamic> toJson() {
    return {
      'project_type': projectType,
      'data': data,
      'contact': contact.toJson(),
    };
  }
}

class QuoteContact {
  const QuoteContact({
    required this.name,
    required this.phone,
    required this.city,
  });

  final String name;
  final String phone;
  final String city;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'city': city,
    };
  }
}

class QuoteCalculationResult {
  const QuoteCalculationResult(this.raw);

  final Map<String, dynamic> raw;

  String? get quoteNumber => _stringValue([
        'quote_number',
        'quoteNumber',
        'quote_reference',
        'devis_reference',
        'reference',
        'numero_devis',
        'id',
      ]);

  double? get totalTtc => _numberValue([
        'total_ttc',
        'totalTTC',
        'amount_total_ttc',
        'montant_total_ttc',
        'prix_total_ttc',
        'grand_total',
        'total_price',
        'total',
      ]);

  double? get powerKwc => _numberValue([
        'power_kwc',
        'puissance_kwc',
        'pv_power_kwc',
        'system_power_kwc',
        'installed_power_kwc',
        'puissance_pv_kwc',
      ]);

  int? get panelCount {
    final value = _numberValue([
      'panels_count',
      'panel_count',
      'number_of_panels',
      'nb_panneaux',
      'nombre_panneaux',
      'modules_count',
    ]);
    return value?.round();
  }

  String? get inverter => _stringValue([
        'inverter',
        'selected_inverter',
        'inverter_model',
        'onduleur',
        'variateur',
        'controller',
        'drive_model',
      ]);

  String? get batteryStorage => _stringValue([
        'battery_storage',
        'battery_capacity',
        'battery_capacity_kwh',
        'stockage_batterie',
        'storage_kwh',
        'batteries',
        'battery',
      ]);

  Object? _lookup(Iterable<String> keys) {
    final targets = keys.map(_normalizeKey).toSet();
    final queue = <Object?>[raw];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (current is Map) {
        for (final entry in current.entries) {
          if (targets.contains(_normalizeKey(entry.key.toString()))) {
            return entry.value;
          }
        }
        queue.addAll(current.values);
      } else if (current is Iterable) {
        queue.addAll(current);
      }
    }
    return null;
  }

  String? _stringValue(List<String> keys) {
    final value = _lookup(keys);
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  double? _numberValue(List<String> keys) {
    final value = _lookup(keys);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalized = value.replaceAll(' ', '').replaceAll(',', '.');
      final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(normalized);
      return match == null ? null : double.tryParse(match.group(0)!);
    }
    return null;
  }

  static String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}

class QuoteApiException implements Exception {
  const QuoteApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
