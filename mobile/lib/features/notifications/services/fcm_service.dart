import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref);
});

class FcmService {
  FcmService(this._ref, [FlutterLocalNotificationsPlugin? localNotifications])
      : _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool _initialized = false;
  bool _tokenRefreshListening = false;
  bool _messageListening = false;
  bool _openedMessageListening = false;
  String? _registeredToken;

  static const String channelId = 'heliantha_notifications';
  static const String channelName = 'Notifications Heliantha';
  static const String channelDescription =
      'Notifications de suivi de commande, état de paiement et alertes de stock.';

  static const AndroidNotificationChannel androidChannel =
      AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize(GoRouter router) async {
    if (!_isSupported || _initialized) {
      return;
    }

    _initialized = true;
    await _initLocalNotifications(router);
    await _requestPermission();
    _listenTokenRefresh();
    _listenForegroundMessages();
    _listenOpenedMessages(router);
    await _handleInitialMessage(router);
  }

  Future<void> _initLocalNotifications(GoRouter router) async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && _isAllowedRoute(payload)) {
            router.go(payload);
            _ref.invalidate(notificationsProvider);
          }
        },
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
      }
    } catch (_) {
      // Local notifications initialization must remain non-blocking.
    }
  }

  Future<void> registerForCurrentUser() async {
    if (!_isSupported) {
      return;
    }

    try {
      await _requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty || token == _registeredToken) {
        return;
      }

      await _ref.read(notificationsRepositoryProvider).registerDevice(token);
      _registeredToken = token;
    } catch (_) {
      // FCM must never block the app experience.
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_isSupported) {
      return;
    }

    try {
      final token =
          _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      await _ref.read(notificationsRepositoryProvider).unregisterDevice(token);
      if (_registeredToken == token) {
        _registeredToken = null;
      }
    } catch (_) {
      // Logout must remain possible even if FCM is temporarily unavailable.
    }
  }

  Future<void> _requestPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {
      // Refusal or platform errors are non-blocking.
    }
  }

  void _listenTokenRefresh() {
    if (_tokenRefreshListening) {
      return;
    }

    _tokenRefreshListening = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (token.isEmpty || token == _registeredToken || !_hasCurrentUser()) {
        return;
      }

      try {
        await _ref.read(notificationsRepositoryProvider).registerDevice(token);
        _registeredToken = token;
      } catch (_) {
        // Token refresh will be retried by the next app/auth lifecycle event.
      }
    });
  }

  void _listenForegroundMessages() {
    if (_messageListening) {
      return;
    }

    _messageListening = true;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _ref.invalidate(notificationsProvider);

      final notification = message.notification;
      if (notification != null) {
        final title = notification.title ?? 'Heliantha';
        final body = notification.body ?? '';
        final route = _routeFromMessage(message);
        final id = message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch.remainder(100000);

        _showForegroundLocalNotification(
          id: id,
          title: title,
          body: body,
          payload: route,
        );
      }
    });
  }

  Future<void> _showForegroundLocalNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: payload,
      );
    } catch (_) {
      // Foreground notification display failure must never crash the app.
    }
  }

  void _listenOpenedMessages(GoRouter router) {
    if (_openedMessageListening) {
      return;
    }

    _openedMessageListening = true;
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openMessage(router, message);
    });
  }

  Future<void> _handleInitialMessage(GoRouter router) async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message == null) {
        return;
      }

      Future<void>.delayed(const Duration(milliseconds: 350), () {
        _openMessage(router, message);
      });
    } catch (_) {
      // Opening the app from a notification must remain safe.
    }
  }

  void _openMessage(GoRouter router, RemoteMessage message) {
    final route = _routeFromMessage(message);
    router.go(route);
    _ref.invalidate(notificationsProvider);
  }

  String _routeFromMessage(RemoteMessage message) {
    final data = message.data;
    final route = data['route']?.toString().trim();
    if (_isAllowedRoute(route)) {
      return route!;
    }

    final orderId = data['order_id']?.toString().trim();
    if (orderId != null && int.tryParse(orderId) != null) {
      return '/orders/$orderId';
    }

    final productId = data['product_id']?.toString().trim();
    if (productId != null && int.tryParse(productId) != null) {
      return '/product/$productId';
    }

    return '/notifications';
  }

  bool _isAllowedRoute(String? route) {
    if (route == null || route.isEmpty || !route.startsWith('/')) {
      return false;
    }
    if (route.startsWith('//') || route.contains('://')) {
      return false;
    }

    return route == '/notifications' ||
        route == '/orders' ||
        route.startsWith('/orders/') ||
        route.startsWith('/product/');
  }

  bool _hasCurrentUser() {
    return _ref.read(currentUserProvider).valueOrNull != null;
  }
}
