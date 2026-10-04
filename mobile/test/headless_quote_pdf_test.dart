import 'package:flutter_test/flutter_test.dart';
import 'package:heliantha_mobile/core/api/api_client.dart';
import 'package:heliantha_mobile/core/config/app_config.dart';
import 'package:heliantha_mobile/features/assistant/presentation/widgets/ai_chat_bottom_sheet.dart';
import 'package:heliantha_mobile/features/quote/data/quote_repository.dart';
import 'package:heliantha_mobile/shared/utils/api_url.dart';

void main() {
  group('Centralisation URL & Résolution PDF (Headless)', () {
    test('resolvePdfUrl gère null, vide et espaces', () {
      expect(AppConfig.resolvePdfUrl(null), '');
      expect(AppConfig.resolvePdfUrl(''), '');
      expect(AppConfig.resolvePdfUrl('   '), '');
      expect(resolvePdfUrl(null), '');
      expect(resolvePdfUrl(''), '');
      expect(ApiClient.resolvePdfUrl(null), '');
    });

    test('resolvePdfUrl préserve les URLs absolues HTTP et HTTPS', () {
      const httpsUrl = 'https://app.heliantha.ma/api/devis/pdf/DEV-2026-001';
      const httpUrl = 'http://example.com/document.pdf';
      expect(AppConfig.resolvePdfUrl(httpsUrl), httpsUrl);
      expect(AppConfig.resolvePdfUrl(httpUrl), httpUrl);
      expect(resolvePdfUrl(httpsUrl), httpsUrl);
    });

    test('resolvePdfUrl préfixe les URLs relatives avec https://app.heliantha.ma', () {
      expect(
        AppConfig.resolvePdfUrl('/api/devis/pdf/DEV-2026-001'),
        'https://app.heliantha.ma/api/devis/pdf/DEV-2026-001',
      );
      expect(
        AppConfig.resolvePdfUrl('/v1/devis/DEV-123/pdf'),
        'https://app.heliantha.ma/v1/devis/DEV-123/pdf',
      );
      expect(
        AppConfig.resolvePdfUrl('api/devis/pdf/DEV-2026-001'),
        'https://app.heliantha.ma/api/devis/pdf/DEV-2026-001',
      );
      expect(
        resolvePdfUrl('/simulation/456/pdf'),
        'https://app.heliantha.ma/simulation/456/pdf',
      );
    });
  });

  group('QuoteCalculationResult - Extraction Métriques & Résolution PDF', () {
    test('Extrait correctement toutes les métriques clés et le PDF URL', () {
      final json = {
        'quote_number': 'DEV-2026-999',
        'total_ttc': 45000.0,
        'power_kwc': 5.85,
        'panel_count': 10,
        'inverter': 'Growatt SPF 5000 ES',
        'battery_storage': 'Batterie Pylontech 4.8 kWh',
        'pdf_url': '/v1/devis/DEV-2026-999/pdf',
      };

      final result = QuoteCalculationResult(json);
      expect(result.quoteNumber, 'DEV-2026-999');
      expect(result.totalTtc, 45000.0);
      expect(result.powerKwc, 5.85);
      expect(result.panelCount, 10);
      expect(result.inverter, 'Growatt SPF 5000 ES');
      expect(result.batteryStorage, 'Batterie Pylontech 4.8 kWh');
      expect(result.pdfUrl, '/v1/devis/DEV-2026-999/pdf');
      expect(
        result.resolvedPdfUrl,
        'https://app.heliantha.ma/v1/devis/DEV-2026-999/pdf',
      );
    });

    test('Calcule resolvedPdfUrl par défaut avec quoteNumber si pdf_url absent', () {
      final json = {
        'id': 'DEV-AUTO-123',
        'total': '32000',
        'puissance_kwc': 3.5,
        'nb_panneaux': 6,
      };

      final result = QuoteCalculationResult(json);
      expect(result.quoteNumber, 'DEV-AUTO-123');
      expect(result.totalTtc, 32000.0);
      expect(result.powerKwc, 3.5);
      expect(result.panelCount, 6);
      expect(result.pdfUrl, isNull);
      expect(
        result.resolvedPdfUrl,
        'https://app.heliantha.ma/v1/devis/DEV-AUTO-123/pdf',
      );
    });
  });

  group('ChatDevisData (Assistant IA) - Résolution PDF Sécurisée', () {
    test('fromJson résout systématiquement pdf_url via resolvePdfUrl', () {
      final devisJson = {
        'ref': 'DEV-IA-888',
        'total_ttc': 54000,
        'kwc': 6.2,
        'panels': 12,
        'onduleur': 'Huawei SUN2000-6KTL',
        'pdf_url': '/api/devis/pdf/DEV-IA-888',
      };

      final data = ChatDevisData.fromJson(devisJson);
      expect(data.reference, 'DEV-IA-888');
      expect(data.totalTtc, 54000.0);
      expect(data.powerKwc, 6.2);
      expect(data.panelCount, 12);
      expect(data.inverter, 'Huawei SUN2000-6KTL');
      expect(
        data.pdfUrl,
        'https://app.heliantha.ma/api/devis/pdf/DEV-IA-888',
      );
    });

    test('fromJson génère et résout une URL PDF par défaut si le champ est absent', () {
      final devisJson = {
        'ref': 'DEV-IA-FALLBACK',
        'total': 25000,
      };

      final data = ChatDevisData.fromJson(devisJson);
      expect(
        data.pdfUrl,
        'https://app.heliantha.ma/api/devis/pdf/DEV-IA-FALLBACK',
      );
    });
  });
}
