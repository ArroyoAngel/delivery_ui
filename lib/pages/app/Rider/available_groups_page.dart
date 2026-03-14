import 'package:flutter/material.dart';
import '../../../services/rider_service.dart';
import 'rider_map_page.dart';

class AvailableGroupsPage extends StatefulWidget {
  const AvailableGroupsPage({super.key});

  @override
  State<AvailableGroupsPage> createState() => _AvailableGroupsPageState();
}

class _AvailableGroupsPageState extends State<AvailableGroupsPage> {
  final _service = RiderService();
  List<RiderGroup> _groups = [];
  bool _loading = true;
  String? _error;
  String? _accepting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final groups = await _service.getAvailableGroups();
      setState(() { _groups = groups; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
              child: Row(
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
                      Text('Aceptá un grupo para empezar', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _load,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
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
                        )
                      : _groups.isEmpty
                          ? Center(
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
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _groups.length,
                                itemBuilder: (_, i) => _GroupCard(
                                  group: _groups[i],
                                  accepting: _accepting == _groups[i].id,
                                  onAccept: () => _accept(_groups[i].id),
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
            // Cabecera del grupo
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
                Text(
                  _timeAgo(group.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Restaurantes (puntos de recogida)
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
                            Expanded(
                              child: Text(o.restaurantName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            const SizedBox(width: 6),
                            _PrepBadge(status: o.status),
                          ],
                        ),
                        Text(o.restaurantAddress, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ],
              ),
            )),

            const Divider(height: 20),

            // Entregas (destinos)
            Text('Entregar a:', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            ...group.orders.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      o.clientAddress ?? 'Dirección no especificada',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    'Bs ${o.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RiderMapPage(group: group)),
                    ),
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
