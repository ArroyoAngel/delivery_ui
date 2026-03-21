import 'package:flutter/material.dart';
import '../../../services/api_client.dart';

class RiderBankAccountsPage extends StatefulWidget {
  const RiderBankAccountsPage({super.key});

  @override
  State<RiderBankAccountsPage> createState() => _RiderBankAccountsPageState();
}

class _RiderBankAccountsPageState extends State<RiderBankAccountsPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/payments/rider/bank-accounts') as List;
      if (mounted) {
        setState(() {
          _accounts = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar cuenta'),
        content: const Text('¿Estás seguro que deseas eliminar esta cuenta bancaria?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/payments/rider/bank-accounts/$id');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddAccountSheet(onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Cuentas bancarias'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddSheet,
            tooltip: 'Agregar cuenta',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Sin cuentas bancarias', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Agrega una para solicitar retiros', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _openAddSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar cuenta'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final acc = _accounts[i];
                      final isDefault = acc['is_default'] == true;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isDefault
                              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                              : Border.all(color: Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.account_balance, color: theme.colorScheme.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          acc['bank_name'] ?? '—',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                      ),
                                      if (isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'Principal',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    acc['account_holder'] ?? '',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    acc['account_number'] ?? '',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                                  ),
                                  if (acc['account_type'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(acc['account_type'], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _delete(acc['id'] as String),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Bottom sheet para agregar cuenta ───────────────────────────────────────────

class _AddAccountSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddAccountSheet({required this.onSaved});

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _bankCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  bool _isDefault = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _bankCtrl.dispose();
    _holderCtrl.dispose();
    _numberCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await _api.post('/payments/rider/bank-accounts', {
        'bankName': _bankCtrl.text.trim(),
        'accountHolder': _holderCtrl.text.trim(),
        'accountNumber': _numberCtrl.text.trim(),
        'accountType': _typeCtrl.text.trim().isNotEmpty ? _typeCtrl.text.trim() : null,
        'isDefault': _isDefault,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nueva cuenta bancaria', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _Field(controller: _bankCtrl, label: 'Banco', hint: 'Ej. BNB, Banco Unión'),
            const SizedBox(height: 12),
            _Field(controller: _holderCtrl, label: 'Titular de la cuenta'),
            const SizedBox(height: 12),
            _Field(controller: _numberCtrl, label: 'Número de cuenta', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _Field(controller: _typeCtrl, label: 'Tipo de cuenta (opcional)', hint: 'Ahorro / Corriente', required: false),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              title: const Text('Cuenta principal', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar cuenta', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool required;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null : null,
    );
  }
}
