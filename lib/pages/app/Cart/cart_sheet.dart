import 'package:flutter/material.dart';
import '../../../services/cart_service.dart';
import '../../../services/order_service.dart';
import '../../../services/restaurant_service.dart';
import '../../../services/address_service.dart';
import '../Orders/payment_page.dart';
import '../settings/addresses_page.dart';

class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final _cart = CartService();
  final _orderService = OrderService();
  final _restaurantService = RestaurantService();
  final _addressService = AddressService();

  bool _isOrdering = false;
  String _deliveryType = 'delivery';
  double? _restaurantDeliveryFee;

  List<UserAddress> _addresses = [];
  UserAddress? _selectedAddress;
  bool _loadingAddresses = false;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    if (!_cart.isMultiRestaurant && _cart.restaurantIds.isNotEmpty) {
      _loadDeliveryFee();
    }
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _loadingAddresses = true);
    try {
      final list = await _addressService.getAddresses();
      if (mounted) {
        setState(() {
          _addresses = list;
          if (list.isNotEmpty) {
            // Pre-seleccionar la dirección por defecto, o la primera
            _selectedAddress = list.firstWhere(
              (a) => a.isDefault,
              orElse: () => list.first,
            );
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  bool get _needsAddress =>
      _deliveryType == 'delivery' ||
      _deliveryType == 'express' ||
      _cart.isMultiRestaurant;

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
      final r = await _restaurantService.getRestaurant(
        _cart.restaurantIds.first,
      );
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
    // Validar dirección de entrega cuando se requiere
    if (_needsAddress && _selectedAddress == null) {
      if (_addresses.isEmpty) {
        // No tiene ninguna dirección guardada — ir a agregar una
        final added = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const AddressesPage()),
        );
        if (added == true) await _loadAddresses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona una dirección de entrega'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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
    final byRestaurant = _cart.byRestaurant;
    final restaurantNames = <String>[];
    final expressOrders = <ExpressRestaurantOrder>[];

    for (final restaurantId in byRestaurant.keys) {
      final entries = byRestaurant[restaurantId]!;
      restaurantNames.add(entries.first.restaurantName);
      expressOrders.add(
        ExpressRestaurantOrder(
          restaurantId: restaurantId,
          items: entries.map((e) => e.item).toList(),
        ),
      );
    }

    final result = await _orderService.expressCheckout(
      restaurants: expressOrders,
      deliveryAddress: _selectedAddress?.fullAddress,
      deliveryLat: _selectedAddress?.latitude,
      deliveryLng: _selectedAddress?.longitude,
    );

    debugPrint(
      'expressCheckout result: groupId=${result.groupId}, total=${result.total}',
    );

    if (!mounted) return;
    _cart.clear();
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          groupId: result.groupId,
          amount: result.total,
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
      deliveryAddress: _needsAddress ? _selectedAddress?.fullAddress : null,
      deliveryLat: _needsAddress ? _selectedAddress?.latitude : null,
      deliveryLng: _needsAddress ? _selectedAddress?.longitude : null,
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
            amount: order.total,
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
                Text(
                  'Mi Carrito',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _cart.clear();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Vaciar',
                    style: TextStyle(color: Colors.red),
                  ),
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
                    Icon(
                      Icons.electric_bolt,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
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
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Elegiste productos de ${byRestaurant.length} restaurantes distintos. Se procesará un pedido Express por restaurante con tarifa ×2.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                            ),
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
                            Icon(
                              Icons.storefront_outlined,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              byRestaurant[restaurantId]!.first.restaurantName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...byRestaurant[restaurantId]!.map(
                      (e) => _CartItemRow(
                        entry: e,
                        onAdd: () => _cart.addItem(
                          e.item,
                          e.restaurantId,
                          e.restaurantName,
                        ),
                        onRemove: () => _cart.removeItem(e.item.menuItemId),
                      ),
                    ),
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

          // Selector de dirección (solo cuando se requiere entrega)
          if (_needsAddress)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _loadingAddresses
                  ? const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _addresses.isEmpty
                  ? GestureDetector(
                      onTap: () async {
                        final added = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddressesPage(),
                          ),
                        );
                        if (added == true) _loadAddresses();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_off_outlined,
                              size: 16,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Necesitas agregar una dirección de entrega',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.red.shade700,
                            ),
                          ],
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: () async {
                        final picked = await showModalBottomSheet<UserAddress>(
                          context: context,
                          builder: (_) => _AddressPicker(
                            addresses: _addresses,
                            selected: _selectedAddress,
                          ),
                        );
                        if (picked != null) {
                          setState(() => _selectedAddress = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedAddress != null
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.5)
                                : Colors.orange.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: _selectedAddress != null
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedAddress != null
                                    ? _selectedAddress!.fullAddress
                                    : 'Selecciona dirección de entrega',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _selectedAddress != null
                                      ? Colors.black87
                                      : Colors.orange.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.expand_more,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
                      ),
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
                    Text(
                      'Subtotal',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
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
                          ? Text(
                              '—',
                              style: TextStyle(color: Colors.grey.shade400),
                            )
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
                      Text(
                        'Envío Express',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                      Text(
                        'calculado al confirmar',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (!isMulti) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
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
                      Icon(
                        Icons.info_outline,
                        size: 13,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Se requiere pago previo por transferencia',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isOrdering || _cart.isEmpty)
                        ? null
                        : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMulti
                          ? Colors.orange.shade700
                          : theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isOrdering
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isMulti
                                ? '⚡ Confirmar Express'
                                : _deliveryType == 'recogida'
                                ? 'Confirmar pedido'
                                : 'Confirmar pedido',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
            Icon(
              icon,
              size: 18,
              color: disabled
                  ? Colors.grey.shade400
                  : selected
                  ? effectiveColor
                  : Colors.grey.shade500,
            ),
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
            child: Text(entry.item.name, style: const TextStyle(fontSize: 14)),
          ),
          Row(
            children: [
              _Btn(icon: Icons.remove, onTap: onRemove),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${entry.item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
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
                    color: theme.colorScheme.primary,
                  ),
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
        child: Icon(
          icon,
          size: 13,
          color: filled ? Colors.white : Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _AddressPicker extends StatelessWidget {
  final List<UserAddress> addresses;
  final UserAddress? selected;

  const _AddressPicker({required this.addresses, this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dirección de entrega',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddressesPage()),
                    );
                  },
                  child: const Text('Administrar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...addresses.map((addr) {
            final isSelected = addr.id == selected?.id;
            return ListTile(
              leading: Icon(
                Icons.location_on_outlined,
                color: isSelected ? theme.colorScheme.primary : Colors.grey,
              ),
              title: Text(
                addr.fullAddress,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: addr.reference != null && addr.reference!.isNotEmpty
                  ? Text(addr.reference!, style: const TextStyle(fontSize: 12))
                  : null,
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    )
                  : null,
              onTap: () => Navigator.pop(context, addr),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
