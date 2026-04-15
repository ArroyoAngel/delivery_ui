import 'package:flutter/material.dart';
import '../app/app_root.dart';
import '../../services/auth_service.dart';
import 'phone_login_page.dart';
import 'forgot_password_page.dart';
import 'address_selection_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _isRegisterMode = false;
  bool _otpSent = false;

  // Estados para el flujo seleccionado
  String? _selectedAuthMethod; // 'email', 'google', 'phone', null

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── Login ────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _snack('Por favor completa todos los campos', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.login(email, password);
      await _checkAndSelectAddress();
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndSelectAddress() async {
    try {
      if (mounted) {
        // Mostrar modal para seleccionar dirección
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddressSelectionPage(isInitialSetup: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _snack('Error al cargar direcciones: $e', Colors.orange);
        _goHome();
      }
    }
  }

  // ── Registro paso 1: enviar OTP ──────────────────────────────────────────

  Future<void> _sendOtp() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty) {
      _snack('Completa todos los campos', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.sendRegisterOtp(email);
      if (mounted) setState(() => _otpSent = true);
      _snack('Código enviado a $email', Colors.green);
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Registro paso 2: verificar OTP y crear cuenta ───────────────────────

  Future<void> _verifyAndRegister() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      _snack('Ingresa el código de 6 dígitos', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.register(
        email: _emailController.text.trim(),
        code: code,
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      await _checkAndSelectAddress();
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google ───────────────────────────────────────────────────────────────

  Future<void> _googleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.googleSignIn();
      await _checkAndSelectAddress();
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppRoot()),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _switchMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _otpSent = false;
      _otpController.clear();
    });
  }

  void _backToMethodSelection() {
    setState(() {
      _selectedAuthMethod = null;
      _isRegisterMode = false;
      _otpSent = false;
      _emailController.clear();
      _passwordController.clear();
      _firstNameController.clear();
      _lastNameController.clear();
      _otpController.clear();
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Si no hay método seleccionado, mostrar pantalla principal
    if (_selectedAuthMethod == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.delivery_dining, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'YaYa Eats',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: primary),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Título
                Text(
                  'Hola 👋',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '¿Cómo deseas ingresar?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),

                // Botón Google (Naranja/Primary)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGoogleLoading ? null : _googleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: _isGoogleLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.g_mobiledata, size: 26),
                    label: const Text(
                      'Ingresar con Google',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botón Teléfono (Blanco)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () {
                      setState(() => _selectedAuthMethod = 'phone');
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PhoneLoginPage()),
                      ).then((_) => _backToMethodSelection());
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.phone_outlined, size: 26, color: Colors.black87),
                    label: const Text(
                      'Ingresar con teléfono',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botón Correo (Blanco)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => setState(() => _selectedAuthMethod = 'email'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.email_outlined, size: 26, color: Colors.black87),
                    label: const Text(
                      'Ingresar con correo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Flujo de Correo ──────────────────────────────────────────────────
    if (_selectedAuthMethod == 'email') {
      String title;
      String subtitle;
      if (!_isRegisterMode) {
        title = 'Iniciar sesión';
        subtitle = 'Ingresa tu correo y contraseña';
      } else if (!_otpSent) {
        title = 'Crear cuenta';
        subtitle = 'Ingresa tus datos para comenzar';
      } else {
        title = 'Verificar correo';
        subtitle = 'Ingresa el código que enviamos a ${_emailController.text.trim()}';
      }

      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botón atrás
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: _isLoading ? null : _backToMethodSelection,
                    icon: const Icon(Icons.arrow_back_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Título
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Campos ─────────────────────────────────────────────────
                if (_otpSent) ...[
                  _InputField(
                    controller: _otpController,
                    label: 'Código de verificación',
                    hint: '6 dígitos',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      child: Text('Reenviar código', style: TextStyle(color: primary, fontSize: 13)),
                    ),
                  ),
                ] else ...[
                  if (_isRegisterMode) ...[
                    _InputField(
                      controller: _firstNameController,
                      label: 'Nombre',
                      hint: 'Ej. Juan',
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 16),
                    _InputField(
                      controller: _lastNameController,
                      label: 'Apellido',
                      hint: 'Ej. Mamani',
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _InputField(
                    controller: _emailController,
                    label: 'Correo electrónico',
                    hint: 'Ej. juan@correo.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _InputField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    hint: 'Mínimo 6 caracteres',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  if (!_isRegisterMode) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                        ),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(color: primary, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 28),

                // ── Botón principal ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _otpSent
                            ? _verifyAndRegister
                            : _isRegisterMode
                                ? _sendOtp
                                : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            _otpSent
                                ? 'Verificar y crear cuenta'
                                : _isRegisterMode
                                    ? 'Enviar código de verificación'
                                    : 'Ingresar',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Cambiar modo ────────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _switchMode,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey.shade600),
                        children: [
                          TextSpan(
                            text: _isRegisterMode ? '¿Ya tienes cuenta? ' : '¿No tienes cuenta? ',
                          ),
                          TextSpan(
                            text: _isRegisterMode ? 'Iniciar sesión' : 'Regístrate',
                            style: TextStyle(color: primary, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Fallback (no debería llegar aquí)
    return Scaffold(
      body: Center(
        child: Text('Estado desconocido: $_selectedAuthMethod'),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF444444)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      ],
    );
  }
}
