import 'api_client.dart';

class RestaurantCategory {
  final String id;
  final String name;
  final String? icon;

  RestaurantCategory({required this.id, required this.name, this.icon});

  factory RestaurantCategory.fromJson(Map<String, dynamic> j) => RestaurantCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String?,
      );
}

class MenuItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String? categoryName;
  final bool isAvailable;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.categoryName,
    required this.isAvailable,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        price: double.tryParse((j['price'] ?? '0').toString()) ?? (j['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: j['image_url'] as String? ?? j['imageUrl'] as String?,
        categoryName: j['category_name'] as String? ?? j['categoryName'] as String?,
        isAvailable: j['is_available'] as bool? ?? j['isAvailable'] as bool? ?? true,
      );
}

class Restaurant {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? address;
  final double? rating;
  final int? deliveryMinutes;
  final double? deliveryFee;
  final bool isOpen;
  final List<MenuItem> menu;

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.address,
    this.rating,
    this.deliveryMinutes,
    this.deliveryFee,
    required this.isOpen,
    this.menu = const [],
  });

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        imageUrl: j['image_url'] as String? ?? j['imageUrl'] as String?,
        address: j['address'] as String?,
        rating: j['rating'] == null ? null : double.tryParse(j['rating'].toString()),
        deliveryMinutes: j['deliveryTimeMin'] as int? ?? j['delivery_time_min'] as int? ?? j['deliveryMinutes'] as int? ?? j['delivery_minutes'] as int?,
        deliveryFee: (j['deliveryFee'] ?? j['delivery_fee']) == null
            ? null
            : double.tryParse((j['deliveryFee'] ?? j['delivery_fee']).toString()),
        isOpen: j['is_open'] as bool? ?? j['isOpen'] as bool? ?? true,
        menu: (j['menu'] as List?)?.map((e) => MenuItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

class RestaurantService {
  static final RestaurantService _instance = RestaurantService._internal();
  factory RestaurantService() => _instance;
  RestaurantService._internal();

  final _api = ApiClient();

  Future<List<Restaurant>> getRestaurants({String? search, String? categoryId}) async {
    final query = <String, String>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (categoryId != null) query['categoryId'] = categoryId;
    final data = await _api.get('/restaurants', query: query.isEmpty ? null : query) as List;
    return data.map((e) => Restaurant.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Restaurant> getRestaurant(String id) async {
    final data = await _api.get('/restaurants/$id') as Map<String, dynamic>;
    return Restaurant.fromJson(data);
  }

  Future<List<RestaurantCategory>> getCategories() async {
    final data = await _api.get('/restaurants/categories') as List;
    return data.map((e) => RestaurantCategory.fromJson(e as Map<String, dynamic>)).toList();
  }
}
