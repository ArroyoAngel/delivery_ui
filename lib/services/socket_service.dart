import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Singleton WebSocket client.
/// Connects to the backend socket.io server derived from API_BASE_URL.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;

  static String get _socketUrl {
    final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3002/api';
    // Strip /api suffix to get the socket.io root
    var url = apiUrl.endsWith('/api') ? apiUrl.substring(0, apiUrl.length - 4) : apiUrl;
    // Android emulator: localhost → 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final uri = Uri.parse(url);
        if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
          url = uri.replace(host: '10.0.2.2').toString();
        }
      } catch (_) {}
    }
    return url;
  }

  void connect({String? token}) {
    if (_socket != null && _socket!.connected) return;

    final opts = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect();
    if (token != null) {
      opts.setExtraHeaders({'Authorization': 'Bearer $token'});
    }

    _socket = io.io(_socketUrl, opts.build());
    _socket!.connect();
  }

  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  bool get isConnected => _socket?.connected ?? false;
}
