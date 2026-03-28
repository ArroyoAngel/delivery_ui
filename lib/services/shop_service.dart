import 'package:flutter/foundation.dart';
import 'api_client.dart';

class ShopCategory {
  final String id;
  final String name;
  final String? icon;
  final String businessType;

  ShopCategory({
    required this.id,
    required this.name,
    this.icon,
    this.businessType = 'restaurant',
  });

  factory ShopCategory.fromJson(Map<String, dynamic> j) => ShopCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String?,
        businessType: j['business_type'] as String? ?? j['businessType'] as String? ?? 'restaurant',
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
  final int size;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.categoryName,
    required this.isAvailable,
    this.size = 1,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        price: double.tryParse((j['price'] ?? '0').toString()) ?? (j['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: j['image_url'] as String? ?? j['imageUrl'] as String?,
        categoryName: j['category_name'] as String? ?? j['categoryName'] as String?,
        isAvailable: j['is_available'] as bool? ?? j['isAvailable'] as bool? ?? true,
        size: (j['size'] as num?)?.toInt() ?? 1,
      );
}

class Shop {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? address;
  final double? rating;
  final int? deliveryMinutes;
  final double? deliveryFee;
  final bool isOpen;
  final String businessType;
  final List<MenuItem> menu;
  final String status; // 'active' | 'disabled'

  bool get isDisabled => status == 'disabled';

  Shop({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.address,
    this.rating,
    this.deliveryMinutes,
    this.deliveryFee,
    required this.isOpen,
    this.businessType = 'restaurant',
    this.menu = const [],
    this.status = 'active',
  });

  Shop copyWith({String? status}) => Shop(
        id: id,
        name: name,
        description: description,
        imageUrl: imageUrl,
        address: address,
        rating: rating,
        deliveryMinutes: deliveryMinutes,
        deliveryFee: deliveryFee,
        isOpen: isOpen,
        businessType: businessType,
        menu: menu,
        status: status ?? this.status,
      );

  factory Shop.fromJson(Map<String, dynamic> j) {
    debugPrint('[Shop.fromJson] id=${j['id']} name=${j['name']} status=${j['status']}');
    return Shop(
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
        businessType: j['business_type'] as String? ?? j['businessType'] as String? ?? 'restaurant',
        menu: _flattenMenu(j),
        status: j['status'] as String? ?? 'active',
      );
  }

  // El backend retorna menuCategories:[{name, items:[...]}] — lo aplanamos.
  static List<MenuItem> _flattenMenu(Map<String, dynamic> j) {
    final categories =
        j['menuCategories'] as List? ?? j['menu'] as List? ?? [];
    final result = <MenuItem>[];
    for (final cat in categories) {
      final catMap = cat as Map<String, dynamic>;
      final catName = catMap['name'] as String?;
      for (final item in (catMap['items'] as List? ?? [])) {
        final itemMap = Map<String, dynamic>.from(item as Map);
        itemMap['category_name'] = catName;
        result.add(MenuItem.fromJson(itemMap));
      }
    }
    return result;
  }
}

class BusinessTypeInfo {
  final String value;
  final String label;
  final int sortOrder;
  final String serviceCategory;
  final String? flutterIcon;
  final String? bgColor;
  final String? iconColor;
  final String? webIcon;

  const BusinessTypeInfo({
    required this.value,
    required this.label,
    required this.sortOrder,
    required this.serviceCategory,
    this.flutterIcon,
    this.bgColor,
    this.iconColor,
    this.webIcon,
  });

  factory BusinessTypeInfo.fromJson(Map<String, dynamic> j) => BusinessTypeInfo(
        value: j['value'] as String,
        label: j['label'] as String,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        serviceCategory: j['serviceCategory'] as String? ?? 'food',
        flutterIcon: j['flutterIcon'] as String?,
        bgColor: j['bgColor'] as String?,
        iconColor: j['iconColor'] as String?,
        webIcon: j['webIcon'] as String?,
      );
}

class ShopService {
  static final ShopService _instance = ShopService._internal();
  factory ShopService() => _instance;
  ShopService._internal();

  final _api = ApiClient();

  Future<List<Shop>> getShops({
    String? search,
    String? categoryId,
    String? businessType,
  }) async {
    final query = <String, String>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (categoryId != null) query['categoryId'] = categoryId;
    if (businessType != null) query['businessType'] = businessType;
    final data = await _api.get('/shops', query: query.isEmpty ? null : query) as List;
    return data.map((e) => Shop.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Shop> getShop(String id) async {
    final data = await _api.get('/shops/$id') as Map<String, dynamic>;
    return Shop.fromJson(data);
  }

  Future<List<ShopCategory>> getCategories({String? businessType}) async {
    final query = businessType != null ? {'businessType': businessType} : null;
    final data = await _api.get('/shops/categories', query: query) as List;
    return data.map((e) => ShopCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BusinessTypeInfo>> getBusinessTypes() async {
    final data = await _api.get('/shops/business-types') as List;
    return data.map((e) => BusinessTypeInfo.fromJson(e as Map<String, dynamic>)).toList();
  }
}
