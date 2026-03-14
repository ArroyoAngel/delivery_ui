import 'api_client.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? type;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        title: j['title'],
        body: j['body'],
        type: j['type'],
        isRead: j['isRead'] ?? false,
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class NotificationApiService {
  static final NotificationApiService _instance = NotificationApiService._internal();
  factory NotificationApiService() => _instance;
  NotificationApiService._internal();

  final _api = ApiClient();

  Future<List<AppNotification>> getNotifications() async {
    final res = await _api.get('/notifications?limit=30');
    return (res as List).map((j) => AppNotification.fromJson(j)).toList();
  }

  Future<int> getUnreadCount() async {
    final res = await _api.get('/notifications/unread-count');
    return (res['count'] as num).toInt();
  }

  Future<void> markRead(String id) => _api.patch('/notifications/$id/read');

  Future<void> markAllRead() => _api.patch('/notifications/read-all');
}
