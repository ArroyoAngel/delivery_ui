import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../services/credit_service.dart';
import '../../../services/socket_service.dart';

class RiderCreditsPage extends StatefulWidget {
  const RiderCreditsPage({super.key});

  @override
  State<RiderCreditsPage> createState() => _RiderCreditsPageState();
}

class _RiderCreditsPageState extends State<RiderCreditsPage> {
  final _service = CreditService();

  late Future<Map<String, dynamic>> _balanceFuture;
  late Future<List<CreditPackage>> _packagesFuture;
  late Future<List<CreditPurchase>> _historyFuture;
  String _riderCode = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _balanceFuture = _service.getMyBalanceFull().then((data) {
      if (mounted)
        setState(() => _riderCode = data['riderCode'] as String? ?? '');
      return data;
    });
    _packagesFuture = _service.getPackages();
    _historyFuture = _service.getMyHistory();
  }

  void _showPurchaseSheet(CreditPackage pkg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PurchaseSheet(
        pkg: pkg,
        riderCode: _riderCode,
        onConfirmed: () => setState(_reload),
      ),
    );
  }

  Future<void> _resumePurchase(CreditPurchase purchase) async {
    // Buscar el paquete para usar su QR propio si tiene, si no el general
    String? staticQrUrl;
    try {
      final packages = await _packagesFuture;
      final pkg = packages.firstWhere(
        (p) => p.name == purchase.packageName,
        orElse: () => packages.first,
      );
      staticQrUrl = pkg.qrImageUrl ?? await _service.getStaticQrUrl();
    } catch (_) {
      staticQrUrl = await _service.getStaticQrUrl();
    }
    print('[RiderCreditsPage] _resumePurchase staticQrUrl="$staticQrUrl"');
    if (!mounted) return;
    final claim = ClaimResult(
      purchaseId: purchase.id,
      reference: purchase.paymentReference,
      bnbQrImage: purchase.bnbQrImage,
      staticQrUrl: staticQrUrl,
      useBnb: purchase.bnbQrImage != null,
      packageName: purchase.packageName,
      amount: purchase.amountPaid,
      creditsGranted: purchase.creditsGranted,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PurchaseSheet(
        riderCode: _riderCode,
        onConfirmed: () => setState(_reload),
        initialClaim: claim,
        initialProofSent: purchase.hasProof,
      ),
    );
  }

  Future<void> _resumeRejectedPurchase(CreditPurchase purchase) async {
    final staticQrUrl = await _service.getStaticQrUrl();
    print('[RiderCreditsPage] _resumeRejectedPurchase staticQrUrl="$staticQrUrl"');
    if (!mounted) return;

    final claim = ClaimResult(
      purchaseId: purchase.id,
      reference: purchase.paymentReference,
      bnbQrImage: purchase.bnbQrImage,
      staticQrUrl: staticQrUrl,
      useBnb: purchase.bnbQrImage != null,
      packageName: purchase.packageName,
      amount: purchase.amountPaid,
      creditsGranted: purchase.creditsGranted,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PurchaseSheet(
        riderCode: _riderCode,
        onConfirmed: () => setState(_reload),
        initialClaim: claim,
        initialProofSent: purchase.hasProof,
        // PASAR ESTO:
        initialRejected: purchase.isRejected,
        rejectionReason: purchase
            .rejectionReason, // Asegúrate que este campo existe en tu modelo
      ),
    );
  }

  Future<void> _cancelPurchase(CreditPurchase purchase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar compra'),
        content: const Text(
          '¿Seguro que querés cancelar esta compra pendiente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.cancelPurchase(purchase.id);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Créditos',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance card
            FutureBuilder<Map<String, dynamic>>(
              future: _balanceFuture,
              builder: (_, snap) {
                final balance = snap.data?['balance'] as int? ?? 0;
                final loading = snap.connectionState == ConnectionState.waiting;
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: balance == 0
                          ? [Colors.red.shade600, Colors.red.shade800]
                          : balance <= 5
                          ? [Colors.orange.shade500, Colors.orange.shade700]
                          : [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Balance disponible',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      loading
                          ? const SizedBox(
                              height: 44,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              '$balance créditos',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                      const SizedBox(height: 6),
                      Text(
                        balance == 0
                            ? '⚠️ Sin créditos — no podrás aceptar pedidos'
                            : '1 crédito = 1 entrega aceptada',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Packages
            Text(
              'Comprar créditos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Paga con QR del BNB. Los créditos se acreditan automáticamente.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<CreditPackage>>(
              future: _packagesFuture,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final packages = snap.data ?? [];
                return Column(
                  children: packages
                      .map(
                        (pkg) => _PackageCard(
                          pkg: pkg,
                          onTap: () => _showPurchaseSheet(pkg),
                        ),
                      )
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // History
            Text(
              'Historial de compras',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<CreditPurchase>>(
              future: _historyFuture,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final history = snap.data ?? [];
                if (history.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Sin compras aún',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  );
                }
                return Column(
                  children: history
                      .map(
                        (p) => _HistoryTile(
                          purchase: p,
                          onResume: p.isPending
                              ? () => _resumePurchase(p)
                              : null,
                          onResumeReject: p.isRejected
                              ? () => _resumeRejectedPurchase(p)
                              : null,
                          onCancel: p.isPending
                              ? () => _cancelPurchase(p)
                              : null,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Package Card ──────────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  final CreditPackage pkg;
  final VoidCallback onTap;

  const _PackageCard({required this.pkg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.toll_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      children: [
                        TextSpan(text: '${pkg.credits} créditos'),
                        if (pkg.bonusCredits > 0)
                          TextSpan(
                            text: ' + ${pkg.bonusCredits} bonus',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Bs ${pkg.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Comprar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Tile ──────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final CreditPurchase purchase;
  final VoidCallback? onCancel;
  final VoidCallback? onResume;
  final VoidCallback? onResumeReject;

  const _HistoryTile({
    required this.purchase,
    this.onCancel,
    this.onResume,
    this.onResumeReject,
  });

  IconData get _icon {
    switch (purchase.status) {
      case 'confirmed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'rejected':
        return Icons.dangerous_outlined;
      case 'expired':
        return Icons.timer_off_outlined;
      default:
        return Icons.pending_outlined;
    }
  }

  Color _iconColor(BuildContext context) {
    switch (purchase.status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
      case 'expired':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (purchase.status) {
      case 'confirmed':
        return 'Confirmado';
      case 'cancelled':
        return 'Cancelado';
      case 'rejected':
        return 'Rechazado';
      case 'expired':
        return 'Expirado';
      default:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _iconColor(context), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${purchase.creditsGranted} créditos — ${purchase.packageName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Bs ${purchase.amountPaid.toStringAsFixed(0)} · $_statusLabel',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (onResume != null)
            TextButton(
              onPressed: onResume,
              style: TextButton.styleFrom(
                foregroundColor: purchase.hasProof
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                purchase.hasProof ? 'Comprobante enviado' : 'Continuar',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (onResumeReject != null)
            TextButton(
              onPressed: onResumeReject,
              style: TextButton.styleFrom(
                foregroundColor: purchase.hasProof
                    ? Colors.red.shade700
                    : Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                purchase.hasProof ? 'Comprobante Rechazado' : 'Continuar',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ── Purchase Bottom Sheet ─────────────────────────────────────────────────────
// Paso 0: Confirmación previa
// Paso 1: Cargando (llamada al backend)
// Paso 2: Mostrando QR de BNB + esperando pago automático
// Paso 3: Éxito

class _PurchaseSheet extends StatefulWidget {
  final CreditPackage? pkg;
  final String riderCode;
  final VoidCallback onConfirmed;
  final ClaimResult? initialClaim;
  final bool initialProofSent;
  final bool initialRejected;
  final String? rejectionReason;

  const _PurchaseSheet({
    this.pkg,
    required this.riderCode,
    required this.onConfirmed,
    this.initialClaim,
    this.initialProofSent = false,
    this.initialRejected = false, // Ahora sí reconocerá este campo
    this.rejectionReason, // Y este también
  });

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  final _service = CreditService();
  final _socket = SocketService();

  int _step =
      0; // 0=pre-confirm, 1=loading, 2=qr+waiting, 3=success, 4=rejected
  String? _error;
  String? _rejectionReason;
  ClaimResult? _claim;
  int _newBalance = 0;

  // Estado para el flujo de QR estático + comprobante
  bool _savingQr = false;
  XFile? _proofFile;
  bool _proofUploading = false;
  bool _proofSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialClaim != null) {
      _claim = widget.initialClaim;
      _proofSent = widget.initialProofSent;

      // Forzamos la asignación independientemente de cualquier otra condición
      _rejectionReason = widget.rejectionReason;

      if (widget.initialRejected) {
        _step = 4;
      } else {
        _step = 2;
        _subscribeToConfirm(_claim!.purchaseId);
      }
    }
  }

  void _subscribeToConfirm(String purchaseId) {
    // Log para confirmar que la suscripción se activó
    print('Subscribing to sockets for purchase: $purchaseId');

    _socket.on('credit:confirmed:$purchaseId', (data) {
      // Log del objeto recibido al confirmar
      print('SOCKET CONFIRMED RECEIVED: $data');

      if (mounted) {
        setState(() {
          _newBalance =
              (data as Map<String, dynamic>?)?['balance'] as int? ?? 0;
          _step = 3;
        });
        widget.onConfirmed();
      }
    });

    _socket.on('credit:rejected:$purchaseId', (data) {
      // Log del objeto recibido al rechazar
      print('SOCKET REJECTED RECEIVED: $data');

      if (mounted) {
        setState(() {
          _step = 4;
          // Si el log muestra que el campo no se llama 'reason', cámbialo aquí
          _rejectionReason = (data as Map<String, dynamic>?)?['reason'];
        });
      }
    });
  }

  @override
  void dispose() {
    if (_claim != null) {
      _socket.off('credit:confirmed:${_claim!.purchaseId}');
      _socket.off('credit:rejected:${_claim!.purchaseId}');
    }
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _step = 1;
      _error = null;
    });
    try {
      final result = await _service.claimPurchase(widget.pkg!.id);
      _claim = result;
      _subscribeToConfirm(result.purchaseId);

      if (mounted) {
        setState(() => _step = 2);
        widget
            .onConfirmed(); // Recargar historial: ya hay un registro pendiente en la DB
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e);
          _step = 0;
        });
      }
    }

    Future<void> _showRejected() async {
      setState(() {
        _step = 1;
        _error = null;
      });
      try {
        final result = await _service.claimPurchase(widget.pkg!.id);
        _claim = result;
        _subscribeToConfirm(result.purchaseId);

        if (mounted) {
          setState(() => _step = 4);
          widget
              .onConfirmed(); // Recargar historial: ya hay un registro pendiente en la DB
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = _friendlyError(e);
            _step = 0;
          });
        }
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('pendiente'))
      return 'Ya tenés una compra pendiente. Cancelala desde tu historial.';
    return msg;
  }

  Future<void> _saveQrToGallery() async {
    setState(() => _savingQr = true);
    try {
      final res = await http.get(Uri.parse(_claim!.staticQrUrl!));
      await Gal.putImageBytes(res.bodyBytes, name: 'qr_yaya_eats');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR guardado en galería'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el QR'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingQr = false);
    }
  }

  Future<void> _pickProof() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _proofFile = file);
  }

  Future<void> _submitProof() async {
    if (_proofFile == null || _claim == null) return;
    setState(() => _proofUploading = true);
    try {
      await _service.submitProof(_claim!.purchaseId, _proofFile!.path);
      if (mounted) {
        setState(() {
          _proofSent = true;
          _proofUploading = false;
        });
        widget.onConfirmed(); // recarga historial en la página padre
      }
    } catch (e) {
      if (mounted) {
        setState(() => _proofUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ..._buildStep(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStep(ThemeData theme) {
    switch (_step) {
      case 0:
        return _buildPreConfirm(theme);
      case 1:
        return _buildLoading();
      case 2:
        return _buildQr(theme);
      case 3:
        return _buildSuccess(theme);
      case 4:
        return _buildRejected(theme);
      default:
        return [];
    }
  }

  // ── Paso 0: Pre-confirmación ──────────────────────────────────────────────

  List<Widget> _buildPreConfirm(ThemeData theme) => [
    Text(
      widget.pkg!.name,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 4),
    Text(
      '${widget.pkg!.totalCredits} créditos · Bs ${widget.pkg!.price.toStringAsFixed(0)}',
      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
    ),
    const SizedBox(height: 20),

    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                '¿Cómo funciona?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Step(
            number: '1',
            text: 'Al confirmar, se muestra el QR de pago de la plataforma.',
          ),
          _Step(
            number: '2',
            text:
                'Escaneá el QR con tu app bancaria y realizá el pago indicando tu referencia.',
          ),
          _Step(
            number: '3',
            text:
                'Los créditos se acreditan automáticamente al confirmar el banco.',
          ),
          _Step(
            number: '4',
            text: 'El pago fue rechazado, revisa los motivos.',
          ),
        ],
      ),
    ),

    if (_error != null) ...[
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
    ],

    const SizedBox(height: 20),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _confirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Confirmar y ver QR',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),
  ];

  // ── Paso 1: Cargando ──────────────────────────────────────────────────────

  List<Widget> _buildLoading() => [
    const SizedBox(height: 40),
    Center(
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Generando QR de pago...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    ),
    const SizedBox(height: 40),
  ];

  // ── Paso 2: QR + Esperar ──────────────────────────────────────────────────

  List<Widget> _buildQr(ThemeData theme) {
    final claim = _claim!;
    if (claim.staticQrUrl != null) return _buildStaticQr(theme, claim);
    return _buildBnbQr(theme, claim);
  }

  // ── Paso 2a: QR estático + comprobante ────────────────────────────────────

  List<Widget> _buildStaticQr(ThemeData theme, ClaimResult claim) {
    print('[RiderCreditsPage] _buildStaticQr → Image.network url="${claim.staticQrUrl}"');
    return [
      Text(
        'Escaneá y pagá',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        'Bs ${claim.amount.toStringAsFixed(0)} · ${claim.creditsGranted} créditos',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      const SizedBox(height: 16),

      // QR estático
      Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              claim.staticQrUrl!,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 200,
                height: 200,
                alignment: Alignment.center,
                child: Text(
                  'No se pudo cargar el QR',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),

      // Guardar QR en galería
      Center(
        child: TextButton.icon(
          onPressed: _savingQr ? null : _saveQrToGallery,
          icon: _savingQr
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 16),
          label: const Text(
            'Guardar QR en galería',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
      const SizedBox(height: 8),

      // Referencia
      _ReferenceBox(reference: claim.reference),
      const SizedBox(height: 16),

      // Sección comprobante
      if (_proofSent) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Comprobante enviado — el administrador lo revisará pronto.',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ),
            ],
          ),
        ),
      ] else if (_proofFile != null) ...[
        // Vista previa del comprobante
        Text(
          'Comprobante seleccionado:',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(_proofFile!.path),
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _proofUploading ? null : _pickProof,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cambiar', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _proofUploading ? null : _submitProof,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _proofUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Enviar comprobante',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ] else ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _pickProof,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text(
              'Cargar comprobante de pago',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],

      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cerrar (podés volver después)'),
        ),
      ),
    ];
  }

  // ── Paso 2b: QR dinámico BNB ──────────────────────────────────────────────

  List<Widget> _buildBnbQr(ThemeData theme, ClaimResult claim) {
    return [
      Text(
        'Escaneá y pagá',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        'Bs ${claim.amount.toStringAsFixed(0)} · ${claim.creditsGranted} créditos',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      const SizedBox(height: 20),

      Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: claim.bnbQrImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(claim.bnbQrImage!),
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                )
              : (widget.pkg?.qrData.isNotEmpty ?? false)
              ? QrImageView(data: widget.pkg!.qrData, size: 200)
              : Container(
                  width: 200,
                  height: 200,
                  alignment: Alignment.center,
                  child: Text(
                    'QR no disponible',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
        ),
      ),
      const SizedBox(height: 12),

      _ReferenceBox(reference: claim.reference),
      const SizedBox(height: 12),

      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Esperando confirmación del banco...',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cerrar (podés volver después)'),
        ),
      ),
    ];
  }

  // ── Paso 3: Éxito ─────────────────────────────────────────────────────────

  List<Widget> _buildSuccess(ThemeData theme) => [
    Center(
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 64),
          const SizedBox(height: 12),
          Text(
            '¡Pago confirmado!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_claim?.creditsGranted ?? 0} créditos acreditados',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
          if (_newBalance > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Tu saldo: $_newBalance créditos',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cerrar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  ];

  // ── Paso 4: Rechazado ──────────────────────────────────────────────────────

  List<Widget> _buildRejected(ThemeData theme) {
    final reasonToShow = _rejectionReason ?? widget.rejectionReason;
    return [
      Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Text(
            'Compra Rechazada',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.red.shade700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        '${_claim?.packageName ?? "Paquete"} · Bs ${_claim?.amount.toStringAsFixed(0)}',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      const SizedBox(height: 16),

      // Caja con el motivo del rechazo
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Motivo del rechazo:',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.red,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reasonToShow != null && reasonToShow.isNotEmpty
                  ? reasonToShow
                  : 'El comprobante no es legible o el monto es incorrecto.',
              style: TextStyle(color: Colors.red.shade900, fontSize: 14),
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),

      // Botón para intentar de nuevo (vuelve al flujo de subir comprobante)
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => setState(() {
            _step = 2;
            _proofSent = false;
            _proofFile = null;
            _subscribeToConfirm(_claim!.purchaseId);
          }),
          icon: const Icon(Icons.refresh),
          label: const Text('Corregir y reintentar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      const SizedBox(height: 12),

      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cerrar por ahora',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    ];
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _Step extends StatelessWidget {
  final String number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceBox extends StatelessWidget {
  final String reference;
  const _ReferenceBox({required this.reference});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ref: $reference',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: reference));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Referencia copiada'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Icon(Icons.copy, size: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
