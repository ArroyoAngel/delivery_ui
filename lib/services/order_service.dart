import 'api_client.dart';

class ExpressRestaurantOrder {
  final String restaurantId;
  final List<OrderItem> items;
  final String? notes;

  ExpressRestaurantOrder({
    required this.restaurantId,
    required this.items,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'restaurantId': restaurantId,
    'items': items.map((e) => e.toJson()).toList(),
    if (notes != null) 'notes': notes,
  };
}

class ExpressCheckoutResult {
  final String groupId;
  final double total;
  final String? paymentReference;

  ExpressCheckoutResult({
    required this.groupId,
    required this.total,
    this.paymentReference,
  });

  factory ExpressCheckoutResult.fromJson(Map<String, dynamic> j) =>
      ExpressCheckoutResult(
        groupId: j['groupId'] as String,
        total: double.tryParse((j['total'] ?? '0').toString()) ?? 0.0,
        paymentReference:
            j['paymentReference'] as String? ??
            j['payment_reference'] as String?,
      );
}

class OrderItem {
  final String menuItemId;
  final String name;
  final double price;
  int quantity;

  OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    'menuItemId': menuItemId,
    'quantity': quantity,
  };
}

class DeliveryOrderItem {
  final String name;
  final int quantity;
  final double unitPrice;

  DeliveryOrderItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => unitPrice * quantity;

  factory DeliveryOrderItem.fromJson(Map<String, dynamic> j) =>
      DeliveryOrderItem(
        name: (j['item_name'] ?? j['name'] ?? 'Producto').toString(),
        quantity: int.tryParse((j['quantity'] ?? '1').toString()) ?? 1,
        unitPrice:
            double.tryParse(
              (j['unit_price'] ?? j['unitPrice'] ?? '0').toString(),
            ) ??
            0.0,
      );
}

class DeliveryOrder {
  final String id;
  final String restaurantId;
  final String? restaurantName;
  final String status;
  final String deliveryType;
  final String? deliveryAddress;
  final double total;
  final double deliveryFee;
  final double platformFee;
  final String? notes;
  final DateTime createdAt;
  final List<DeliveryOrderItem> items;
  final String? paymentReference;

  DeliveryOrder({
    required this.id,
    required this.restaurantId,
    this.restaurantName,
    required this.status,
    required this.deliveryType,
    this.deliveryAddress,
    required this.total,
    required this.deliveryFee,
    this.platformFee = 0,
    this.notes,
    required this.createdAt,
    this.items = const [],
    this.paymentReference,
  });

  static List<DeliveryOrderItem> _parseItems(dynamic rawItems) {
    if (rawItems is! List) return const [];

    return rawItems
        .whereType<Map>()
        .map((e) => DeliveryOrderItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  factory DeliveryOrder.fromJson(Map<String, dynamic> j) => DeliveryOrder(
    id: j['id'] as String,
    restaurantId:
        j['restaurantId'] as String? ?? j['restaurant_id'] as String? ?? '',
    restaurantName:
        j['restaurantName'] as String? ?? j['restaurant_name'] as String?,
    status: j['status'] as String? ?? 'pendiente',
    deliveryType:
        j['deliveryType'] as String? ??
        j['delivery_type'] as String? ??
        'delivery',
    deliveryAddress:
        j['deliveryAddress'] as String? ?? j['delivery_address'] as String?,
    total: double.tryParse((j['total'] ?? '0').toString()) ?? 0.0,
    deliveryFee:
        double.tryParse(
          (j['deliveryFee'] ?? j['delivery_fee'] ?? '0').toString(),
        ) ??
        0.0,
    platformFee:
        double.tryParse(
          (j['platformFee'] ?? j['platform_fee'] ?? '0').toString(),
        ) ??
        0.0,
    notes: j['notes'] as String?,
    createdAt:
        DateTime.tryParse(
          j['createdAt'] as String? ?? j['created_at'] as String? ?? '',
        ) ??
        DateTime.now(),
    items: _parseItems(j['items']),
    paymentReference:
        j['paymentReference'] as String? ?? j['payment_reference'] as String?,
  );
}

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final _api = ApiClient();

  Future<List<DeliveryOrder>> getOrders() async {
    final data = await _api.get('/orders') as List;
    return data
        .map((e) => DeliveryOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DeliveryOrder> getOrder(String id) async {
    final data = await _api.get('/orders/$id') as Map<String, dynamic>;
    print("getOrder data: $data");
    return DeliveryOrder.fromJson(data);
  }

  Future<DeliveryOrder> createOrder({
    required String restaurantId,
    required List<OrderItem> items,
    String deliveryType = 'delivery',
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'restaurantId': restaurantId,
      'items': items.map((e) => e.toJson()).toList(),
      'deliveryType': deliveryType,
    };
    if (deliveryAddress != null) body['deliveryAddress'] = deliveryAddress;
    if (deliveryLat != null) body['deliveryLat'] = deliveryLat;
    if (deliveryLng != null) body['deliveryLng'] = deliveryLng;
    if (notes != null) body['notes'] = notes;
    final data = await _api.post('/orders', body) as Map<String, dynamic>;
    return DeliveryOrder.fromJson(data);
  }

  Future<ExpressCheckoutResult> expressCheckout({
    required List<ExpressRestaurantOrder> restaurants,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final body = <String, dynamic>{
      'orders': restaurants.map((r) => r.toJson()).toList(),
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      if (deliveryLat != null) 'deliveryLat': deliveryLat,
      if (deliveryLng != null) 'deliveryLng': deliveryLng,
    };
    final data =
        await _api.post('/orders/express-checkout', body)
            as Map<String, dynamic>;
    return ExpressCheckoutResult.fromJson(data);
  }

  Future<void> cancelOrder(String id) async {
    await _api.post('/orders/$id/cancel', {});
  }

  Future<String> checkPaymentStatus(String id) async {
    final data = await _api.get('/orders/$id') as Map<String, dynamic>;
    return data['status'] as String? ?? 'pendiente';
  }

  Future<String> checkGroupPaymentStatus(String groupId) async {
    // Considera el grupo "confirmado" si al menos una de sus órdenes está confirmada
    final data = await _api.get('/orders') as List;
    final groupOrders = data
        .map((e) => e as Map<String, dynamic>)
        .where((o) => o['groupId'] == groupId || o['group_id'] == groupId)
        .toList();
    if (groupOrders.isEmpty) return 'pendiente';
    final allConfirmed = groupOrders.every((o) {
      final s = o['status'] as String? ?? 'pendiente';
      return [
        'confirmado',
        'preparando',
        'listo',
        'en_camino',
        'entregado',
      ].contains(s);
    });
    return allConfirmed ? 'confirmado' : 'pendiente';
  }
}
