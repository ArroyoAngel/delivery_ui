import 'package:flutter/material.dart';
import '../../../services/api_client.dart';

class SupportTicketPage extends StatefulWidget {
  const SupportTicketPage({super.key});

  @override
  State<SupportTicketPage> createState() => _SupportTicketPageState();
}

class _SupportTicketPageState extends State<SupportTicketPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/support/tickets') as List;
      if (mounted) {
        setState(() {
          _tickets = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openNewTicket() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NewTicketSheet(onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Ayuda y soporte'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _openNewTicket,
            tooltip: 'Nuevo reclamo',
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo
          Container(
            width: double.infinity,
            color: theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              children: [
                Icon(Icons.support_agent_outlined, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Tenés un problema?',
                        style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                      ),
                      Text(
                        'Enviá un ticket y nuestro equipo te responderá.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _openNewTicket,
                  child: const Text('Nuevo'),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tickets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Sin tickets', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('Tus reclamos aparecerán aquí', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _tickets.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _TicketCard(ticket: _tickets[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de ticket ──────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _TicketCard({required this.ticket});

  static const _statusLabel = {
    'open': 'Abierto',
    'in_progress': 'En revisión',
    'resolved': 'Resuelto',
    'closed': 'Cerrado',
  };

  static const _statusColor = {
    'open': Color(0xFFFFF3CD),
    'in_progress': Color(0xFFCCE5FF),
    'resolved': Color(0xFFD4EDDA),
    'closed': Color(0xFFF0F0F0),
  };

  static const _statusTextColor = {
    'open': Color(0xFF856404),
    'in_progress': Color(0xFF004085),
    'resolved': Color(0xFF155724),
    'closed': Color(0xFF6C757D),
  };

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] as String? ?? 'open';
    final hasNotes = (ticket['admin_notes'] as String?)?.isNotEmpty == true;
    final createdAt = DateTime.tryParse(ticket['created_at'] as String? ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket['subject'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor[status] ?? const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel[status] ?? status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusTextColor[status] ?? Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ticket['message'] as String? ?? '',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasNotes) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.support_agent_outlined, size: 16, color: Color(0xFF0369A1)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ticket['admin_notes'] as String,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              createdAt.toLocal().toString().substring(0, 16),
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bottom sheet nuevo ticket ──────────────────────────────────────────────────

class _NewTicketSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _NewTicketSheet({required this.onSaved});

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await _api.post('/support/tickets', {
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket enviado. Te responderemos pronto.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
            const Text('Nuevo ticket de soporte', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Describí tu problema y te contactaremos.', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectCtrl,
              decoration: InputDecoration(
                labelText: 'Asunto',
                hintText: 'Ej. Problema con un pedido',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Describí tu problema con detalle...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().length < 10) ? 'Escribe al menos 10 caracteres' : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _send,
                icon: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined, size: 18),
                label: const Text('Enviar ticket', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
