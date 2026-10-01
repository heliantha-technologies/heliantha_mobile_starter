import '../../core/config/app_config.dart';

String absoluteApiUrl(String? path) {
  if (path == null || path.isEmpty) {
    return '';
  }
  final value = path.trim();
  if (value.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    return _normalizeAbsoluteUrl(uri, value);
  }

  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
  final normalized = value.startsWith('/') ? value : '/$value';
  return '$base$normalized';
}

String _normalizeAbsoluteUrl(Uri uri, String original) {
  if (_isLocalHost(uri.host)) {
    return _rebaseOnConfiguredApi(uri);
  }
  if (uri.scheme == 'http' && _isHelianthaHost(uri.host)) {
    return uri.replace(scheme: 'https').toString();
  }
  return original;
}

String _rebaseOnConfiguredApi(Uri uri) {
  final configured = Uri.parse(AppConfig.apiBaseUrl);
  return configured
      .replace(
        path: uri.path,
        query: uri.hasQuery ? uri.query : null,
        fragment: uri.hasFragment ? uri.fragment : null,
      )
      .toString();
}

bool _isLocalHost(String host) {
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '10.0.2.2' ||
      host == '0.0.0.0';
}

bool _isHelianthaHost(String host) {
  return host == 'api.heliantha.ma' || host == 'app.heliantha.ma';
}
