import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/shop_service.dart';
import '../../../services/notification_api_service.dart';
import '../notifications_sheet.dart';
import 'shop_page.dart';

// ── Tipos de negocio disponibles ──────────────────────────────────────────────

class _BusinessTypeOption {
  final String? value; // null = Todos
  final String label;
  final IconData icon;
  const _BusinessTypeOption({this.value, required this.label, required this.icon});
}

const _businessTypes = [
  _BusinessTypeOption(value: null,           label: 'Todos',          icon: Icons.apps),
  _BusinessTypeOption(value: 'shop',   label: 'Restaurantes',   icon: Icons.shop),
  _BusinessTypeOption(value: 'supermarket',  label: 'Supermercados',  icon: Icons.local_grocery_store),
  _BusinessTypeOption(value: 'minimarket',   label: 'Minimarkets',    icon: Icons.store),
];

String _sectionLabel(String? businessType) {
  switch (businessType) {
    case 'supermarket': return 'Supermercados';
    case 'minimarket':  return 'Minimarkets';
    case 'shop':  return 'Restaurantes';
    default:            return 'Negocios';
  }
}

String _searchHint(String? businessType) {
  switch (businessType) {
    case 'supermarket': return 'Buscar supermercado...';
    case 'minimarket':  return 'Buscar minimarket...';
    case 'shop':  return 'Buscar shope...';
    default:            return 'Buscar negocio...';
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
  final _searchController = TextEditingController();

  late Future<List<Shop>> _shopsFuture;
  late Future<List<ShopCategory>> _categoriesFuture;
  String? _selectedCategory;
  String? _selectedBusinessType; // null = todos
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notifService.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
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
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        categoryId: _selectedCategory,
        businessType: _selectedBusinessType,
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService().currentUser;

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hola, ${user?.firstName ?? 'amigo'} 👋',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '¿Qué vas a pedir hoy?',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              onPressed: _openNotifications,
                              tooltip: 'Notificaciones',
                            ),
                            if (_unreadCount > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
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
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _load();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Business type tabs
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _businessTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final opt = _businessTypes[i];
                    final selected = _selectedBusinessType == opt.value;
                    return _BusinessTypeTab(
                      label: opt.label,
                      icon: opt.icon,
                      selected: selected,
                      onTap: () => _selectBusinessType(opt.value),
                    );
                  },
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
                  return SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: categories.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          final selected = _selectedCategory == null;
                          return _CategoryChip(
                            label: 'Todos',
                            selected: selected,
                            onTap: () {
                              _selectedCategory = null;
                              _load();
                            },
                          );
                        }
                        final cat = categories[i - 1];
                        final selected = _selectedCategory == cat.id;
                        return _CategoryChip(
                          label: '${cat.icon ?? ''} ${cat.name}'.trim(),
                          selected: selected,
                          onTap: () {
                            _selectedCategory = selected ? null : cat.id;
                            _load();
                          },
                        );
                      },
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
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                    child: Center(child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )),
                  );
                }
                if (snap.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('No se pudo cargar', style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _load, child: const Text('Reintentar')),
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
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _StoreCard(
                          shop: list[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopPage(shopId: list[i].id),
                            ),
                          ),
                        ),
                      ),
                      childCount: list.length,
                    ),
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

// ── Business Type Tab ─────────────────────────────────────────────────────────

class _BusinessTypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _BusinessTypeTab({
    required this.label,
    required this.icon,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

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
    case 'supermarket': return Icons.local_grocery_store;
    case 'minimarket':  return Icons.store;
    default:            return Icons.shop;
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
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: shop.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: shop.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shop.name,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!shop.isOpen)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Cerrado',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                    ],
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
                        Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                        const SizedBox(width: 3),
                        Text(
                          shop.rating!.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (shop.deliveryMinutes != null) ...[
                        Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          '${shop.deliveryMinutes} min',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
