import 'dart:convert';

import 'package:dio/dio.dart';

class FriendlyError {
  const FriendlyError({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

FriendlyError friendlyLoadError(Object? error) {
  if (error is DioException && _isConnectionFailure(error)) {
    return const FriendlyError(
      title: 'Connexion indisponible',
      message: 'Vérifiez votre connexion Internet puis réessayez.',
    );
  }

  return const FriendlyError(
    title: 'Service momentanément indisponible',
    message: 'Nous n’avons pas pu charger ces informations pour le moment.',
  );
}

String friendlyLoginMessage() {
  return 'Vérifiez votre adresse e-mail et votre mot de passe.';
}

String friendlyRegisterMessage(Object? error) {
  if (error is DioException && error.response?.statusCode == 409) {
    return 'Un compte existe déjà avec cette adresse e-mail.';
  }
  if (error is DioException && error.response?.statusCode == 422) {
    return 'Certaines informations semblent incorrectes. Vérifiez les champs indiqués.';
  }
  return 'La création du compte est momentanément indisponible. Veuillez réessayer.';
}

String friendlyAddressSaveMessage(Object? error) {
  if (error is DioException && error.response?.statusCode == 422) {
    return 'Certaines informations semblent incorrectes. Vérifiez les champs indiqués.';
  }
  return 'Nous n’avons pas pu enregistrer cette adresse pour le moment.';
}

String friendlyCheckoutMessage(Object? error) {
  if (error is DioException && error.response?.statusCode == 422) {
    return 'Certaines informations semblent incorrectes. Vérifiez les champs indiqués.';
  }
  return 'Nous n’avons pas pu finaliser votre commande pour le moment. Veuillez réessayer.';
}

final _technicalErrorPattern = RegExp(
  r'\b(?:[a-z_$]*exception|traceback|'
  r'stack\s*trace|null\s*pointer|connection\s*refused|'
  r'internal\s*server\s*error|bad\s*gateway|500|502)\b|'
  r'\.(?:dart|py)\b|'
  r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d{1,5})?\b|'
  r'<!doctype\b|</?[a-z][^>]*>',
  caseSensitive: false,
);

/// Returns whether a message contains infrastructure details unsuitable for UI.
bool containsTechnicalLeak(String? text) {
  if (text == null || text.trim().isEmpty) {
    return false;
  }
  if (_technicalErrorPattern.hasMatch(text)) {
    return true;
  }

  final trimmed = text.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map || decoded is List;
    } on FormatException {
      // Ordinary text may begin with punctuation without being a JSON dump.
    }
  }
  return false;
}

String friendlyQuoteErrorMessage(Object? error) {
  if (error is DioException) {
    if (error.response?.statusCode == 422) {
      return 'Certaines informations de votre projet solaire semblent incorrectes. '
          'Vérifiez les champs indiqués puis relancez votre devis.';
    }
    if ((error.response?.statusCode ?? 0) >= 500) {
      return 'Notre outil de dimensionnement solaire est momentanément indisponible. '
          'Veuillez réessayer dans quelques instants ou contacter notre équipe.';
    }
    if (_isConnectionFailure(error)) {
      return 'Votre connexion Internet semble ralentie ou indisponible. '
          'Vérifiez-la puis relancez votre devis solaire.';
    }
    if (error.type == DioExceptionType.cancel) {
      return 'La préparation de votre devis solaire a été interrompue. '
          'Vous pouvez la relancer quand vous le souhaitez.';
    }
  }
  if (error is String &&
      error.trim().isNotEmpty &&
      !containsTechnicalLeak(error)) {
    return error.trim();
  }
  return 'Notre simulateur solaire ne peut pas préparer votre devis pour le moment. '
      'Veuillez réessayer dans quelques instants ou contacter notre équipe.';
}

String friendlyPdfErrorMessage([Object? error]) {
  return 'Le PDF de votre devis est momentanément indisponible. '
      'Contactez notre équipe par WhatsApp ou email : '
      'nous vous aiderons à obtenir votre devis solaire.';
}

bool _isConnectionFailure(DioException error) {
  if (error.response != null) {
    return false;
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    case DioExceptionType.unknown:
      return _isSocketLikeError(error.error);
    default:
      return false;
  }
}

bool _isSocketLikeError(Object? error) {
  final type = error.runtimeType.toString();
  return type == 'SocketException' ||
      type == '_ClientSocketException' ||
      type == 'HandshakeException';
}
