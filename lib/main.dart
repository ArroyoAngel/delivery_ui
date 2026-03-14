import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'mapbox_config.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'pages/app/app_root.dart';
import 'pages/core/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  MapboxOptions.setAccessToken(mapboxAccessToken);
  // Firebase se inicializa en background — nunca bloquea el arranque
  Firebase.initializeApp().then((_) {
    NotificationService().init().catchError((_) {});
  }).catchError((e) {
    debugPrint('Firebase init error: $e');
  });

  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YaYa Eats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
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
          return const AppRoot();
        }

        return const OnboardingPage();
      },
    );
  }
}
