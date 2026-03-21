import 'dart:convert';
import 'api_client.dart';

class ChatMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Acción estructurada que la IA puede solicitar ejecutar.
class AiAction {
  final String type; // 'CREATE_ORDER' | 'CHECK_PAYMENT'
  final Map<String, dynamic> data;

  AiAction({required this.type, required this.data});
}

/// Resultado de enviar un mensaje: texto visible + acción opcional.
class ChatResponse {
  final String text;
  final AiAction? action;

  ChatResponse({required this.text, this.action});
}

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _api = ApiClient();

  static String get debugUrl => '${ApiClient.baseUrl}/ai/chat';

  Future<ChatResponse> sendMessage(List<ChatMessage> history) async {
    final messages = history
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final data = await _api.post(
      '/ai/chat',
      {'messages': messages, 'channel': 'app'},
    ) as Map<String, dynamic>;

    final choices = data['choices'] as List<dynamic>;
    final message = choices.first['message'] as Map<String, dynamic>;
    final raw = message['content'] as String? ?? '';

    return _parseResponse(raw);
  }

  /// Separa el texto visible de la línea __ACTION__ (si existe).
  ChatResponse _parseResponse(String raw) {
    const marker = '__ACTION__:';
    final idx = raw.lastIndexOf(marker);
    if (idx == -1) return ChatResponse(text: raw.trim());

    final text = raw.substring(0, idx).trim();
    final jsonStr = raw.substring(idx + marker.length).trim();

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final type = map['type'] as String? ?? '';
      return ChatResponse(text: text, action: AiAction(type: type, data: map));
    } catch (_) {
      // JSON malformado — mostrar el mensaje completo sin acción
      return ChatResponse(text: raw.trim());
    }
  }
}
