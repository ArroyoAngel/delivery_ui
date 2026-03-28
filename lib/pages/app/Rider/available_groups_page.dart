import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/rider_service.dart';
import '../../../services/notification_api_service.dart';
import '../../../services/location_tracking_service.dart';
import '../../../services/socket_service.dart';
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
  final _socket = SocketService();
  List<RiderGroup> _groups = [];
  bool _loading = true;
  String? _error;
  String? _accepting;
  int _unreadCount = 0;
  bool _online = false;
  bool _togglingOnline = false;
  int _deliveriesToday = 0;
  double _earningsToday = 0.0;
  double _credits = 0.0;

  String? _deliveredEventName;

  @override
  void initState() {
    super.initState();
    _loadOnlineState();
    _loadUnreadCount();
    _loadTodayStats();
    _socket.on('group:new', (_) {
      if (_online && mounted) _load();
    });
    final accountId = AuthService().currentUser?.id;
    if (accountId != null) {
      _deliveredEventName = 'rider:order_delivered:$accountId';
      _socket.on(_deliveredEventName!, (_) {
        if (mounted) _loadTodayStats();
      });
    }
  }

  @override
  void dispose() {
    _socket.off('group:new');
    if (_deliveredEventName != null) _socket.off(_deliveredEventName!);
    super.dispose();
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
        _loadTodayStats(); // refresca créditos al ponerse online
      } else {
        await _tracking.stop();
        setState(() => _groups = []);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rider_online', newOnline);
      if (mounted) setState(() => _online = newOnline);
      // Notificar al backend en segundo plano — no bloquea el toggle
      _service.setAvailable(newOnline).catchError((e) {
        debugPrint('setAvailable error: $e');
      });
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

  Future<void> _loadTodayStats() async {
    try {
      final stats = await _service.getTodayStats();
      if (mounted) {
        setState(() {
          _deliveriesToday = (stats['deliveries_today'] as num).toInt();
          _earningsToday   = (stats['earnings_today']   as num).toDouble();
          _credits         = (stats['credits']           as num).toDouble();
        });
      }
    } catch (e, st) {
      debugPrint('[_loadTodayStats] ERROR: $e');
      debugPrint('[_loadTodayStats] STACK: $st');
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await _service.getAvailableGroups();
      if (mounted)
        setState(() {
          _groups = groups;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
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
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // ── Blue header ────────────────────────────────────────────────
          Container(
            color: AppColors.riderBlue,
            child: SafeArea(
              bottom: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.riderBlue,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(40),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
                child: Column(
                  children: [
                    // Top row
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'YaYa! Rider',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                user != null
                                    ? '${user.firstName} ${user.lastName}'
                                    : 'Rider',
                                style: TextStyle(
                                  color: Colors.blue.shade100,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Online/offline pill
                        GestureDetector(
                          onTap: _toggleOnline,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _online ? 'En línea' : 'Offline',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (_togglingOnline)
                                  const SizedBox(
                                    width: 8,
                                    height: 8,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _online
                                          ? const Color(0xFF4ADE80)
                                          : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                      boxShadow: _online
                                          ? [
                                              const BoxShadow(
                                                color: Color(0x664ADE80),
                                                blurRadius: 6,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Notification bell
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                              ),
                              onPressed: _openNotifications,
                            ),
                            if (_unreadCount > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: AppColors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.riderBlue,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Entregas Hoy',
                            value: '$_deliveriesToday',
                            icon: Icons.delivery_dining_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Ganancia Hoy',
                            value: 'Bs ${_earningsToday.toStringAsFixed(2)}',
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: !_online
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_tethering_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Estás offline',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Actívate para ver y aceptar pedidos',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _toggleOnline,
                          child: const Text('Activarme'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : CustomScrollView(
                            slivers: [
                              // Section title
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'DISPONIBLES AHORA (${_groups.length})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            letterSpacing: 1.5,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _load,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                                blurRadius: 4,
                                              ),
                                            ],
                                            border: Border.all(
                                              color: Colors.grey.shade100,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.refresh,
                                            size: 16,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_error != null)
                                SliverFillRemaining(
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          size: 48,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _error!,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _load,
                                          child: const Text('Reintentar'),
                                        ),
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
                                        Icon(
                                          Icons.inbox_outlined,
                                          size: 64,
                                          color: Colors.grey[300],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No hay grupos disponibles',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Los pedidos se agrupan automáticamente',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    24,
                                  ),
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
    );
  }
}

class _GroupCard extends StatelessWidget {
  final RiderGroup group;
  final bool accepting;
  final VoidCallback onAccept;

  const _GroupCard({
    required this.group,
    required this.accepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final payout = group.orders.fold<double>(0, (sum, o) => sum + o.total);
    final first = group.orders.isNotEmpty ? group.orders.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.riderBlue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFEFF4FF)),
      ),
      child: Stack(
        children: [
          // Decorative circle top-right
          Positioned(
            top: -28,
            right: -28,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF4FF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop + payout row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.orangeLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: AppColors.orange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            first?.shopName ?? 'Varios negocios',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _PrepBadge(status: first?.status ?? 'pendiente'),
                              if (group.orderCount > 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(
                                    '+${group.orderCount - 1} más',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Bs ${payout.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.riderBlue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Route line
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Dots + line
                      Column(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: Colors.grey.shade200,
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    first?.shopAddress ?? '—',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (first != null) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    first.shopRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    first?.clientAddress ??
                                        'Dirección no especificada',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                if (first != null) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    first.clientRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Buttons
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RiderMapPage(group: group),
                        ),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Ruta'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: accepting ? null : onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.riderBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: accepting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'ACEPTAR PEDIDO',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
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

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Color(0xFFBFDBFE),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFBFDBFE),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrepBadge extends StatelessWidget {
  final String status;
  const _PrepBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = switch (status) {
      'listo' => (
        'Listo',
        Icons.check_circle_outline,
        Colors.green.shade50,
        Colors.green.shade700,
      ),
      'preparando' => (
        'Preparando',
        Icons.schedule,
        Colors.orange.shade50,
        Colors.orange.shade700,
      ),
      'confirmado' => (
        'Confirmado',
        Icons.thumb_up_outlined,
        Colors.blue.shade50,
        Colors.blue.shade700,
      ),
      _ => (
        'Pendiente',
        Icons.hourglass_empty,
        Colors.grey.shade100,
        Colors.grey.shade600,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
