import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static String get baseUrl {
    final envBaseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3002/api';
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return envBaseUrl;
    }
    try {
      final uri = Uri.parse(envBaseUrl);
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        return uri.replace(host: '10.0.2.2').toString();
      }
    } catch (_) {}
    return envBaseUrl;
  }

  static const _tokenKey = 'yd_jwt_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {bool auth = true, Map<String, String>? query}) async {
    Uri uri = Uri.parse('$baseUrl$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers(auth: auth));
    return _handle(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true, Map<String, String>? extraHeaders}) async {
    final headers = await _headers(auth: auth);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    final raw = res.body.trim();
    // 204 No Content u otras respuestas sin cuerpo
    if (raw.isEmpty) {
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      throw ApiException('Error ${res.statusCode}', res.statusCode);
    }
    final body = jsonDecode(raw);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final message = body['message'] ?? 'Error desconocido';
    throw ApiException(
      message is List ? message.join(', ') : message.toString(),
      res.statusCode,
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
