import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';

class AuthUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> roles;

  AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    roles: List<String>.from(json['roles'] as List? ?? []),
  );

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
    return _currentUser!;
  }

  Future<AuthUser> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final data =
        await _api.post('/auth/register', {
              'email': email,
              'password': password,
              'firstName': firstName,
              'lastName': lastName,
            }, auth: false)
            as Map<String, dynamic>;
    await _api.saveToken(data['accessToken'] as String);
    final me = await _api.get('/auth/me') as Map<String, dynamic>;
    _currentUser = AuthUser.fromJson(me);
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
    if (idToken == null)
      throw Exception('No se pudo obtener el token de Google');
    final data =
        await _api.post('/auth/google', {'idToken': idToken}, auth: false)
            as Map<String, dynamic>;
    await _api.saveToken(data['accessToken'] as String);
    final me = await _api.get('/auth/me') as Map<String, dynamic>;
    _currentUser = AuthUser.fromJson(me);
    return _currentUser!;
  }

  Future<void> signOut() async {
    await _api.clearToken();
    _currentUser = null;
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
}
