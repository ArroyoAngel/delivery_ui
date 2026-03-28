import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home/home_page.dart';
import 'Express/express_page.dart';
import 'Chat/chat_page.dart';
import 'settings/settings_page.dart';
import 'Rider/available_groups_page.dart';
import 'Rider/active_delivery_page.dart';
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_tracking_service.dart';
import '../../services/credit_service.dart';
import '../../services/socket_service.dart';
import '../../services/rider_service.dart';
import '../../theme/app_colors.dart';
import 'Cart/cart_sheet.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _cart = CartService();
  final _credits = CreditService();
  final _socket = SocketService();
  final _rider = RiderService();
  String _activeMode = 'client';
  int _riderCredits = 999; // 999 = no cargado aún (no mostrar banner)

  static const List<Widget> _clientPages = [
    HomePage(),
    ExpressPage(),
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
    WidgetsBinding.instance.addObserver(this);
    _cart.addListener(_onCartChanged);
    _socket.on('credit:confirmed', (data) {
      if (!mounted || _activeMode != 'rider') return;
      final balance = (data as Map?)?['balance'];
      if (balance != null) {
        setState(() => _riderCredits = (balance as num).toInt());
      } else {
        _loadRiderCredits();
      }
    });
    _socket.on('credit:rejected', (data) {
      if (!mounted || _activeMode != 'rider') return;
      final reason = (data as Map?)?['reason'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason != null && reason.isNotEmpty
              ? 'Compra rechazada: $reason'
              : 'Tu compra de créditos fue rechazada.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    });
    _loadMode();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_activeMode == 'rider' &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      _goOffline();
    }
  }

  Future<void> _goOffline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rider_online', false);
    await LocationTrackingService().stop();
    _rider.setAvailable(false).catchError((_) {});
  }

  Future<void> _loadRiderCredits() async {
    try {
      final balance = await _credits.getMyBalance();
      if (mounted) setState(() => _riderCredits = balance);
    } catch (_) {}
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('active_mode') ?? 'client';
    final roles = AuthService().currentUser?.roles ?? [];
    final hasRider = roles.contains('rider');
    final hasClient = roles.contains('client');

    String mode;
    if (hasRider && hasClient) {
      // Usuario con ambos roles: respetar la preferencia guardada
      mode = stored;
    } else if (hasRider) {
      // Solo rider: forzar modo delivery
      mode = 'rider';
    } else {
      // Solo client (o sin roles): forzar modo cliente
      mode = 'client';
    }

    if (mode != stored) await prefs.setString('active_mode', mode);

    // Si cargamos en modo rider y el rider estaba online, reanudar tracking
    if (mode == 'rider') {
      final wasOnline = prefs.getBool('rider_online') ?? false;
      if (wasOnline) await LocationTrackingService().start();
    }

    if (mounted)
      setState(() {
        _activeMode = mode;
        _selectedIndex = 0;
      });
    if (mode == 'rider') _loadRiderCredits();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cart.removeListener(_onCartChanged);
    _socket.off('credit:confirmed');
    _socket.off('credit:rejected');
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

    final scaffold = Scaffold(
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
                        child: Icon(
                          Icons.shopping_basket_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRider && _riderCredits < 10)
            Container(
              width: double.infinity,
              color: _riderCredits == 0 ? AppColors.error : AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _riderCredits == 0
                        ? Icons.block
                        : Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _riderCredits == 0
                          ? 'Sin créditos — no podés aceptar pedidos'
                          : 'Créditos bajos ($_riderCredits) — recargá pronto',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
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
        ],
      ),
    );

    if (isRider) {
      return Theme(data: AppColors.riderTheme, child: scaffold);
    }
    return scaffold;
  }
}
