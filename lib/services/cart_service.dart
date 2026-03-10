import 'package:flutter/foundation.dart';
import 'order_service.dart';

class CartEntry {
  final OrderItem item;
  final String restaurantId;
  final String restaurantName;

  CartEntry({
    required this.item,
    required this.restaurantId,
    required this.restaurantName,
  });
}

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  // keyed by menuItemId
  final Map<String, CartEntry> _entries = {};

  List<CartEntry> get entries => _entries.values.toList();

  int get totalCount => _entries.values.fold(0, (s, e) => s + e.item.quantity);

  double get subtotal =>
      _entries.values.fold(0, (s, e) => s + e.item.price * e.item.quantity);

  /// Returns all unique restaurant IDs in the cart
  Set<String> get restaurantIds => _entries.values.map((e) => e.restaurantId).toSet();

  bool get isMultiRestaurant => restaurantIds.length > 1;

  bool get isEmpty => _entries.isEmpty;

  /// Items grouped by restaurantId
  Map<String, List<CartEntry>> get byRestaurant {
    final map = <String, List<CartEntry>>{};
    for (final e in _entries.values) {
      map.putIfAbsent(e.restaurantId, () => []).add(e);
    }
    return map;
  }

  void addItem(OrderItem item, String restaurantId, String restaurantName) {
    if (_entries.containsKey(item.menuItemId)) {
      _entries[item.menuItemId]!.item.quantity++;
    } else {
      _entries[item.menuItemId] = CartEntry(
        item: item,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      );
    }
    notifyListeners();
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

  void clearRestaurant(String restaurantId) {
    _entries.removeWhere((_, e) => e.restaurantId == restaurantId);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
