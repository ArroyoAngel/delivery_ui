import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import '../../../services/order_service.dart';
import '../../../services/cart_service.dart';

class PaymentPage extends StatefulWidget {
  /// Para órdenes simples. Mutuamente excluyente con [groupId].
  final String? orderId;
  /// Para checkout express multi-restaurante.
  final String? groupId;
  final double amount;
  final String restaurantName;

  const PaymentPage({
    super.key,
    this.orderId,
    this.groupId,
    required this.amount,
    required this.restaurantName,
  }) : assert(orderId != null || groupId != null);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _orderService = OrderService();
  bool _verifying = false;
  bool _saving = false;

  Future<void> _saveQr() async {
    setState(() => _saving = true);
    try {
      final bytes = await rootBundle.load('assets/qr_bnb.jpg');
      await Gal.putImageBytes(
        bytes.buffer.asUint8List(),
        name: 'pago_bnb_${(widget.groupId ?? widget.orderId!).substring(0, 8)}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR guardado en tu galería')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _verifyPayment() async {
    setState(() => _verifying = true);
    try {
      final status = widget.groupId != null
          ? await _orderService.checkGroupPaymentStatus(widget.groupId!)
          : await _orderService.checkPaymentStatus(widget.orderId!);
      if (!mounted) return;
      if (status == 'pagado' ||
          status == 'confirmado' ||
          status == 'preparando' ||
          status == 'en_camino' ||
          status == 'entregado') {
        CartService().clear();
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago confirmado. Tu pedido está en proceso.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago aún no confirmado. Intenta en unos momentos.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al verificar: $e')),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Realizar Pago'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Amount banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total a pagar',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bs ${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.restaurantName,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bank info
              _InfoCard(children: [
                _BankRow(label: 'Banco', value: 'Banco Nacional de Bolivia (BNB)'),
                const Divider(height: 16),
                _BankRow(
                  label: 'N° de cuenta',
                  value: '1234567890',
                  copyable: true,
                ),
                const Divider(height: 16),
                _BankRow(label: 'A nombre de', value: 'YaYa Eats SRL'),
                const Divider(height: 16),
                _BankRow(
                  label: 'Referencia',
                  value: (widget.groupId ?? widget.orderId!).substring(0, 8).toUpperCase(),
                  copyable: true,
                ),
              ]),
              const SizedBox(height: 20),

              // QR
              Text(
                'Escanea el QR con tu app bancaria',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/qr_bnb.jpg',
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 220,
                      height: 220,
                      color: Colors.grey.shade100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('QR no disponible',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _saving ? null : _saveQr,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(_saving ? 'Guardando...' : 'Guardar QR en galería'),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verifyPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Ya pagué — Verificar',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Una vez que realices la transferencia, pulsa el botón para confirmar.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _BankRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  const _BankRow({required this.label, required this.value, this.copyable = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        Row(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (copyable) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copiado'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Icon(Icons.copy_outlined, size: 14, color: theme.colorScheme.primary),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
