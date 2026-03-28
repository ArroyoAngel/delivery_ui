import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_client.dart';
import 'notification_service.dart';

class AuthUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final List<String> roles;

  AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.roles,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    phone: json['phone'] as String? ?? '',
    roles: List<String>.from(json['roles'] as List? ?? []),
  );

  bool get hasPhone => phone.isNotEmpty;

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _api = ApiClient();
  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;

  Future<AuthUser> login(String email, String password) async {
    final data =
        await _api.post('/auth/login', {
              'email': email,
              'password': password,
            }, auth: false)
            as Map<String, dynamic>;
    await _api.saveToken(data['accessToken'] as String);
    // delivery_api returns only accessToken — fetch user separately
    final me = await _api.get('/auth/me') as Map<String, dynamic>;
    _currentUser = AuthUser.fromJson(me);
    NotificationService().registerAfterLogin().catchError((_) {});
    return _currentUser!;
  }

  /// Paso 1: envía OTP al email. Llama antes de mostrar el campo de código.
  Future<void> sendRegisterOtp(String email) async {
    await _api.post('/auth/register/send-otp', {'email': email}, auth: false);
  }

  /// Paso 2: verifica el código y crea la cuenta.
  Future<AuthUser> register({
    required String email,
    required String code,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final data = await _api.post('/auth/register', {
      'email': email,
      'code': code,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
    }, auth: false) as Map<String, dynamic>;
    await _api.saveToken(data['accessToken'] as String);
    final me = await _api.get('/auth/me') as Map<String, dynamic>;
    _currentUser = AuthUser.fromJson(me);
    NotificationService().registerAfterLogin().catchError((_) {});
    return _currentUser!;
  }

  Future<bool> isSignedIn() async {
    final token = await _api.getToken();
    if (token == null) return false;
    try {
      final data = await _api.get('/auth/me') as Map<String, dynamic>;
      _currentUser = AuthUser.fromJson(data);
      return true;
    } catch (_) {
      await _api.clearToken();
      return false;
    }
  }

  Future<AuthUser> googleSignIn() async {
    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    final account = await googleSignIn.signIn();
    if (account == null) throw Exception('Login con Google cancelado');
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw Exception('No se pudo obtener el token de Google');
    }
    final data =
        await _api.post('/auth/google', {'idToken': idToken}, auth: false)
            as Map<String, dynamic>;
    await _api.saveToken(data['accessToken'] as String);
    final me = await _api.get('/auth/me') as Map<String, dynamic>;
    _currentUser = AuthUser.fromJson(me);
    NotificationService().registerAfterLogin().catchError((_) {});
    return _currentUser!;
  }

  /// Envía un SMS al [phoneNumber] (formato E.164: +591XXXXXXXX).
  /// Llama a [onCodeSent] con el verificationId cuando el SMS llega.
  /// Llama a [onError] si algo falla.
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential)? onAutoVerify,
  }) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) => onAutoVerify?.call(credential),
      verificationFailed: (e) => onError(e.message ?? 'Error de verificación'),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Completa el sign-in con el código SMS recibido.
  Future<AuthUser> phoneSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await result.user!.getIdToken();
    final data = await _api.post('/auth/firebase', {'idToken': idToken!}) as Map<String, dynamic>;
    await _api.saveToken(data['accessToken'] as String);
    final me = await _api.get('/auth/me') as Map<String, dynamic>;
    _currentUser = AuthUser.fromJson(me);
    NotificationService().registerAfterLogin().catchError((_) {});
    return _currentUser!;
  }

  /// Verifica un número de teléfono para el usuario ya autenticado (editar perfil).
  /// Llama a sendPhoneOtp primero, luego este método con el código.
  Future<String> verifyAndUpdatePhone({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await result.user!.getIdToken();
    final data = await _api.patch('/auth/phone', {'idToken': idToken!}) as Map<String, dynamic>;
    // Refresh cached user so phone shows up immediately everywhere
    final me = await _api.get('/auth/me') as Map<String, dynamic>;
    _currentUser = AuthUser.fromJson(me);
    return data['phone'] as String;
  }

  /// Actualiza nombre y/o apellido del perfil.
  Future<void> updateProfile({String? firstName, String? lastName}) async {
    final body = <String, String>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (body.isEmpty) return;
    await _api.patch('/auth/profile', body);
    // Refrescar currentUser
    final me = await _api.get('/auth/me') as Map<String, dynamic>;
    _currentUser = AuthUser.fromJson(me);
  }

  /// Elimina permanentemente la cuenta del usuario autenticado y todos sus datos.
  Future<void> deleteAccount() async {
    await _api.delete('/auth/me');
    await signOut();
  }

  Future<void> signOut() async {
    await NotificationService().unregisterOnLogout().catchError((_) {});
    await _api.clearToken();
    _currentUser = null;
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
}
