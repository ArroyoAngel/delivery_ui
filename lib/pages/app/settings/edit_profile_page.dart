import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _auth = AuthService();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  final _otpCtrl = TextEditingController();

  bool _savingProfile = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  String _completePhone = '';
  String? _verificationId;
  String? _verifiedPhone;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: user?.lastName ?? '');
    if (user != null && user.hasPhone) {
      _verifiedPhone = user.phone;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await _auth.updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _sendOtp() async {
    if (_completePhone.isEmpty) {
      _snack('Ingresa un número de teléfono', Colors.orange);
      return;
    }
    setState(() => _sendingOtp = true);
    try {
      await _auth.sendPhoneOtp(
        phoneNumber: _completePhone,
        onCodeSent: (id) {
          if (mounted) setState(() => _verificationId = id);
          _snack('Código enviado a $_completePhone', Colors.green);
        },
        onError: (err) {
          if (mounted) _snack('Error: $err', Colors.red);
        },
      );
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    final code = _otpCtrl.text.trim();
    if (code.length < 6) {
      _snack('Ingresa el código de 6 dígitos', Colors.orange);
      return;
    }
    setState(() => _verifyingOtp = true);
    try {
      final phone = await _auth.verifyAndUpdatePhone(
        verificationId: _verificationId!,
        smsCode: code,
      );
      if (mounted) {
        setState(() {
          _verifiedPhone = phone;
          _verificationId = null;
        });
        _snack('Teléfono $phone verificado y guardado ✓', Colors.green);
      }
    } catch (e) {
      if (mounted) _snack('Código incorrecto o expirado', Colors.red);
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF7F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Nombre y apellido ────────────────────────────────────────
            _Section(
              title: 'Datos personales',
              children: [
                _Field(
                  controller: _firstNameCtrl,
                  label: 'Nombre',
                  hint: 'Ej. Juan',
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _lastNameCtrl,
                  label: 'Apellido',
                  hint: 'Ej. Mamani',
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savingProfile ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _savingProfile
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Teléfono verificado ──────────────────────────────────────
            _Section(
              title: 'Número de teléfono',
              subtitle: 'Se verificará por SMS antes de guardarse',
              children: [
                if (_verifiedPhone != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          _verifiedPhone!,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  IntlPhoneField(
                    initialCountryCode: 'BO',
                    decoration: InputDecoration(
                      labelText: 'Número de teléfono',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primary, width: 2),
                      ),
                    ),
                    onChanged: (phone) {
                      setState(() => _completePhone = phone.completeNumber);
                    },
                    onCountryChanged: (_) {
                      setState(() => _completePhone = '');
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_sendingOtp || _verificationId != null) ? null : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _sendingOtp
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _verificationId != null ? 'SMS enviado' : 'Enviar SMS',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  if (_verificationId != null) ...[
                    const SizedBox(height: 14),
                    _Field(
                      controller: _otpCtrl,
                      label: 'Código de verificación',
                      hint: '6 dígitos',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _verifyingOtp ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _verifyingOtp
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Verificar código', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _Section({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primary, width: 2)),
          ),
        ),
      ],
    );
  }
}
