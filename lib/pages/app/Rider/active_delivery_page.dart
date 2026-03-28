import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../services/rider_service.dart';
import '../ratings/rating_sheet.dart';
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
  final Set<String> _pickingUp = {};
  final Set<String> _cancelling = {};

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

  Future<void> _showCancelDialog(String orderId, String shopName) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pedido de $shopName', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('¿Por qué cancelás este pedido?'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Ej: Producto agotado, no pude llegar...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Atrás')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final reason = controller.text.trim();
    setState(() => _cancelling.add(orderId));
    try {
      await _service.cancelOrder(orderId, reason);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido cancelado. El cliente fue notificado.'),
            backgroundColor: Colors.orange,
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
      if (mounted) setState(() => _cancelling.remove(orderId));
    }
  }

  Future<void> _markPickedUp(String orderId) async {
    setState(() => _pickingUp.add(orderId));
    try {
      await _service.markOrderPickedUp(orderId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Pedido recogido! Ahora podés entregarlo.'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[_markPickedUp] ERROR: $e');
      debugPrint('[_markPickedUp] STACK: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingUp.remove(orderId));
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
        // Ofrecer calificar al cliente
        await showRatingSheet(context, orderId);
      }
    } catch (e, st) {
      final code = e is ApiException ? e.statusCode : '?';
      debugPrint('[_markDelivered] ERROR $code: $e');
      debugPrint('[_markDelivered] STACK: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('[$code] ${e.toString()}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
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
    final toPickup  = orders.where((o) => o.status == 'listo').toList();
    final waiting   = orders.where((o) => ['confirmado', 'preparando'].contains(o.status)).toList();
    final toDeliver = orders.where((o) => o.status == 'en_camino').toList();
    final done      = orders.where((o) => o.status == 'entregado').toList();

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
                    // Esperando que el restaurante termine (preparando/confirmado)
                    if (waiting.isNotEmpty) ...[
                      Text('Esperando restaurante', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      ...waiting.map((o) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.orange.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o.shopName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text(
                                      o.status == 'preparando' ? 'Preparando tu pedido...' : 'Confirmado, esperando inicio',
                                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],

                    // Por recoger (listo) — deslizá para confirmar recogida
                    if (toPickup.isNotEmpty) ...[
                      Text('Por recoger', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text(
                        'Deslizá la tarjeta  →  para confirmar que recogiste el pedido',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      ...toPickup.map((o) => _PickupCard(
                        key: ValueKey(o.orderId),
                        stop: o,
                        pickingUp: _pickingUp.contains(o.orderId),
                        cancelling: _cancelling.contains(o.orderId),
                        onPickedUp: () => _markPickedUp(o.orderId),
                        onCancel: () => _showCancelDialog(o.orderId, o.shopName),
                      )),
                      const SizedBox(height: 16),
                    ],

                    // Por entregar (en_camino)
                    if (toDeliver.isNotEmpty) ...[
                      Text('Por entregar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      ...toDeliver.map((o) => _StopCard(
                        stop: o,
                        delivering: _delivering.contains(o.orderId),
                        cancelling: _cancelling.contains(o.orderId),
                        onMarkDelivered: () => _markDelivered(o.orderId),
                        onCancel: () => _showCancelDialog(o.orderId, o.shopName),
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

// Tarjeta de recogida — deslizá a la derecha para confirmar
class _PickupCard extends StatelessWidget {
  final RiderOrderStop stop;
  final bool pickingUp;
  final bool cancelling;
  final VoidCallback onPickedUp;
  final VoidCallback onCancel;

  const _PickupCard({
    super.key,
    required this.stop,
    required this.pickingUp,
    required this.onPickedUp,
    required this.onCancel,
    this.cancelling = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('pickup_${stop.orderId}'),
      direction: pickingUp ? DismissDirection.none : DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onPickedUp();
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade600,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          children: [
            Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Recogido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.store, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stop.shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(stop.shopAddress, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ],
              ),
              if (stop.hasSpecialInstructions) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stop.riderInstructions!,
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (stop.items.isNotEmpty) ...[
                const Divider(height: 14),
                ...stop.items.map((item) => Text(
                  '${item['quantity']}x ${item['item_name']}',
                  style: const TextStyle(fontSize: 13),
                )),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Total: Bs ${stop.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  IconButton(
                    onPressed: (pickingUp || cancelling) ? null : onCancel,
                    icon: cancelling
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.cancel_outlined, color: Colors.red),
                    tooltip: 'Cancelar pedido',
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: (pickingUp || cancelling) ? null : onPickedUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: pickingUp
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: Text(pickingUp ? 'Recogiendo...' : 'Recoger', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final RiderOrderStop stop;
  final bool delivering;
  final bool delivered;
  final bool cancelling;
  final VoidCallback? onMarkDelivered;
  final VoidCallback? onCancel;

  const _StopCard({
    required this.stop,
    this.delivering = false,
    this.delivered = false,
    this.cancelling = false,
    this.onMarkDelivered,
    this.onCancel,
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
              label: 'Recogido en',
              title: stop.shopName,
              subtitle: stop.shopAddress,
              rating: stop.shopRating,
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
              rating: stop.clientRating,
            ),

            // Banner instrucciones especiales (negocio sin membresía)
            if (stop.hasSpecialInstructions) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stop.riderInstructions!,
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                else ...[
                  IconButton(
                    onPressed: (delivering || cancelling) ? null : onCancel,
                    icon: cancelling
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Icon(Icons.cancel_outlined, color: Colors.red),
                    tooltip: 'Cancelar pedido',
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: (delivering || cancelling) ? null : onMarkDelivered,
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
  final double rating;

  const _StepRow({required this.icon, required this.iconColor, required this.label, required this.title, this.subtitle, this.rating = 5.0});

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
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 2),
                  Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                ],
              ),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
      ],
    );
  }
}
