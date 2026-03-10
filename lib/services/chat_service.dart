import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  static String get _baseUrl {
    final env = dotenv.env['OWUI_BASE_URL'] ?? 'http://localhost:3000';
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return env;
    try {
      final uri = Uri.parse(env);
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        return uri.replace(host: '10.0.2.2').toString();
      }
    } catch (_) {}
    return env;
  }

  static String get _apiKey => dotenv.env['OWUI_API_KEY'] ?? '';
  static String get _model => dotenv.env['OWUI_MODEL'] ?? 'llama3.1:8b';
  static String? get _systemPrompt => dotenv.env['OWUI_SYSTEM_PROMPT'];

  static String get debugUrl => '$_baseUrl/api/chat/completions';

  Future<String> sendMessage(List<ChatMessage> history) async {
    final token = await ApiClient().getToken();

    final messages = <Map<String, String>>[];

    // Always prepend system prompt if configured
    final prompt = _systemPrompt;
    if (prompt != null && prompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': prompt});
    }

    messages.addAll(
      history.map((m) => {'role': m.role, 'content': m.content}),
    );

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_apiKey.isNotEmpty ? _apiKey : token ?? ''}',
    };

    final body = jsonEncode({
      'model': _model,
      'messages': messages,
      'stream': false,
    });

    final res = await http
        .post(
          Uri.parse('$_baseUrl/api/chat/completions'),
          headers: headers,
          body: body,
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      final message = choices.first['message'] as Map<String, dynamic>;
      return message['content'] as String? ?? '';
    }

    throw Exception('Error ${res.statusCode}: ${res.body}');
  }
}
