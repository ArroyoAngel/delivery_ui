import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/rider_service.dart';
import '../../../services/notification_api_service.dart';
import '../../../services/location_tracking_service.dart';
import '../notifications_sheet.dart';
import 'rider_map_page.dart';

class AvailableGroupsPage extends StatefulWidget {
  const AvailableGroupsPage({super.key});

  @override
  State<AvailableGroupsPage> createState() => _AvailableGroupsPageState();
}

class _AvailableGroupsPageState extends State<AvailableGroupsPage> {
  final _service = RiderService();
  final _notifService = NotificationApiService();
  final _tracking = LocationTrackingService();
  List<RiderGroup> _groups = [];
  bool _loading = true;
  String? _error;
  String? _accepting;
  int _unreadCount = 0;
  bool _online = false;
  bool _togglingOnline = false;

  @override
  void initState() {
    super.initState();
    _loadOnlineState();
    _loadUnreadCount();
  }

  Future<void> _loadOnlineState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOnline = prefs.getBool('rider_online') ?? false;
    // Sync with actual tracking state
    final actuallyRunning = _tracking.isRunning;
    final online = savedOnline || actuallyRunning;
    if (mounted) setState(() => _online = online);
    if (online) _load();
  }

  Future<void> _toggleOnline() async {
    if (_togglingOnline) return;
    setState(() => _togglingOnline = true);
    try {
      final newOnline = !_online;
      if (newOnline) {
        await _tracking.start();
        await _load();
      } else {
        await _tracking.stop();
        setState(() => _groups = []);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rider_online', newOnline);
      if (mounted) setState(() => _online = newOnline);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
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

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final groups = await _service.getAvailableGroups();
      if (mounted) setState(() { _groups = groups; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _accept(String groupId) async {
    setState(() => _accepting = groupId);
    try {
      await _service.acceptGroup(groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Grupo aceptado! Revisá "Mi Entrega"'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.delivery_dining, color: theme.colorScheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pedidos disponibles', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            _online ? 'Estás activo · compartiendo ubicación' : 'Estás offline',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _online ? Colors.green.shade600 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
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
                  const SizedBox(height: 14),
                  // Online/offline toggle
                  GestureDetector(
                    onTap: _toggleOnline,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: _online ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _online ? Colors.green.shade300 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_togglingOnline)
                            const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              _online ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                              color: _online ? Colors.green.shade700 : Colors.grey.shade600,
                              size: 20,
                            ),
                          const SizedBox(width: 10),
                          Text(
                            _online ? 'En línea — Toca para desconectarte' : 'Offline — Toca para activarte',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _online ? Colors.green.shade700 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: !_online
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_tethering_off, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Estás offline', style: TextStyle(color: Colors.grey[500], fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('Actívate para ver y aceptar pedidos', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : CustomScrollView(
                              slivers: [
                                if (_error != null)
                                  SliverFillRemaining(
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                          const SizedBox(height: 8),
                                          Text(_error!, textAlign: TextAlign.center),
                                          const SizedBox(height: 16),
                                          ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (_groups.isEmpty)
                                  SliverFillRemaining(
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                                          const SizedBox(height: 12),
                                          Text('No hay grupos disponibles', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                                          const SizedBox(height: 8),
                                          Text('Los pedidos se agrupan automáticamente', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  SliverPadding(
                                    padding: const EdgeInsets.all(16),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (_, i) => _GroupCard(
                                          group: _groups[i],
                                          accepting: _accepting == _groups[i].id,
                                          onAccept: () => _accept(_groups[i].id),
                                        ),
                                        childCount: _groups.length,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final RiderGroup group;
  final bool accepting;
  final VoidCallback onAccept;

  const _GroupCard({required this.group, required this.accepting, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${group.orderCount} pedido${group.orderCount != 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                const Spacer(),
                Text(_timeAgo(group.createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Recoger en:', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            ...group.orders.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.store_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(o.shopName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            const SizedBox(width: 6),
                            _PrepBadge(status: o.status),
                          ],
                        ),
                        Text(o.shopAddress, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            const Divider(height: 20),
            Text('Entregar a:', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            ...group.orders.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  Expanded(child: Text(o.clientAddress ?? 'Dirección no especificada', style: const TextStyle(fontSize: 13))),
                  Text('Bs ${o.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RiderMapPage(group: group))),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Ver ruta'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: accepting ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: accepting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Aceptar grupo', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return 'Hace ${diff.inHours}h';
  }
}

class _PrepBadge extends StatelessWidget {
  final String status;
  const _PrepBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = switch (status) {
      'listo'      => ('Listo', Icons.check_circle_outline, Colors.green.shade50,  Colors.green.shade700),
      'preparando' => ('Preparando', Icons.schedule, Colors.orange.shade50, Colors.orange.shade700),
      'confirmado' => ('Confirmado', Icons.thumb_up_outlined, Colors.blue.shade50,  Colors.blue.shade700),
      _            => ('Pendiente', Icons.hourglass_empty, Colors.grey.shade100, Colors.grey.shade600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
