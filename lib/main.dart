import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'mapbox_config.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/notification_service.dart';
import 'services/socket_service.dart';
import 'theme/app_colors.dart';
import 'pages/app/app_root.dart';
import 'pages/core/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En release siempre se usa .env (producción). .env.local solo en debug/profile.
  if (kDebugMode || kProfileMode) {
    try {
      await dotenv.load(fileName: '.env.local');
    } catch (_) {
      await dotenv.load(fileName: '.env');
    }
  } else {
    await dotenv.load(fileName: '.env');
  }
  MapboxOptions.setAccessToken(mapboxAccessToken);
  // Firebase se inicializa en background — nunca bloquea el arranque
  Firebase.initializeApp().then((_) {
    NotificationService().init().catchError((_) {});
  }).catchError((e) {
    debugPrint('Firebase init error: $e');
  });

  // Cargar límite de bolsa desde config del servidor
  ApiClient().get('/config/max_bag_size').then((value) {
    final size = int.tryParse(value?.toString() ?? '');
    if (size != null && size > 0) CartService().setMaxBagSize(size);
  }).catchError((_) {});

  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YaYa Eats',
      debugShowCheckedModeBanner: false,
      theme: AppColors.clientTheme,
      home: const SessionGatePage(),
    );
  }
}

class SessionGatePage extends StatefulWidget {
  const SessionGatePage({super.key});

  @override
  State<SessionGatePage> createState() => _SessionGatePageState();
}

class _SessionGatePageState extends State<SessionGatePage> {
  final _authService = AuthService();
  late final Future<bool> _isSignedInFuture;

  @override
  void initState() {
    super.initState();
    _isSignedInFuture = _authService.isSignedIn();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (kDebugMode || kProfileMode) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.startFlexibleUpdate();
        InAppUpdate.completeFlexibleUpdate();
      }
    } catch (_) {
      // No interrumpir el flujo si falla la verificación
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isSignedInFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          // Conectar socket con el token del usuario autenticado
          ApiClient().getToken().then((token) {
            SocketService().connect(token: token);
          });
          return const AppRoot();
        }

        return const OnboardingPage();
      },
    );
  }
}
