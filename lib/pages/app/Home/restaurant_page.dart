import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../services/restaurant_service.dart';
import '../../../services/order_service.dart';
import '../../../services/cart_service.dart';
import '../Cart/cart_sheet.dart';

class RestaurantPage extends StatefulWidget {
  final String restaurantId;
  const RestaurantPage({super.key, required this.restaurantId});

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends State<RestaurantPage> {
  final _restaurantService = RestaurantService();
  final _cart = CartService();

  late Future<Restaurant> _future;

  @override
  void initState() {
    super.initState();
    _future = _restaurantService.getRestaurant(widget.restaurantId);
    _cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() => setState(() {});

  void _addItem(MenuItem item, String restaurantName) {
    _cart.addItem(
      OrderItem(menuItemId: item.id, name: item.name, price: item.price),
      widget.restaurantId,
      restaurantName,
    );
  }

  void _removeItem(MenuItem item) {
    _cart.removeItem(item.id);
  }

  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartCount = _cart.totalCount;

    return Scaffold(
      body: Stack(
        children: [
          FutureBuilder<Restaurant>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              return _buildContent(snap.data!);
            },
          ),

          // Floating cart button (same as AppRoot, visible here too)
          if (cartCount > 0)
            Positioned(
              right: 16,
              bottom: 24,
              child: GestureDetector(
                onTap: _openCart,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Center(
                        child: Icon(Icons.shopping_basket_outlined,
                            color: Colors.white, size: 26),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 20, minHeight: 20),
                          child: Text(
                            '$cartCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(Restaurant restaurant) {
    final Map<String, List<MenuItem>> grouped = {};
    for (final item in restaurant.menu) {
      final cat = item.categoryName ?? 'General';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              restaurant.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            background: restaurant.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: restaurant.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey.shade300),
                  )
                : Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.restaurant,
                        size: 64, color: Colors.white)),
          ),
        ),

        // Info row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (restaurant.rating != null) ...[
                  Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                  const SizedBox(width: 4),
                  Text(restaurant.rating!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                ],
                if (restaurant.deliveryMinutes != null) ...[
                  const Icon(Icons.timer_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${restaurant.deliveryMinutes} min',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(width: 16),
                ],
                if (restaurant.deliveryFee != null)
                  Text(
                    restaurant.deliveryFee == 0
                        ? 'Envío gratis'
                        : 'Envío Bs ${restaurant.deliveryFee!.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: restaurant.deliveryFee == 0
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Menu sections
        for (final entry in grouped.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                entry.key,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _MenuItemTile(
                item: entry.value[i],
                quantity: _cart.quantityOf(entry.value[i].id),
                onAdd: () => _addItem(entry.value[i], restaurant.name),
                onRemove: () => _removeItem(entry.value[i]),
              ),
              childCount: entry.value.length,
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─── Menu Item Tile ───────────────────────────────────────────────────────────

class _MenuItemTile extends StatelessWidget {
  final MenuItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _MenuItemTile({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl!,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 72,
                  height: 72,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.fastfood, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.fastfood, color: Colors.grey.shade400),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bs ${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        fontSize: 15,
                      ),
                    ),
                    Row(
                      children: [
                        if (quantity > 0) ...[
                          _CircleBtn(icon: Icons.remove, onTap: onRemove),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('$quantity',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                          ),
                        ],
                        _CircleBtn(
                            icon: Icons.add, onTap: onAdd, filled: true),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _CircleBtn(
      {required this.icon, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? primary : Colors.transparent,
          border: filled ? null : Border.all(color: Colors.grey.shade400),
        ),
        child: Icon(icon,
            size: 16,
            color: filled ? Colors.white : Colors.grey.shade600),
      ),
    );
  }
}
