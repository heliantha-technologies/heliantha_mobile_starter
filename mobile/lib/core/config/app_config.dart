import 'package:flutter/foundation.dart';

class AppConfig {
  static const supportWhatsAppNumber = '212661575128';
  static const supportWhatsAppDisplay = '+212 661 57 51 28';
  static const supportEmail = 'contact@heliantha.ma';
  static const supportPhoneNumber = '0530133583';
  static const supportPhoneDisplay = '05 30 13 35 83';

  static Uri supportWhatsAppUri({String? message}) => Uri.https(
        'wa.me',
        '/$supportWhatsAppNumber',
        message == null ? null : {'text': message},
      );

  static Uri get supportEmailUri => Uri(scheme: 'mailto', path: supportEmail);

  static Uri get supportPhoneUri =>
      Uri(scheme: 'tel', path: supportPhoneNumber);

  static const productionApiBaseUrl = 'https://app.heliantha.ma';
  static const productionAppBaseUrl = 'https://app.heliantha.ma';

  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _appBaseUrlOverride = String.fromEnvironment('APP_BASE_URL');
  static const _isRelease = bool.fromEnvironment('dart.vm.product');

  static String get apiBaseUrl {
    return _resolveBaseUrl(
      _apiBaseUrlOverride,
      defaultValue: kIsWeb ? '' : productionApiBaseUrl,
    );
  }

  static String get appBaseUrl {
    return _resolveBaseUrl(
      _appBaseUrlOverride,
      defaultValue: productionAppBaseUrl,
    );
  }

  static String productShareUrl(int productId) {
    return '${appBaseUrl.replaceAll(RegExp(r'/$'), '')}/product/$productId';
  }

  static String resolvePdfUrl(String? rawUrl) {
    if (rawUrl == null) return '';
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return 'https://app.heliantha.ma$trimmed';
    }
    return 'https://app.heliantha.ma/$trimmed';
  }

  static String _resolveBaseUrl(
    String override, {
    required String defaultValue,
  }) {
    final value = override.trim();
    if (value.isEmpty) {
      return defaultValue;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return defaultValue;
    }

    if (_isLocalHost(uri.host)) {
      return _isRelease ? defaultValue : _withoutTrailingSlash(value);
    }
    if (uri.scheme == 'http' && _isHelianthaHost(uri.host)) {
      return _withoutTrailingSlash(uri.replace(scheme: 'https').toString());
    }
    if (_isRelease && uri.scheme != 'https') {
      return defaultValue;
    }

    return _withoutTrailingSlash(value);
  }

  static String _withoutTrailingSlash(String value) {
    return value.replaceAll(RegExp(r'/$'), '');
  }

  static bool _isLocalHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host == '0.0.0.0';
  }

  static bool _isHelianthaHost(String host) {
    return host == 'api.heliantha.ma' || host == 'app.heliantha.ma';
  }
}
