import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../app/app_root.dart';
import '../../services/auth_service.dart';
import '../../services/address_service.dart';
import 'address_selection_page.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _auth = AuthService();
  final _otpCtrl = TextEditingController();

  bool _sending = false;
  bool _verifying = false;
  String? _verificationId;
  String _completePhone = ''; // E.164 completo: +59178000000

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_completePhone.isEmpty) {
      _snack('Ingresa tu número de teléfono', Colors.orange);
      return;
    }
    setState(() => _sending = true);
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
        onAutoVerify: (credential) => _signInWithCredential(credential),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final cred = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _otpCtrl.text.trim(),
    );
    await _signInWithCredential(cred);
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    setState(() => _verifying = true);
    try {
      await _auth.phoneSignIn(
        verificationId: credential.verificationId ?? _verificationId!,
        smsCode: credential.smsCode ?? _otpCtrl.text.trim(),
      );
      if (mounted) {
        await _checkAndSelectAddress();
      }
    } catch (e) {
      if (mounted) _snack('Código incorrecto o expirado', Colors.red);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _checkAndSelectAddress() async {
    try {
      final addressService = AddressService();
      final addresses = await addressService.getAddresses();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AddressSelectionPage(isInitialSetup: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _snack('Error al cargar direcciones: $e', Colors.orange);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppRoot()),
        );
      }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ingresar con teléfono',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _verificationId == null
                    ? 'Te enviaremos un código por SMS'
                    : 'Ingresa el código que recibiste en $_completePhone',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              if (_verificationId == null) ...[
                // ── Selector de país + número ──────────────────────────
                IntlPhoneField(
                  initialCountryCode: 'BO',
                  decoration: InputDecoration(
                    labelText: 'Número de teléfono',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                  ),
                  onChanged: (phone) {
                    setState(() => _completePhone = phone.completeNumber);
                  },
                  onCountryChanged: (country) {
                    setState(() => _completePhone = '');
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _sendOtp,
                    style: _btnStyle(primary),
                    child: _sending
                        ? const _Spinner()
                        : const Text(
                            'Enviar código SMS',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ] else ...[
                // ── Ingreso de OTP ─────────────────────────────────────
                Text(
                  'Código de verificación',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 10,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verifying ? null : _verify,
                    style: _btnStyle(primary),
                    child: _verifying
                        ? const _Spinner()
                        : const Text(
                            'Verificar',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _verificationId = null;
                      _otpCtrl.clear();
                    }),
                    child: Text('Cambiar número', style: TextStyle(color: primary)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _btnStyle(Color primary) => ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
}
