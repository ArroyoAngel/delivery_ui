import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/cart_service.dart';
import '../../../services/order_service.dart';
import '../../../services/shop_service.dart';
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
  final _shopService = ShopService();
  final _addressService = AddressService();

  bool _isOrdering = false;
  String _deliveryType = 'delivery';
  String _paymentMethod = 'cash'; // 'qr' | 'cash'
  bool _shopDisabled = false;
  double _configDeliveryFee = 5.0;
  double _configExpressFee = 5.0;

  List<UserAddress> _addresses = [];
  UserAddress? _selectedAddress;
  bool _loadingAddresses = false;

  // Cupón
  final _couponController = TextEditingController();
  String? _appliedCouponCode;
  double _couponDiscount = 0;
  bool _validatingCoupon = false;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    if (!_cart.isMultiShop && _cart.shopIds.isNotEmpty) {
      _loadDeliveryFee();
    }
    _loadAddresses();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final data = await ApiClient().get('/config') as List;
      final map = <String, String>{
        for (final e in data.cast<Map<String, dynamic>>())
          e['key'] as String: e['value'] as String,
      };
      if (mounted) {
        setState(() {
          _configDeliveryFee = double.tryParse(map['delivery_fee'] ?? '5') ?? 5.0;
          _configExpressFee  = double.tryParse(map['express_fee']  ?? '5') ?? 5.0;
        });
      }
    } catch (_) {}
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
      _cart.isMultiShop;

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    if (_cart.shopIds.isEmpty) return;
    setState(() { _validatingCoupon = true; _couponError = null; });
    try {
      final discount = await _orderService.validateCoupon(
        code: code,
        subtotal: _subtotal,
        deliveryFee: _deliveryFee,
        shopId: _cart.shopIds.first,
      );
      setState(() {
        _appliedCouponCode = code.toUpperCase();
        _couponDiscount = discount;
      });
    } catch (e) {
      setState(() {
        _couponError = e.toString().replaceFirst('Exception: ', '');
        _appliedCouponCode = null;
        _couponDiscount = 0;
      });
    } finally {
      if (mounted) setState(() => _validatingCoupon = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _couponDiscount = 0;
      _couponError = null;
      _couponController.clear();
    });
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDeliveryFee() async {
    try {
      final shopId = _cart.shopIds.first;
      debugPrint('[CartSheet] cargando shop: $shopId');
      final s = await _shopService.getShop(shopId);
      debugPrint('[CartSheet] shop.name=${s.name} shop.status=${s.status} shop.isDisabled=${s.isDisabled}');
      if (mounted) {
        setState(() {
          _shopDisabled = s.isDisabled;
          if (s.isDisabled) _deliveryType = 'express';
        });
        debugPrint('[CartSheet] _shopDisabled=$_shopDisabled _deliveryType=$_deliveryType');
      }
    } catch (e) {
      debugPrint('[CartSheet] ERROR en _loadDeliveryFee: $e');
    }
  }

  double get _subtotal => _cart.subtotal;

  double get _deliveryFee {
    if (_deliveryType == 'express') return _configExpressFee;
    if (_deliveryType == 'delivery') return _configDeliveryFee;
    return 0;
  }

  double get _total => _subtotal + _deliveryFee - _couponDiscount;

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
      if (_cart.isMultiShop) {
        await _checkoutMultiShop();
      } else {
        await _checkoutSingleShop();
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

  Future<void> _checkoutMultiShop() async {
    final byShop = _cart.byShop;
    final shopNames = <String>[];
    final expressOrders = <ExpressShopOrder>[];

    for (final shopId in byShop.keys) {
      final entries = byShop[shopId]!;
      shopNames.add(entries.first.shopName);
      expressOrders.add(
        ExpressShopOrder(
          shopId: shopId,
          items: entries.map((e) => e.item).toList(),
        ),
      );
    }

    final result = await _orderService.expressCheckout(
      shops: expressOrders,
      deliveryAddress: _selectedAddress?.fullAddress,
      deliveryLat: _selectedAddress?.latitude,
      deliveryLng: _selectedAddress?.longitude,
      paymentMethod: _paymentMethod,
    );

    debugPrint(
      'expressCheckout result: groupId=${result.groupId}, total=${result.total}',
    );

    if (!mounted) return;
    _cart.clear();
    Navigator.pop(context);

    if (_paymentMethod == 'cash') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido registrado. Paga al repartidor en efectivo.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            groupId: result.groupId,
            amount: result.total,
            shopName: shopNames.join(' + '),
            paymentReference: result.paymentReference,
          ),
        ),
      );
    }
  }

  Future<void> _checkoutSingleShop() async {
    final shopId = _cart.shopIds.first;
    final items = _cart.entries.map((e) => e.item).toList();
    final shopName = _cart.entries.first.shopName;

    final order = await _orderService.createOrder(
      shopId: shopId,
      items: items,
      deliveryType: _deliveryType,
      deliveryAddress: _needsAddress ? _selectedAddress?.fullAddress : null,
      deliveryLat: _needsAddress ? _selectedAddress?.latitude : null,
      deliveryLng: _needsAddress ? _selectedAddress?.longitude : null,
      couponCode: _appliedCouponCode,
      paymentMethod: _paymentMethod,
    );

    if (!mounted) return;
    _cart.clearShop(shopId);
    Navigator.pop(context);

    if (_deliveryType == 'recogida' || _paymentMethod == 'cash') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _paymentMethod == 'cash'
                ? 'Pedido registrado. Paga al repartidor en efectivo.'
                : 'Pedido registrado. Te avisaremos cuando esté listo.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            orderId: order.id,
            amount: order.total + order.platformFee,
            shopName: shopName,
            paymentReference: order.paymentReference,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMulti = _cart.isMultiShop;
    final byShop = _cart.byShop;

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

          // Indicador de capacidad de bolsa
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Builder(builder: (context) {
              final used = _cart.totalSize;
              final max = _cart.maxBagSize;
              final pct = (used / max).clamp(0.0, 1.0);
              final isFull = used >= max;
              return Row(
                children: [
                  Icon(
                    isFull ? Icons.shopping_bag : Icons.shopping_bag_outlined,
                    size: 14,
                    color: isFull ? Colors.red : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          isFull ? Colors.red : pct > 0.7 ? Colors.orange : Colors.green,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$used/$max pts',
                    style: TextStyle(
                      fontSize: 11,
                      color: isFull ? Colors.red : Colors.grey[600],
                      fontWeight: isFull ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),

          // Banner negocio sin membresía
          if (!isMulti && _shopDisabled)
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
                    Icon(Icons.flash_on, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este negocio solo acepta pedidos Express.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Multi-shop banner
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
                            'Elegiste productos de ${byShop.length} negocios distintos. Se procesará un pedido Express por negocio con tarifa ×2.',
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
                  for (final shopId in byShop.keys) ...[
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
                              byShop[shopId]!.first.shopName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...byShop[shopId]!.map(
                      (e) => _CartItemRow(
                        entry: e,
                        onAdd: () {
                          final added = _cart.addItem(e.item, e.shopId, e.shopName);
                          if (!added) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Bolsa llena (${_cart.totalSize}/${_cart.maxBagSize} pts). Quitá algún producto primero.',
                                ),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        onRemove: () => _cart.removeItem(e.item.menuItemId),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Delivery type selector (all 3 always visible; disabled when multi-shop)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _DeliveryChip(
                    label: 'Delivery',
                    icon: Icons.delivery_dining,
                    selected: !isMulti && !_shopDisabled && _deliveryType == 'delivery',
                    disabled: isMulti || _shopDisabled,
                    onTap: (isMulti || _shopDisabled)
                        ? null
                        : () => setState(() => _deliveryType = 'delivery'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DeliveryChip(
                    label: 'Recojo',
                    icon: Icons.store,
                    selected: !isMulti && !_shopDisabled && _deliveryType == 'recogida',
                    disabled: isMulti || _shopDisabled,
                    onTap: (isMulti || _shopDisabled)
                        ? null
                        : () => setState(() => _deliveryType = 'recogida'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DeliveryChip(
                    label: 'Express',
                    icon: Icons.electric_bolt,
                    selected: isMulti || _shopDisabled || _deliveryType == 'express',
                    color: Colors.orange.shade700,
                    disabled: isMulti,
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

          // Cupón (solo para pedido simple, no multi-shop)
          if (!isMulti)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _appliedCouponCode != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_offer, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$_appliedCouponCode · −Bs ${_couponDiscount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _removeCoupon,
                            child: Icon(Icons.close, size: 18, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _couponController,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Código de cupón',
                                  hintStyle: const TextStyle(fontSize: 13),
                                  prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  ),
                                ),
                                onSubmitted: (_) => _applyCoupon(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _validatingCoupon ? null : _applyCoupon,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: _validatingCoupon
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Aplicar', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                        if (_couponError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _couponError!,
                            style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                          ),
                        ],
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
                        _deliveryType == 'express' ? 'Envío Express' : 'Envío',
                        style: TextStyle(
                          color: _deliveryType == 'express'
                              ? Colors.orange.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      Text(
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
                if (!isMulti && _couponDiscount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cupón $_appliedCouponCode',
                        style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                      ),
                      Text(
                        '−Bs ${_couponDiscount.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ],
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
                // Selector de método de pago (no aplica para recogida)
                if (_deliveryType != 'recogida') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentChip(
                          label: 'QR / Transferencia',
                          icon: Icons.qr_code,
                          selected: _paymentMethod == 'qr',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pago con QR — Próximamente'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PaymentChip(
                          label: 'Efectivo',
                          icon: Icons.payments_outlined,
                          selected: _paymentMethod == 'cash',
                          onTap: () => setState(() => _paymentMethod = 'cash'),
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

class _PaymentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? primary : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? primary : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? primary : Colors.grey.shade600,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
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
