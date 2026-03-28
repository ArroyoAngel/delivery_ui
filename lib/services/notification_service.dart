import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';

/// Handler de mensajes en background (top-level, fuera de cualquier clase)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase ya está inicializado al llegar aquí
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _api = ApiClient();

  String? _currentToken;

  static const _androidChannel = AndroidNotificationChannel(
    'yaya_orders',
    'Pedidos YaYa Eats',
    description: 'Notificaciones de estado de pedidos',
    importance: Importance.high,
    playSound: true,
  );

  // Canal de alta prioridad para cancelaciones y entrega
  static final _androidChannelCritical = AndroidNotificationChannel(
    'yaya_critical',
    'Alertas urgentes YaYa Eats',
    description: 'Cancelaciones y confirmaciones de entrega',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
  );

  Future<void> init() async {
    // Registrar el handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Solicitar permisos (iOS + Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configurar canales Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    await androidPlugin?.createNotificationChannel(_androidChannelCritical);

    // Inicializar flutter_local_notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    // Presentar notificaciones en foreground como banners (iOS)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Mostrar notificación local cuando la app está en foreground
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Registrar token con el backend
    await _registerToken();

    // Actualizar token si se renueva
    _fcm.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _api.post('/notifications/token', {
        'token': newToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
      }).catchError((_) {});
    });
  }

  Future<void> _registerToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      _currentToken = token;
      await _api.post('/notifications/token', {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {
      // Sin acceso a internet o usuario no autenticado aún — se reintentará en el login
    }
  }

  /// Llamar después del login para asegurarse de que el token quede registrado
  Future<void> registerAfterLogin() => _registerToken();

  /// Llamar en el logout para desregistrar el token
  Future<void> unregisterOnLogout() async {
    if (_currentToken == null) return;
    try {
      await _api.delete('/notifications/token');
    } catch (_) {}
    _currentToken = null;
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] as String?;
    final status = message.data['status'] as String?;
    final isCritical = type == 'order_cancelled' ||
        (type == 'order_status' && status == 'entregado');

    final channel = isCritical ? _androidChannelCritical : _androidChannel;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: isCritical ? Importance.max : Importance.high,
          priority: isCritical ? Priority.max : Priority.high,
          icon: '@mipmap/ic_launcher',
          vibrationPattern: isCritical
              ? Int64List.fromList([0, 500, 200, 500, 200, 500])
              : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
