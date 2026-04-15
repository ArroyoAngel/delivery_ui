import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../services/shop_service.dart';
import '../../../services/notification_api_service.dart';
import '../../../services/rating_service.dart';
import '../../../services/socket_service.dart';
import '../../../services/session_context.dart';
import '../../../services/zones_service.dart';
import '../../core/address_selection_page.dart';
import '../notifications_sheet.dart';
import '../ratings/rating_sheet.dart';
import 'shop_page.dart';

// ── Icon name → IconData mapping ─────────────────────────────────────────────

const _iconMap = <String, IconData>{
  'restaurant_menu': Icons.restaurant_menu,
  'local_cafe': Icons.local_cafe,
  'local_grocery_store': Icons.local_grocery_store,
  'storefront': Icons.storefront,
  'local_pharmacy': Icons.local_pharmacy,
  'restaurant': Icons.restaurant_outlined,
  'store': Icons.store_outlined,
  'shopping_basket': Icons.shopping_basket_outlined,
  'medical_services': Icons.medical_services_outlined,
};

IconData _resolveIcon(String? name) => name != null
    ? (_iconMap[name] ?? Icons.store_outlined)
    : Icons.store_outlined;

Color _parseHex(String? hex) {
  if (hex == null) return const Color(0xFFF3F4F6);
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

String _sectionLabel(String? businessType) {
  switch (businessType) {
    case 'supermarket':
      return 'Supermercados';
    case 'minimarket':
      return 'Minimarkets';
    case 'restaurant':
      return 'Restaurantes';
    case 'cafe':
      return 'Cafeterías';
    case 'pharmacy':
      return 'Farmacias';
    default:
      return 'Negocios';
  }
}

String _searchHint(String? businessType) {
  switch (businessType) {
    case 'supermarket':
      return 'Buscar supermercado...';
    case 'minimarket':
      return 'Buscar minimarket...';
    case 'restaurant':
      return 'Buscar restaurante...';
    case 'cafe':
      return 'Buscar cafetería...';
    case 'pharmacy':
      return 'Buscar farmacia...';
    default:
      return 'Buscar negocio...';
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _shopService = ShopService();
  final _notifService = NotificationApiService();
  final _ratingService = RatingService();
  final _searchController = TextEditingController();
  final _sessionContext = SessionContext();
  final _zonesService = ZonesService();

  late Future<List<Shop>> _shopsFuture;
  late Future<List<ShopCategory>> _categoriesFuture;
  late Future<List<BusinessTypeInfo>> _businessTypesFuture;
  String? _selectedCategory;
  String? _selectedBusinessType; // null = todos
  String? _userZoneId; // Zona de la dirección seleccionada
  int _unreadCount = 0;

  // Overrides de status recibidos por WebSocket
  final Map<String, String> _statusOverrides = {};

  @override
  void initState() {
    super.initState();
    _businessTypesFuture = _shopService.getBusinessTypes();
    _loadCategories();
    _detectUserZone();
    _load();
    _loadUnreadCount();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingRatings());
    _sessionContext.addListener(_onSessionChanged);
    SocketService().on('shop:status_changed', (data) {
      if (!mounted) return;
      final shopId = data['shopId'] as String?;
      final status = data['status'] as String?;
      if (shopId != null && status != null) {
        setState(() => _statusOverrides[shopId] = status);
      }
    });
  }

  @override
  void dispose() {
    SocketService().off('shop:status_changed');
    _searchController.dispose();
    _sessionContext.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    // Si cambió la dirección de sesión, detectar nueva zona y recargar
    if (mounted) {
      _detectUserZone();
    }
  }

  Future<void> _detectUserZone() async {
    final address = _sessionContext.selectedAddress;
    if (address?.latitude != null && address?.longitude != null) {
      try {
        final zone = await _zonesService.detectZone(
          address!.latitude!.toDouble(),
          address.longitude!.toDouble(),
        );
        if (mounted) {
          setState(() => _userZoneId = zone?.id);
          _load(); // Recargar shops con la nueva zona
        }
      } catch (e) {
        debugPrint('[HomePage] Error detecting zone: $e');
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notifService.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _checkPendingRatings() async {
    try {
      final orderId = await _ratingService.getFirstPendingOrderId();
      if (orderId != null && mounted) {
        await showRatingSheet(context, orderId);
      }
    } catch (e, st) {
      debugPrint('[_checkPendingRatings] ERROR: $e');
      debugPrint('[_checkPendingRatings] STACK: $st');
    }
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const NotificationsSheet(),
    ).then((_) => _loadUnreadCount());
  }

  void _openAddressSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddressSelectionPage(),
    );
  }

  void _loadCategories() {
    setState(() {
      _categoriesFuture = _shopService.getCategories(
        businessType: _selectedBusinessType,
      );
    });
  }

  void _load() {
    setState(() {
      _shopsFuture = _shopService.getShops(
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        categoryId: _selectedCategory,
        businessType: _selectedBusinessType,
        zoneId: _userZoneId,
      );
    });
  }

  void _selectBusinessType(String? type) {
    _selectedBusinessType = type;
    _selectedCategory = null; // reset category when switching type
    _loadCategories();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _load(),
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'YaYa! Eats',
                                style: TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              GestureDetector(
                                onTap: _openAddressSelection,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: AppColors.orange,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _sessionContext.selectedAddress?.name ??
                                          'Santa Cruz, Bolivia',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _openNotifications,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: Color(0xFF4B5563),
                                  size: 22,
                                ),
                              ),
                              if (_unreadCount > 0)
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.orange,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        hintText: _searchHint(_selectedBusinessType),
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _load();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: AppColors.orange,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Business type icon grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categorías',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<BusinessTypeInfo>>(
                      future: _businessTypesFuture,
                      builder: (_, snap) {
                        final types = snap.data ?? [];
                        // "Todos" siempre primero, luego los tipos de la DB
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _CategoryIconTile(
                                label: 'Todos',
                                icon: Icons.apps_rounded,
                                selected: _selectedBusinessType == null,
                                bg: const Color(0xFFEFF4FF),
                                iconColor: AppColors.riderBlue,
                                onTap: () => _selectBusinessType(null),
                              ),
                              ...types.map((t) {
                                final selected = _selectedBusinessType == t.value;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: _CategoryIconTile(
                                    label: t.label,
                                    icon: _resolveIcon(t.flutterIcon),
                                    selected: selected,
                                    bg: _parseHex(t.bgColor),
                                    iconColor: _parseHex(t.iconColor),
                                    onTap: () => _selectBusinessType(t.value),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Category chips (filtered by business type)
            SliverToBoxAdapter(
              child: FutureBuilder<List<ShopCategory>>(
                future: _categoriesFuture,
                builder: (_, snap) {
                  final categories = snap.data ?? [];
                  if (categories.isEmpty) return const SizedBox.shrink();
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: 'Todos',
                          selected: _selectedCategory == null,
                          onTap: () {
                            _selectedCategory = null;
                            _load();
                          },
                        ),
                        ...categories.map((cat) {
                          final selected = _selectedCategory == cat.id;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _CategoryChip(
                              label: '${cat.icon ?? ''} ${cat.name}'.trim(),
                              selected: selected,
                              onTap: () {
                                _selectedCategory = selected ? null : cat.id;
                                _load();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Section title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _sectionLabel(_selectedBusinessType),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Store list
            FutureBuilder<List<Shop>>(
              future: _shopsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                if (snap.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.wifi_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No se pudo cargar',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'No hay negocios disponibles',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final shop = _statusOverrides.containsKey(list[i].id)
                          ? list[i].copyWith(
                              status: _statusOverrides[list[i].id],
                            )
                          : list[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _StoreCard(
                          shop: shop,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopPage(shopId: shop.id),
                            ),
                          ),
                        ),
                      );
                    }, childCount: list.length),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── Category Icon Tile ────────────────────────────────────────────────────────

class _CategoryIconTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color bg;
  final Color iconColor;
  final VoidCallback onTap;

  const _CategoryIconTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.bg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: selected ? theme.colorScheme.primary : bg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.35,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 26,
                color: selected ? Colors.white : iconColor,
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 28,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? theme.colorScheme.primary
                        : const Color(0xFF4B5563),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Store Card ────────────────────────────────────────────────────────────────

IconData _placeholderIcon(String businessType) {
  switch (businessType) {
    case 'supermarket':
      return Icons.local_grocery_store;
    case 'minimarket':
      return Icons.storefront;
    case 'cafe':
      return Icons.local_cafe;
    case 'pharmacy':
      return Icons.local_pharmacy;
    default:
      return Icons.restaurant_menu;
  }
}

class _StoreCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;

  const _StoreCard({required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlays
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: shop.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: shop.imageUrls.first,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 160,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _PlaceholderImage(
                            height: 160,
                            icon: _placeholderIcon(shop.businessType),
                          ),
                        )
                      : _PlaceholderImage(
                          height: 160,
                          icon: _placeholderIcon(shop.businessType),
                        ),
                ),
                // Status badge — top left
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: shop.isDisabled
                            ? Colors.orange.shade200
                            : (shop.isOpen
                                  ? Colors.green.shade200
                                  : Colors.grey.shade200),
                      ),
                    ),
                    child: Text(
                      shop.isDisabled
                          ? 'SOLO EXPRESS'
                          : (shop.isOpen ? 'ABIERTO' : 'CERRADO'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: shop.isDisabled
                            ? Colors.orange.shade700
                            : (shop.isOpen
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
                // Delivery time — bottom right
                if (shop.deliveryMinutes != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${shop.deliveryMinutes} min',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (shop.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      shop.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (shop.rating != null) ...[
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          shop.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (shop.deliveryMinutes != null) ...[
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${shop.deliveryMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (shop.deliveryFee != null)
                        Text(
                          shop.deliveryFee == 0
                              ? 'Envío gratis'
                              : 'Envío Bs ${shop.deliveryFee!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: shop.deliveryFee == 0
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  final double height;
  final IconData icon;
  const _PlaceholderImage({required this.height, this.icon = Icons.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: Icon(icon, size: 48, color: Colors.grey.shade400),
    );
  }
}
