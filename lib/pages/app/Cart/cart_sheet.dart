import 'package:flutter/material.dart';
import '../../../services/cart_service.dart';
import '../../../services/order_service.dart';
import '../../../services/restaurant_service.dart';
import '../Orders/payment_page.dart';

class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final _cart = CartService();
  final _orderService = OrderService();
  final _restaurantService = RestaurantService();

  bool _isOrdering = false;
  String _deliveryType = 'delivery';
  double? _restaurantDeliveryFee;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    if (!_cart.isMultiRestaurant && _cart.restaurantIds.isNotEmpty) {
      _loadDeliveryFee();
    }
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDeliveryFee() async {
    try {
      final r = await _restaurantService.getRestaurant(_cart.restaurantIds.first);
      if (mounted) setState(() => _restaurantDeliveryFee = r.deliveryFee ?? 0);
    } catch (_) {}
  }

  double get _subtotal => _cart.subtotal;

  double get _deliveryFee {
    final base = _restaurantDeliveryFee ?? 0;
    if (_deliveryType == 'express') return base * 2;
    if (_deliveryType == 'delivery') return base;
    return 0;
  }

  double get _total => _subtotal + _deliveryFee;

  Future<void> _checkout() async {
    setState(() => _isOrdering = true);
    try {
      if (_cart.isMultiRestaurant) {
        await _checkoutMultiRestaurant();
      } else {
        await _checkoutSingleRestaurant();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  Future<void> _checkoutMultiRestaurant() async {
    // Create one express order per restaurant
    final byRestaurant = _cart.byRestaurant;
    double totalAmount = 0;
    String firstOrderId = '';
    final restaurantNames = <String>[];

    for (final restaurantId in byRestaurant.keys) {
      final entries = byRestaurant[restaurantId]!;
      final items = entries.map((e) => e.item).toList();
      restaurantNames.add(entries.first.restaurantName);

      Restaurant? r;
      try {
        r = await _restaurantService.getRestaurant(restaurantId);
      } catch (_) {}

      final subtotal = items.fold(0.0, (s, i) => s + i.price * i.quantity);
      final fee = (r?.deliveryFee ?? 0) * 2; // express = ×2
      totalAmount += subtotal + fee;

      final order = await _orderService.createOrder(
        restaurantId: restaurantId,
        items: items,
        deliveryType: 'express',
      );
      if (firstOrderId.isEmpty) firstOrderId = order.id;
    }

    if (!mounted) return;
    _cart.clear(); // Limpiar carrito al confirmar
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          orderId: firstOrderId,
          amount: totalAmount,
          restaurantName: restaurantNames.join(' + '),
        ),
      ),
    );
  }

  Future<void> _checkoutSingleRestaurant() async {
    final restaurantId = _cart.restaurantIds.first;
    final items = _cart.entries.map((e) => e.item).toList();
    final restaurantName = _cart.entries.first.restaurantName;

    final order = await _orderService.createOrder(
      restaurantId: restaurantId,
      items: items,
      deliveryType: _deliveryType,
    );

    if (!mounted) return;
    _cart.clearRestaurant(restaurantId); // Limpiar carrito al confirmar
    Navigator.pop(context);

    if (_deliveryType == 'recogida') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido registrado. Te avisaremos cuando esté listo.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            orderId: order.id,
            amount: _total,
            restaurantName: restaurantName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMulti = _cart.isMultiRestaurant;
    final byRestaurant = _cart.byRestaurant;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mi Carrito',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () {
                    _cart.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Vaciar',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),

          // Multi-restaurant banner
          if (isMulti)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.electric_bolt,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedido Express automático',
                            style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                          Text(
                            'Elegiste productos de ${byRestaurant.length} restaurantes distintos. Se procesará un pedido Express por restaurante con tarifa ×2.',
                            style: TextStyle(
                                color: Colors.orange.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Items (scrollable)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final restaurantId in byRestaurant.keys) ...[
                    if (isMulti)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.storefront_outlined,
                                size: 14,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              byRestaurant[restaurantId]!.first.restaurantName,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ...byRestaurant[restaurantId]!.map((e) => _CartItemRow(
                          entry: e,
                          onAdd: () => _cart.addItem(
                              e.item, e.restaurantId, e.restaurantName),
                          onRemove: () =>
                              _cart.removeItem(e.item.menuItemId),
                        )),
                  ],
                ],
              ),
            ),
          ),

          // Delivery type selector (all 3 always visible; disabled when multi-restaurant)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _DeliveryChip(
                    label: 'Delivery',
                    icon: Icons.delivery_dining,
                    selected: !isMulti && _deliveryType == 'delivery',
                    disabled: isMulti,
                    onTap: isMulti
                        ? null
                        : () => setState(() => _deliveryType = 'delivery'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DeliveryChip(
                    label: 'Recojo',
                    icon: Icons.store,
                    selected: !isMulti && _deliveryType == 'recogida',
                    disabled: isMulti,
                    onTap: isMulti
                        ? null
                        : () => setState(() => _deliveryType = 'recogida'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DeliveryChip(
                    label: 'Express',
                    icon: Icons.electric_bolt,
                    selected: isMulti || _deliveryType == 'express',
                    color: Colors.orange.shade700,
                    onTap: isMulti
                        ? null
                        : () => setState(() => _deliveryType = 'express'),
                  ),
                ),
              ],
            ),
          ),

          // Totals
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                const Divider(height: 0),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal',
                        style: TextStyle(color: Colors.grey.shade600)),
                    Text('Bs ${_subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                if (!isMulti && _deliveryType != 'recogida') ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _deliveryType == 'express'
                            ? 'Envío Express (×2)'
                            : 'Envío',
                        style: TextStyle(
                          color: _deliveryType == 'express'
                              ? Colors.orange.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      _restaurantDeliveryFee == null
                          ? Text('—',
                              style:
                                  TextStyle(color: Colors.grey.shade400))
                          : Text(
                              _deliveryFee == 0
                                  ? 'Gratis'
                                  : 'Bs ${_deliveryFee.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: _deliveryType == 'express'
                                    ? Colors.orange.shade700
                                    : null,
                                fontWeight: _deliveryType == 'express'
                                    ? FontWeight.w600
                                    : null,
                              ),
                            ),
                    ],
                  ),
                ],
                if (isMulti) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Envío Express',
                          style: TextStyle(color: Colors.orange.shade700)),
                      Text('calculado al confirmar',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (!isMulti) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(
                        'Bs ${_total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isMulti && _deliveryType != 'recogida') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 13, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Se requiere pago previo por transferencia',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_isOrdering || _cart.isEmpty) ? null : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMulti
                          ? Colors.orange.shade700
                          : theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isOrdering
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isMulti
                                ? '⚡ Confirmar Express'
                                : _deliveryType == 'recogida'
                                    ? 'Confirmar pedido'
                                    : 'Confirmar pedido',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final Color? color;

  const _DeliveryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Theme.of(context).colorScheme.primary;
    final effectiveColor = disabled ? Colors.grey.shade400 : primary;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.shade100
              : selected
                  ? effectiveColor.withValues(alpha: 0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade300
                : selected
                    ? effectiveColor
                    : Colors.grey.shade300,
            width: selected && !disabled ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 18,
                color: disabled
                    ? Colors.grey.shade400
                    : selected
                        ? effectiveColor
                        : Colors.grey.shade500),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: disabled
                    ? Colors.grey.shade400
                    : selected
                        ? effectiveColor
                        : Colors.grey.shade600,
                fontWeight: selected && !disabled
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartEntry entry;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CartItemRow({
    required this.entry,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(entry.item.name,
                style: const TextStyle(fontSize: 14)),
          ),
          Row(
            children: [
              _Btn(icon: Icons.remove, onTap: onRemove),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('${entry.item.quantity}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              _Btn(icon: Icons.add, onTap: onAdd, filled: true),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: Text(
                  'Bs ${(entry.item.price * entry.item.quantity).toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _Btn({required this.icon, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? primary : Colors.transparent,
          border: filled ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon,
            size: 13,
            color: filled ? Colors.white : Colors.grey.shade600),
      ),
    );
  }
}
