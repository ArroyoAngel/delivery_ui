import 'package:flutter/material.dart';
import '../../../services/rider_service.dart';
import 'rider_map_page.dart';

class ActiveDeliveryPage extends StatefulWidget {
  const ActiveDeliveryPage({super.key});

  @override
  State<ActiveDeliveryPage> createState() => _ActiveDeliveryPageState();
}

class _ActiveDeliveryPageState extends State<ActiveDeliveryPage> {
  final _service = RiderService();
  RiderGroup? _group;
  bool _loading = true;
  String? _error;
  final Set<String> _delivering = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final group = await _service.getMyActiveGroup();
      setState(() { _group = group; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _markDelivered(String orderId) async {
    setState(() => _delivering.add(orderId));
    try {
      await _service.markOrderDelivered(orderId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido entregado!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _delivering.remove(orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_group == null || _group!.status == 'completed') {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_group?.status == 'completed') ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, size: 80, color: Colors.green),
                  ),
                  const SizedBox(height: 20),
                  Text('¡Entrega completada!', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Todos los pedidos fueron entregados', style: TextStyle(color: Colors.grey[500])),
                ] else ...[
                  Icon(Icons.motorcycle_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text('Sin entrega activa', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Aceptá un grupo en "Disponibles"', style: TextStyle(color: Colors.grey[500])),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final orders = _group!.orders;
    final pending = orders.where((o) => o.status != 'entregado').toList();
    final done = orders.where((o) => o.status == 'entregado').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header con progreso
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.motorcycle, color: theme.colorScheme.primary, size: 24),
                      const SizedBox(width: 10),
                      Text('Mi entrega activa', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.map_outlined, color: theme.colorScheme.primary),
                        tooltip: 'Ver ruta',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiderMapPage(group: _group!),
                          ),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('${done.length}/${orders.length} entregados', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: orders.isEmpty ? 0 : done.length / orders.length,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Pendientes
                    if (pending.isNotEmpty) ...[
                      Text('Por entregar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      ...pending.map((o) => _StopCard(
                        stop: o,
                        delivering: _delivering.contains(o.orderId),
                        onMarkDelivered: () => _markDelivered(o.orderId),
                      )),
                      const SizedBox(height: 16),
                    ],

                    // Completados
                    if (done.isNotEmpty) ...[
                      Text('Entregados', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      ...done.map((o) => _StopCard(stop: o, delivered: true)),
                    ],
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

class _StopCard extends StatelessWidget {
  final RiderOrderStop stop;
  final bool delivering;
  final bool delivered;
  final VoidCallback? onMarkDelivered;

  const _StopCard({
    required this.stop,
    this.delivering = false,
    this.delivered = false,
    this.onMarkDelivered,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: delivered ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Paso 1: Recoger
            _StepRow(
              icon: Icons.store_outlined,
              iconColor: theme.colorScheme.primary,
              label: 'Recoger en',
              title: stop.restaurantName,
              subtitle: stop.restaurantAddress,
            ),
            const Padding(
              padding: EdgeInsets.only(left: 11),
              child: SizedBox(height: 20, child: VerticalDivider(width: 2, thickness: 2, color: Color(0xFFE0E0E0))),
            ),
            // Paso 2: Entregar
            _StepRow(
              icon: Icons.location_on_outlined,
              iconColor: Colors.orange,
              label: 'Entregar a',
              title: stop.clientAddress ?? 'Sin dirección especificada',
            ),

            // Items del pedido
            if (stop.items.isNotEmpty) ...[
              const Divider(height: 16),
              Text('Items:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              ...stop.items.map((item) => Text(
                '${item['quantity']}x ${item['item_name']}',
                style: const TextStyle(fontSize: 13),
              )),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Text(
                  'Total: Bs ${stop.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (delivered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text('Entregado', style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: delivering ? null : onMarkDelivered,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: delivering
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Entregado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String title;
  final String? subtitle;

  const _StepRow({required this.icon, required this.iconColor, required this.label, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
      ],
    );
  }
}
