import 'package:flutter/foundation.dart';
import 'api_client.dart';

class RiderOrderStop {
  final String orderId;
  final String shopName;
  final String shopAddress;
  final double? shopLat;
  final double? shopLng;
  final String? clientAddress;
  final double? clientLat;
  final double? clientLng;
  final String status;
  final List<Map<String, dynamic>> items;
  final double total;
  final String? riderInstructions;
  final double shopRating;
  final double clientRating;
  final String? paymentMethod;
  final String? paidAt;

  RiderOrderStop({
    required this.orderId,
    required this.shopName,
    required this.shopAddress,
    this.shopLat,
    this.shopLng,
    this.clientAddress,
    this.clientLat,
    this.clientLng,
    required this.status,
    required this.items,
    required this.total,
    this.riderInstructions,
    this.shopRating = 5.0,
    this.clientRating = 5.0,
    this.paymentMethod,
    this.paidAt,
  });

  bool get hasSpecialInstructions =>
      riderInstructions != null && riderInstructions!.isNotEmpty;

  factory RiderOrderStop.fromJson(Map<String, dynamic> j) => RiderOrderStop(
        orderId: j['id'] as String,
        shopName: j['shop_name'] as String? ?? j['restaurant_name'] as String? ?? '',
        shopAddress: j['shop_address'] as String? ?? j['restaurant_address'] as String? ?? '',
        shopLat: double.tryParse((j['shop_lat'] ?? j['restaurant_lat'] ?? '').toString()),
        shopLng: double.tryParse((j['shop_lng'] ?? j['restaurant_lng'] ?? '').toString()),
        clientAddress: j['delivery_address'] as String?,
        clientLat: double.tryParse((j['delivery_lat'] ?? '').toString()),
        clientLng: double.tryParse((j['delivery_lng'] ?? '').toString()),
        status: j['status'] as String? ?? 'en_camino',
        total: double.tryParse((j['total'] ?? '0').toString()) ?? 0.0,
        items: List<Map<String, dynamic>>.from(
          (j['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        ),
        riderInstructions: j['rider_instructions'] as String? ??
            j['riderInstructions'] as String?,
        shopRating: double.tryParse((j['shop_rating'] ?? '').toString()) ?? 5.0,
        clientRating: double.tryParse((j['client_rating'] ?? '').toString()) ?? 5.0,
        paymentMethod: j['payment_method'] as String? ?? j['paymentMethod'] as String? ?? 'qr',
        paidAt: j['paid_at'] as String? ?? j['paidAt'] as String?,
      );
}

class RiderGroup {
  final String id;
  final String status;
  final String? riderId;
  final List<RiderOrderStop> orders;
  final DateTime createdAt;

  RiderGroup({
    required this.id,
    required this.status,
    this.riderId,
    required this.orders,
    required this.createdAt,
  });

  factory RiderGroup.fromJson(Map<String, dynamic> j) => RiderGroup(
        id: j['id'] as String,
        status: j['status'] as String? ?? 'available',
        riderId: j['riderId'] as String? ?? j['rider_id'] as String?,
        orders: (j['orders'] as List? ?? [])
            .map((e) => RiderOrderStop.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(
              j['createdAt'] as String? ?? j['created_at'] as String? ?? '',
            ) ??
            DateTime.now(),
      );

  int get orderCount => orders.length;

  Set<String> get shopNames => orders.map((o) => o.shopName).toSet();
}

class RiderService {
  static final RiderService _instance = RiderService._internal();
  factory RiderService() => _instance;
  RiderService._internal();

  final _api = ApiClient();

  Future<List<RiderGroup>> getAvailableGroups() async {
    final data = await _api.get('/rider/groups/available') as List;
    return data.map((e) => RiderGroup.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RiderGroup?> getMyActiveGroup() async {
    final data = await _api.get('/rider/groups/my-active');
    if (data == null) return null;
    return RiderGroup.fromJson(data as Map<String, dynamic>);
  }

  Future<RiderGroup> acceptGroup(String groupId) async {
    final data = await _api.post('/rider/groups/$groupId/accept', {}) as Map<String, dynamic>;
    return RiderGroup.fromJson(data);
  }

  Future<void> markOrderPickedUp(String orderId) async {
    await _api.put('/orders/$orderId/on-the-way', {});
  }

  Future<void> markOrderDelivered(String orderId) async {
    await _api.put('/orders/$orderId/done', {});
  }

  Future<Map<String, dynamic>> getTodayStats() async {
    final data = await _api.get('/rider/stats/today') as Map<String, dynamic>;
    debugPrint('[getTodayStats] raw: $data');
    return {
      'deliveries_today': int.tryParse(data['deliveries_today']?.toString() ?? '0') ?? 0,
      'earnings_today':   double.tryParse(data['earnings_today']?.toString() ?? '0') ?? 0.0,
      'credits':          double.tryParse(data['credits']?.toString() ?? '0') ?? 0.0,
    };
  }

  Future<void> setAvailable(bool available) async {
    await _api.patch('/rider/available', {'available': available});
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    await _api.post('/orders/$orderId/rider-cancel', {'reason': reason});
  }
}
