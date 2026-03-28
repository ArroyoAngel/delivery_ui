import 'api_client.dart';

class PendingRating {
  final String targetType; // 'shop' | 'rider' | 'client'
  final String targetId;
  final String name;

  const PendingRating({
    required this.targetType,
    required this.targetId,
    required this.name,
  });

  factory PendingRating.fromJson(Map<String, dynamic> j) => PendingRating(
        targetType: j['targetType'] as String,
        targetId: j['targetId'] as String,
        name: j['name'] as String,
      );

  IconLabel get icon {
    switch (targetType) {
      case 'shop':   return IconLabel(label: 'Restaurante');
      case 'rider':  return IconLabel(label: 'Repartidor');
      default:       return IconLabel(label: 'Cliente');
    }
  }
}

class IconLabel {
  final String label;
  const IconLabel({required this.label});
}

class RatingService {
  static final RatingService _i = RatingService._();
  factory RatingService() => _i;
  RatingService._();

  final _api = ApiClient();

  Future<List<PendingRating>> getPending(String orderId) async {
    final data = await _api.get('/ratings/pending/$orderId');
    final list = (data['pending'] as List? ?? []);
    return list.map((e) => PendingRating.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Devuelve el orderId más reciente con calificaciones pendientes, o null si no hay.
  Future<String?> getFirstPendingOrderId() async {
    final data = await _api.get('/ratings/my-pending') as List?;
    if (data == null || data.isEmpty) return null;
    return (data.first as Map<String, dynamic>)['orderId'] as String?;
  }

  Future<void> submit({
    required String orderId,
    required String targetType,
    required String targetId,
    required int score,
    String? comment,
  }) async {
    final body = <String, dynamic>{
      'orderId': orderId,
      'targetType': targetType,
      'score': score,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };
    if (targetType == 'shop') {
      body['targetShopId'] = targetId;
    } else {
      body['targetAccountId'] = targetId;
    }
    await _api.post('/ratings', body);
  }
}
