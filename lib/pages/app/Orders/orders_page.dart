import 'package:flutter/material.dart';
import '../../../services/order_service.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _orderService = OrderService();
  late Future<List<DeliveryOrder>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() { _future = _orderService.getOrders(); });
  }

  (String, Color) _statusInfo(String status, ThemeData theme) {
    switch (status) {
      case 'pendiente':
        return ('Pendiente', Colors.orange.shade700);
      case 'confirmado':
        return ('Confirmado', Colors.blue.shade700);
      case 'preparando':
        return ('Preparando', Colors.purple.shade700);
      case 'en_camino':
        return ('En camino', theme.colorScheme.primary);
      case 'entregado':
        return ('Entregado', Colors.grey);
      case 'cancelado':
        return ('Cancelado', Colors.red);
      default:
        return (status, Colors.orange.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Mis Pedidos',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<DeliveryOrder>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return RefreshIndicator(
                    onRefresh: () async => _load(),
                    child: ListView(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('Error al cargar pedidos',
                                    style: TextStyle(color: Colors.grey.shade600)),
                                const SizedBox(height: 12),
                                TextButton(onPressed: _load, child: const Text('Reintentar')),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final orders = snap.data ?? [];
                if (orders.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => _load(),
                    child: ListView(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(60),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'No tienes pedidos aún',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Pide tu primera comida desde la pantalla de inicio',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      final (label, color) = _statusInfo(order.status, theme);
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailPage(orderId: order.id),
                          ),
                        ).then((_) => _load()),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha:0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.delivery_dining,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.restaurantName ?? 'Restaurante',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Bs ${order.total.toStringAsFixed(2)} · ${order.deliveryType == 'delivery' ? 'Delivery' : 'Recojo'}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha:0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}
