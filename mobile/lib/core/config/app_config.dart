class AppConfig {
  static const productionApiBaseUrl = 'https://api.heliantha.ma';
  static const productionAppBaseUrl = 'https://app.heliantha.ma';

  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _appBaseUrlOverride = String.fromEnvironment('APP_BASE_URL');
  static const _isRelease = bool.fromEnvironment('dart.vm.product');

  static String get apiBaseUrl {
    return _resolveBaseUrl(
      _apiBaseUrlOverride,
      defaultValue: productionApiBaseUrl,
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
