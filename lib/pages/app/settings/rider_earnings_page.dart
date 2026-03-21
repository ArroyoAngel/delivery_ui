import 'package:flutter/material.dart';
import '../../../services/api_client.dart';

class RiderEarningsPage extends StatefulWidget {
  const RiderEarningsPage({super.key});

  @override
  State<RiderEarningsPage> createState() => _RiderEarningsPageState();
}

class _RiderEarningsPageState extends State<RiderEarningsPage> {
  final _api = ApiClient();

  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _withdrawals = [];
  List<Map<String, dynamic>> _bankAccounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _errorMessage;

  Future<void> _load() async {
    setState(() { _loading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        _api.get('/payments/rider/income'),
        _api.get('/payments/rider/withdrawals'),
        _api.get('/payments/rider/bank-accounts'),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = Map<String, dynamic>.from(results[0] as Map);
        _withdrawals = (results[1] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _bankAccounts = (results[2] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      debugPrint('[RiderEarnings] ApiException ${e.statusCode}: ${e.message}');
      if (!mounted) return;
      final msg = e.statusCode == 401
          ? 'Sesión expirada. Vuelve a iniciar sesión.'
          : e.statusCode == 403
              ? 'No tienes permiso para ver esta sección (403). Contacta al administrador.'
              : 'Error del servidor (${e.statusCode}): ${e.message}';
      setState(() { _loading = false; _errorMessage = msg; });
    } catch (e, st) {
      debugPrint('[RiderEarnings] Error inesperado: $e\n$st');
      if (!mounted) return;
      setState(() { _loading = false; _errorMessage = 'Error inesperado: $e'; });
    }
  }

  double get _available => double.tryParse(_summary?['available_balance']?.toString() ?? '0') ?? 0;

  void _showWithdrawalSheet() {
    if (_bankAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes agregar una cuenta bancaria antes de solicitar un retiro.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WithdrawalSheet(
        available: _available,
        bankAccounts: _bankAccounts,
        onSuccess: () {
          Navigator.pop(context);
          _load();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Retiro solicitado correctamente'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis ingresos'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Tarjetas de saldo ──
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Total ganado',
                          value: 'Bs ${double.tryParse(_summary?['total_earned']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                          icon: Icons.trending_up,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Disponible',
                          value: 'Bs ${_available.toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet_outlined,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    label: 'En proceso de retiro',
                    value: 'Bs ${double.tryParse(_summary?['pending_withdrawals_amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.pending_outlined,
                    color: Colors.orange,
                    wide: true,
                  ),

                  const SizedBox(height: 20),

                  // ── Botón solicitar retiro ──
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _available > 0 ? _showWithdrawalSheet : null,
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('Solicitar retiro'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Historial de retiros ──
                  Text(
                    'Historial de retiros',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_withdrawals.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aún no has solicitado retiros',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ...(_withdrawals.map((w) => _WithdrawalTile(w))),
                ],
              ),
            ),
    );
  }
}

// ── Tarjeta de resumen ─────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool wide;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
      child: wide
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 10),
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
              ],
            ),
    );
  }
}

// ── Fila de retiro ─────────────────────────────────────────────────────────────

class _WithdrawalTile extends StatelessWidget {
  final Map<String, dynamic> w;
  const _WithdrawalTile(this.w);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = w['status'] as String? ?? 'pending';
    final (label, color) = switch (status) {
      'completed' => ('Completado', Colors.green),
      'rejected'  => ('Rechazado', Colors.red),
      _           => ('Pendiente', Colors.orange),
    };

    final amount = double.tryParse(w['amount']?.toString() ?? '0') ?? 0;
    final bank = w['bank_name'] as String? ?? '—';
    final account = w['account_number'] as String? ?? '';
    final accountSuffix = account.length > 4 ? '···${account.substring(account.length - 4)}' : account;
    final dateStr = w['requested_at'] as String? ?? '';
    final date = dateStr.isNotEmpty
        ? (DateTime.tryParse(dateStr)?.toLocal().toString().substring(0, 10) ?? dateStr)
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bs ${amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$bank${accountSuffix.isNotEmpty ? ' — $accountSuffix' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ),
              const SizedBox(height: 4),
              Text(date, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet de solicitud ──────────────────────────────────────────────────

class _WithdrawalSheet extends StatefulWidget {
  final double available;
  final List<Map<String, dynamic>> bankAccounts;
  final VoidCallback onSuccess;

  const _WithdrawalSheet({
    required this.available,
    required this.bankAccounts,
    required this.onSuccess,
  });

  @override
  State<_WithdrawalSheet> createState() => _WithdrawalSheetState();
}

class _WithdrawalSheetState extends State<_WithdrawalSheet> {
  final _api = ApiClient();
  final _amountController = TextEditingController();
  String? _selectedAccountId;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Preseleccionar cuenta principal si existe
    final defaultAcc = widget.bankAccounts.firstWhere(
      (a) => a['is_default'] == true,
      orElse: () => widget.bankAccounts.first,
    );
    _selectedAccountId = defaultAcc['id'] as String?;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _error = null; });
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido');
      return;
    }
    if (amount > widget.available) {
      setState(() => _error = 'Máximo disponible: Bs ${widget.available.toStringAsFixed(2)}');
      return;
    }
    if (_selectedAccountId == null) {
      setState(() => _error = 'Selecciona una cuenta bancaria');
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.post('/payments/rider/withdrawal', {
        'amount': amount,
        'bankAccountId': _selectedAccountId,
      });
      widget.onSuccess();
    } catch (e) {
      final msg = e.toString().contains('Saldo insuficiente')
          ? 'Saldo insuficiente'
          : 'Error al solicitar retiro';
      if (mounted) setState(() { _error = msg; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solicitar retiro', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Saldo disponible: Bs ${widget.available.toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Monto
          Text('Monto (Bs)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Ej: 50.00',
              prefixText: 'Bs ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Cuenta bancaria
          Text('Cuenta bancaria', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedAccountId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: widget.bankAccounts.map((a) {
              final bank = a['bank_name'] as String? ?? '—';
              final num = a['account_number'] as String? ?? '';
              final suffix = num.length > 4 ? '···${num.substring(num.length - 4)}' : num;
              return DropdownMenuItem(
                value: a['id'] as String?,
                child: Text('$bank${suffix.isNotEmpty ? ' — $suffix' : ''}', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedAccountId = v),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Solicitar', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
