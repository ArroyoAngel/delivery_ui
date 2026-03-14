import 'api_client.dart';

class RiderOrderStop {
  final String orderId;
  final String restaurantName;
  final String restaurantAddress;
  final double? restaurantLat;
  final double? restaurantLng;
  final String? clientAddress;
  final double? clientLat;
  final double? clientLng;
  final String status;
  final List<Map<String, dynamic>> items;
  final double total;

  RiderOrderStop({
    required this.orderId,
    required this.restaurantName,
    required this.restaurantAddress,
    this.restaurantLat,
    this.restaurantLng,
    this.clientAddress,
    this.clientLat,
    this.clientLng,
    required this.status,
    required this.items,
    required this.total,
  });

  factory RiderOrderStop.fromJson(Map<String, dynamic> j) => RiderOrderStop(
        orderId: j['id'] as String,
        restaurantName: j['restaurant_name'] as String? ?? '',
        restaurantAddress: j['restaurant_address'] as String? ?? '',
        restaurantLat: double.tryParse((j['restaurant_lat'] ?? '').toString()),
        restaurantLng: double.tryParse((j['restaurant_lng'] ?? '').toString()),
        clientAddress: j['delivery_address'] as String?,
        clientLat: double.tryParse((j['delivery_lat'] ?? '').toString()),
        clientLng: double.tryParse((j['delivery_lng'] ?? '').toString()),
        status: j['status'] as String? ?? 'en_camino',
        total: double.tryParse((j['total'] ?? '0').toString()) ?? 0.0,
        items: List<Map<String, dynamic>>.from(
          (j['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        ),
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

  Set<String> get restaurantNames => orders.map((o) => o.restaurantName).toSet();
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
}
