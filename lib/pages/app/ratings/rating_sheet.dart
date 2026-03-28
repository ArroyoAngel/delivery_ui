import 'package:flutter/material.dart';
import '../../../services/rating_service.dart';
import '../../../theme/app_colors.dart';

/// Muestra el bottom sheet de calificaciones pendientes para un pedido.
/// Retorna true si se envió al menos una calificación.
Future<bool> showRatingSheet(BuildContext context, String orderId) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _RatingSheet(orderId: orderId),
  );
  return result == true;
}

class _RatingSheet extends StatefulWidget {
  final String orderId;
  const _RatingSheet({required this.orderId});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  final _service = RatingService();
  List<PendingRating> _pending = [];
  final Map<String, int> _scores = {};
  final Map<String, TextEditingController> _comments = {};
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pending = await _service.getPending(widget.orderId);
      if (mounted) {
        setState(() {
          _pending = pending;
          for (final p in pending) {
            _scores[p.targetId] = 5;
            _comments[p.targetId] = TextEditingController();
          }
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[RatingSheet._load] ERROR: $e');
      debugPrint('[RatingSheet._load] STACK: $st');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Envía calificación 3 para todos los pendientes y cierra sin mostrar el check.
  Future<void> _submitDefaults() async {
    FocusScope.of(context).unfocus();
    if (_pending.isEmpty) { Navigator.pop(context, false); return; }
    try {
      for (final p in _pending) {
        await _service.submit(
          orderId: widget.orderId,
          targetType: p.targetType,
          targetId: p.targetId,
          score: 3,
          comment: null,
        );
      }
    } catch (_) {
      // Ignorar errores en calificación por defecto
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus(); // cerrar teclado antes de la animación
    setState(() => _submitting = true);
    try {
      for (final p in _pending) {
        await _service.submit(
          orderId: widget.orderId,
          targetType: p.targetType,
          targetId: p.targetId,
          score: _scores[p.targetId] ?? 5,
          comment: _comments[p.targetId]?.text,
        );
      }
      if (mounted) setState(() { _submitting = false; _submitted = true; });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: _loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          : _submitted
              ? const SizedBox(
                  height: 120,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success, size: 48),
                        SizedBox(height: 8),
                        Text('¡Gracias por tu calificación!',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              : _pending.isEmpty
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: Text('No hay calificaciones pendientes')),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle
                          Center(
                            child: Container(
                              width: 40, height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '¿Cómo fue tu experiencia?',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tu opinión ayuda a mejorar el servicio',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 20),
                          ..._pending.map((p) => _RatingCard(
                            pending: p,
                            score: _scores[p.targetId] ?? 5,
                            commentController: _comments[p.targetId]!,
                            onScore: (s) => setState(() => _scores[p.targetId] = s),
                          )),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _submitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Enviar calificación', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                          ),
                          TextButton(
                            onPressed: _submitting ? null : _submitDefaults,
                            child: const Center(
                              child: Text('Ahora no', style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        ],
                      ),
                    ),
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final PendingRating pending;
  final int score;
  final TextEditingController commentController;
  final ValueChanged<int> onScore;

  const _RatingCard({
    required this.pending,
    required this.score,
    required this.commentController,
    required this.onScore,
  });

  IconData get _icon {
    switch (pending.targetType) {
      case 'shop':   return Icons.restaurant_outlined;
      case 'rider':  return Icons.delivery_dining_outlined;
      default:       return Icons.person_outline;
    }
  }

  Color get _color {
    switch (pending.targetType) {
      case 'shop':   return AppColors.orange;
      case 'rider':  return AppColors.riderBlue;
      default:       return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pending.icon.label,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    Text(pending.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < score;
              return GestureDetector(
                onTap: () => onScore(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: filled ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _scoreLabel(score),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentController,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Comentario opcional...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  String _scoreLabel(int s) {
    switch (s) {
      case 1: return 'Muy malo';
      case 2: return 'Malo';
      case 3: return 'Regular';
      case 4: return 'Bueno';
      default: return 'Excelente';
    }
  }
}
