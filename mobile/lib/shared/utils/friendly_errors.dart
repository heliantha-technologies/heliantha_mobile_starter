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
