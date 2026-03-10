import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home/home_page.dart';
import 'Express/express_page.dart';
import 'orders/orders_page.dart';
import 'Chat/chat_page.dart';
import 'settings/settings_page.dart';
import 'Rider/available_groups_page.dart';
import 'Rider/active_delivery_page.dart';
import '../../services/cart_service.dart';
import 'Cart/cart_sheet.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _selectedIndex = 0;
  final _cart = CartService();
  String _activeMode = 'client';

  static const List<Widget> _clientPages = [
    HomePage(),
    ExpressPage(),
    OrdersPage(),
    ChatPage(),
    SettingsPage(),
  ];

  static const List<Widget> _riderPages = [
    AvailableGroupsPage(),
    ActiveDeliveryPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('active_mode') ?? 'client';
    if (mounted) setState(() { _activeMode = mode; _selectedIndex = 0; });
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() => setState(() {});

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
    final isRider = _activeMode == 'rider';
    final pages = isRider ? _riderPages : _clientPages;
    final cartCount = _cart.totalCount;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: pages),

          // Carrito flotante solo en modo cliente
          if (!isRider && cartCount > 0)
            Positioned(
              right: 16,
              bottom: 80,
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
                        child: Icon(Icons.shopping_basket_outlined, color: Colors.white, size: 26),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Text(
                            '$cartCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: theme.colorScheme.primaryContainer,
        destinations: isRider
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.delivery_dining_outlined),
                  selectedIcon: Icon(Icons.delivery_dining),
                  label: 'Disponibles',
                ),
                NavigationDestination(
                  icon: Icon(Icons.route_outlined),
                  selectedIcon: Icon(Icons.route),
                  label: 'Mi Entrega',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.electric_bolt_outlined),
                  selectedIcon: Icon(Icons.electric_bolt),
                  label: 'Express',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Pedidos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
      ),
    );
  }
}
