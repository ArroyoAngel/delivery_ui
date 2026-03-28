import 'package:flutter/foundation.dart';
import 'order_service.dart';

class CartEntry {
  final OrderItem item;
  final String shopId;
  final String shopName;

  CartEntry({
    required this.item,
    required this.shopId,
    required this.shopName,
  });
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  // keyed by menuItemId
  final Map<String, CartEntry> _entries = {};

  List<CartEntry> get entries => _entries.values.toList();

  int _maxBagSize = 10;
  int get maxBagSize => _maxBagSize;
  void setMaxBagSize(int size) { _maxBagSize = size; notifyListeners(); }

  int get totalCount => _entries.values.fold(0, (s, e) => s + e.item.quantity);

  /// Sum of (item.size × quantity) across all cart items
  int get totalSize => _entries.values.fold(0, (s, e) => s + e.item.size * e.item.quantity);

  bool get isBagFull => totalSize >= _maxBagSize;

  double get subtotal =>
      _entries.values.fold(0, (s, e) => s + e.item.price * e.item.quantity);

  /// Returns all unique shop IDs in the cart
  Set<String> get shopIds => _entries.values.map((e) => e.shopId).toSet();

  bool get isMultiShop => shopIds.length > 1;

  bool get isEmpty => _entries.isEmpty;

  /// Items grouped by shopId
  Map<String, List<CartEntry>> get byShop {
    final map = <String, List<CartEntry>>{};
    for (final e in _entries.values) {
      map.putIfAbsent(e.shopId, () => []).add(e);
    }
    return map;
  }

  /// Returns false if adding the item would exceed the bag size limit.
  bool addItem(OrderItem item, String shopId, String shopName) {
    if (totalSize + item.size > _maxBagSize) return false;
    if (_entries.containsKey(item.menuItemId)) {
      _entries[item.menuItemId]!.item.quantity++;
    } else {
      _entries[item.menuItemId] = CartEntry(
        item: item,
        shopId: shopId,
        shopName: shopName,
      );
    }
    notifyListeners();
    return true;
  }

  void removeItem(String menuItemId) {
    if (_entries.containsKey(menuItemId)) {
      if (_entries[menuItemId]!.item.quantity > 1) {
        _entries[menuItemId]!.item.quantity--;
      } else {
        _entries.remove(menuItemId);
      }
      notifyListeners();
    }
  }

  int quantityOf(String menuItemId) => _entries[menuItemId]?.item.quantity ?? 0;

  void clearShop(String shopId) {
    _entries.removeWhere((_, e) => e.shopId == shopId);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
