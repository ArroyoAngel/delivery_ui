import 'package:flutter/material.dart';
import '../../../services/order_service.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _orderService = OrderService();
  late Future<DeliveryOrder> _future;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _future = _orderService.getOrder(widget.orderId);
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar pedido'),
        content: const Text('¿Estás seguro que deseas cancelar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await _orderService.cancelOrder(widget.orderId);
      if (mounted) {
        setState(() { _future = _orderService.getOrder(widget.orderId); });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del pedido'),
        centerTitle: true,
      ),
      body: FutureBuilder<DeliveryOrder>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          return _buildBody(snap.data!);
        },
      ),
    );
  }

  Widget _buildBody(DeliveryOrder order) {
    final theme = Theme.of(context);
    final (label, color) = _statusInfo(order.status);
    final canCancel = order.status == 'pendiente' || order.status == 'confirmado';

    final steps = _buildSteps(order.status, order.deliveryType);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha:0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.restaurantName ?? 'Restaurante',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Timeline
          Text('Seguimiento', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final isLast = i == steps.length - 1;
            return _StepTile(step: step, isLast: isLast);
          }),
          const SizedBox(height: 24),

          // Details
          Text('Detalles', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _DetailRow(label: 'Tipo', value: order.deliveryType == 'delivery' ? 'Delivery' : 'Recojo'),
          if (order.deliveryAddress != null)
            _DetailRow(label: 'Dirección', value: order.deliveryAddress!),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Envío', style: TextStyle(color: Colors.grey.shade600)),
              Text('Bs ${order.deliveryFee.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(
                'Bs ${order.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),

          if (canCancel) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isCancelling ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isCancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar pedido', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (String, Color) _statusInfo(String status) {
    switch (status) {
      case 'pendiente':
        return ('Pendiente', Colors.orange);
      case 'confirmado':
        return ('Confirmado', Colors.blue.shade700);
      case 'preparando':
        return ('Preparando', Colors.purple.shade700);
      case 'listo':
        return ('Listo para despacho', Colors.teal.shade600);
      case 'en_camino':
        return ('En camino', Colors.green.shade700);
      case 'entregado':
        return ('Entregado', Colors.grey);
      case 'cancelado':
        return ('Cancelado', Colors.red);
      default:
        return (status, Colors.orange);
    }
  }

  List<_Step> _buildSteps(String status, String deliveryType) {
    if (status == 'cancelado') {
      return [
        _Step(title: 'Pedido cancelado', done: true, active: false, icon: Icons.cancel),
      ];
    }
    final isDone = status == 'entregado';
    final inTransit = status == 'en_camino' || isDone;
    final isListo = status == 'listo' || inTransit;
    final isPreparing = status == 'preparando' || isListo;
    final isConfirmed = status == 'confirmado' || isPreparing;

    if (deliveryType == 'recogida') {
      return [
        _Step(title: 'Pedido realizado', done: true, active: status == 'pendiente', icon: Icons.receipt),
        _Step(title: 'Confirmado', done: isConfirmed, active: status == 'confirmado', icon: Icons.check_circle),
        _Step(title: 'Listo para recoger', done: isListo, active: status == 'listo' || status == 'preparando', icon: Icons.store),
      ];
    }

    return [
      _Step(title: 'Pedido realizado', done: true, active: status == 'pendiente', icon: Icons.receipt),
      _Step(title: 'Confirmado por restaurante', done: isConfirmed, active: status == 'confirmado', icon: Icons.restaurant),
      _Step(title: 'En preparación', done: isPreparing, active: status == 'preparando', icon: Icons.soup_kitchen),
      _Step(title: 'Listo para despacho', done: isListo, active: status == 'listo', icon: Icons.inventory_2),
      _Step(title: 'En camino', done: inTransit, active: status == 'en_camino', icon: Icons.delivery_dining),
      _Step(title: 'Entregado', done: isDone, active: isDone, icon: Icons.home),
    ];
  }
}

class _Step {
  final String title;
  final bool done;
  final bool active;
  final IconData icon;

  const _Step({
    required this.title,
    required this.done,
    required this.active,
    required this.icon,
  });
}

class _StepTile extends StatelessWidget {
  final _Step step;
  final bool isLast;

  const _StepTile({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color iconColor = step.done
        ? theme.colorScheme.primary
        : step.active
            ? theme.colorScheme.primary
            : Colors.grey.shade300;
    final Color lineColor = step.done ? theme.colorScheme.primary : Colors.grey.shade200;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: step.done ? theme.colorScheme.primary : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(step.icon, size: 18, color: step.done ? Colors.white : iconColor),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: lineColor),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            step.title,
            style: TextStyle(
              fontWeight: step.active ? FontWeight.w600 : FontWeight.normal,
              color: step.done ? theme.colorScheme.onSurface : Colors.grey.shade500,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value),
        ],
      ),
    );
  }
}
