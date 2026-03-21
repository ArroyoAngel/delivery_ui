import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/login_page.dart';
import '../app_root.dart';
import '../orders/orders_page.dart';
import 'addresses_page.dart';
import 'edit_profile_page.dart';
import 'rider_bank_accounts_page.dart';
import 'rider_earnings_page.dart';
import 'support_ticket_page.dart';
import '../notifications_sheet.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_tracking_service.dart';
import '../../../services/rider_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _authService = AuthService();
  String _activeMode = 'client';
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _activeMode = prefs.getString('active_mode') ?? 'client');
  }

  Future<void> _setMode(String mode) async {
    if (mode == _activeMode || _switching) return;
    if (mode == 'rider' && !(_authService.currentUser?.roles.contains('rider') ?? false)) return;

    // Bloquear cambio a cliente si hay entrega activa
    if (mode == 'client') {
      setState(() => _switching = true);
      try {
        final activeGroup = await RiderService().getMyActiveGroup();
        if (activeGroup != null &&
            !['done', 'completed', 'cancelled'].contains(activeGroup.status)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tienes una entrega en curso. Complétala antes de cambiar de modo.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _switching = false);
          return;
        }
      } catch (_) {}

      // Al salir de rider: detener tracking + resetear online
      await LocationTrackingService().stop();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rider_online', false);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_mode', mode);
    setState(() { _activeMode = mode; _switching = false; });

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AppRoot()),
        (_) => false,
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que deseas salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await LocationTrackingService().stop();
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.currentUser;
    final fullName = user?.fullName ?? 'Usuario';
    final email = user?.email ?? '';
    final initials = user?.initials ?? 'U';
    final roles = user?.roles ?? [];
    final isRider = roles.contains('rider');
    final hasBothRoles = isRider && roles.contains('client');

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isRider)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Repartidor',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Selector de modo (solo visible si el superadmin otorgó ambos roles)
            if (hasBothRoles)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modo activo', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Cliente',
                            selected: _activeMode == 'client',
                            loading: _switching && _activeMode == 'rider',
                            onTap: () => _setMode('client'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeButton(
                            icon: Icons.delivery_dining,
                            label: 'Delivery',
                            selected: _activeMode == 'rider',
                            loading: false,
                            onTap: () => _setMode('rider'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (hasBothRoles) const SizedBox(height: 12),

            // Options
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline,
                    title: 'Editar perfil',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfilePage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Historial de pedidos',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrdersPage()),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.location_on_outlined,
                    title: 'Mis direcciones',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesPage())),
                  ),
                  // Opciones solo para riders
                  if (isRider) ...[
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Mis ingresos y retiros',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderEarningsPage())),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.account_balance_outlined,
                      title: 'Cuentas bancarias',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderBankAccountsPage())),
                    ),
                  ],
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notificaciones',
                    onTap: _openNotifications,
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.help_outline,
                    title: 'Ayuda y soporte',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketPage())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: loading
            ? const Center(child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(
                children: [
                  Icon(icon, color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: Colors.white,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: theme.colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
