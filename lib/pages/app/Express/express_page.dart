import 'package:flutter/material.dart';
import '../../../services/restaurant_service.dart';
import '../../../services/order_service.dart';
import '../../../services/cart_service.dart';
import '../Home/restaurant_page.dart';

class _ProductItem {
  final MenuItem item;
  final Restaurant restaurant;
  _ProductItem({required this.item, required this.restaurant});
}

class ExpressPage extends StatefulWidget {
  const ExpressPage({super.key});

  @override
  State<ExpressPage> createState() => _ExpressPageState();
}

class _ExpressPageState extends State<ExpressPage> {
  final _restaurantService = RestaurantService();
  final _cart = CartService();
  final _searchController = TextEditingController();

  late Future<List<_ProductItem>> _future;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _future = _loadProducts();
    _cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onCartChanged() => setState(() {});

  Future<List<_ProductItem>> _loadProducts() async {
    final restaurants = await _restaurantService.getRestaurants();
    final detailed = await Future.wait(
      restaurants.map((r) => _restaurantService.getRestaurant(r.id)),
    );
    final items = <_ProductItem>[];
    for (final r in detailed) {
      for (final item in r.menu) {
        items.add(_ProductItem(item: item, restaurant: r));
      }
    }
    return items;
  }

  List<_ProductItem> _filtered(List<_ProductItem> all) {
    return all.where((p) {
      final matchCat = _selectedCategory == 'Todos' ||
          (p.item.categoryName ?? '').contains(_selectedCategory);
      final matchSearch = _searchQuery.isEmpty ||
          p.item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.item.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.restaurant.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  List<String> _categories(List<_ProductItem> all) {
    final cats = all.map((p) => p.item.categoryName ?? 'General').toSet().toList()..sort();
    return ['Todos', ...cats];
  }

  void _addToCart(_ProductItem p) {
    _cart.addItem(
      OrderItem(menuItemId: p.item.id, name: p.item.name, price: p.item.price),
      p.restaurant.id,
      p.restaurant.name,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${p.item.name} agregado al carrito'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeFromCart(String menuItemId) {
    _cart.removeItem(menuItemId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.electric_bolt,
                          color: theme.colorScheme.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Express',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Busca productos de todos los restaurantes',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Buscar productos...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: FutureBuilder<List<_ProductItem>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('Error al cargar',
                              style: TextStyle(color: Colors.grey.shade500)),
                          TextButton(
                            onPressed: () => setState(() => _future = _loadProducts()),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    );
                  }
                  final all = snap.data ?? [];
                  final cats = _categories(all);
                  final filtered = _filtered(all);

                  return Column(
                    children: [
                      // Category chips
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: cats.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final cat = cats[i];
                            final selected = _selectedCategory == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = cat),
                              selectedColor: theme.colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade700,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Multi-restaurant notice
                      if (_cart.isMultiRestaurant)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.electric_bolt,
                                  color: Colors.orange.shade700, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tienes productos de ${_cart.restaurantIds.length} restaurantes — se procesará como pedido Express',
                                  style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Product list
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off,
                                        size: 48, color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    Text('Sin resultados',
                                        style: TextStyle(
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) =>
                                    _ProductCard(
                                  product: filtered[i],
                                  quantity: _cart.quantityOf(filtered[i].item.id),
                                  onAdd: () => _addToCart(filtered[i]),
                                  onRemove: () =>
                                      _removeFromCart(filtered[i].item.id),
                                  onRestaurantTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RestaurantPage(
                                          restaurantId: filtered[i].restaurant.id),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _ProductItem product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onRestaurantTap;

  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    required this.onRestaurantTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = product.item;
    final restaurant = product.restaurant;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category indicator
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _categoryEmoji(item.categoryName),
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (item.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description!,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onRestaurantTap,
                  child: Row(
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 12, color: theme.colorScheme.primary),
                      const SizedBox(width: 3),
                      Text(
                        restaurant.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bs ${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          // Qty controls
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (quantity > 0) ...[
                _SmallButton(icon: Icons.remove, onTap: onRemove),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('$quantity',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ],
              _SmallButton(icon: Icons.add, onTap: onAdd, filled: true),
            ],
          ),
        ],
      ),
    );
  }

  String _categoryEmoji(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('pizza')) return '🍕';
    if (c.contains('hambur') || c.contains('burger')) return '🍔';
    if (c.contains('sushi')) return '🍣';
    if (c.contains('pollo') || c.contains('chicken')) return '🍗';
    if (c.contains('papa') || c.contains('frit')) return '🍟';
    if (c.contains('beb') || c.contains('drink')) return '🥤';
    if (c.contains('postre') || c.contains('waffle') || c.contains('cafe')) return '🍰';
    if (c.contains('tacos') || c.contains('mexican')) return '🌮';
    return '🍽️';
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _SmallButton({required this.icon, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? primary : Colors.transparent,
          border: filled ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon,
            size: 14, color: filled ? Colors.white : Colors.grey.shade600),
      ),
    );
  }
}
