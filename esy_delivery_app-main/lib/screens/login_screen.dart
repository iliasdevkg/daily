import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../auth.dart';
import '../theme.dart';
import '../widgets/blob_background.dart';
import '../widgets/glass.dart';
import 'location_picker_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  final _regName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPhone = TextEditingController();
  final _regPass = TextEditingController();
  final _regAddress = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  Future<void> _submitGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthStore>().loginWithGoogle();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Не удалось войти через Google');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthStore>();
      if (_isLogin) {
        await auth.login(_loginEmail.text.trim(), _loginPass.text);
      } else {
        if (_regName.text.trim().isEmpty ||
            _regEmail.text.trim().isEmpty ||
            _regPass.text.isEmpty) {
          throw ApiException('Заполните все поля');
        }
        await auth.register(
          name: _regName.text.trim(),
          email: _regEmail.text.trim(),
          password: _regPass.text,
          phone: _regPhone.text.trim(),
          address: _regAddress.text.trim(),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Нет соединения, попробуйте снова');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlobBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.brand500,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand500.withValues(alpha: .35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'D',
                      style: GoogleFonts.pacifico(
                        color: Colors.white,
                        fontSize: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Daily', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 4),
                Text(
                  'Войти или зарегистрироваться',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                Glass(
                  borderRadius: BorderRadius.circular(28),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.zinc100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            Expanded(
                              child: _tab(
                                'Войти',
                                _isLogin,
                                () => setState(() {
                                  _isLogin = true;
                                  _error = null;
                                }),
                              ),
                            ),
                            Expanded(
                              child: _tab(
                                'Регистрация',
                                !_isLogin,
                                () => setState(() {
                                  _isLogin = false;
                                  _error = null;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_isLogin) ..._loginFields() else ..._registerFields(),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _isLogin ? 'Войти →' : 'Регистрация →',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppColors.zinc200),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'или',
                              style: TextStyle(
                                color: AppColors.zinc400,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppColors.zinc200),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _googleLoading ? null : _submitGoogle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.zinc200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        child: _googleLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'G',
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: const Color(0xFF4285F4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Войти через Google',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _loginFields() => [
    _field(_loginEmail, 'Email', TextInputType.emailAddress),
    const SizedBox(height: 12),
    _field(_loginPass, 'Пароль', TextInputType.text, obscure: true),
  ];

  List<Widget> _registerFields() => [
    _field(_regName, 'Имя и фамилия', TextInputType.name),
    const SizedBox(height: 10),
    _field(_regPhone, '+996 700 000 000', TextInputType.phone),
    const SizedBox(height: 10),
    _field(_regEmail, 'Email', TextInputType.emailAddress),
    const SizedBox(height: 10),
    _field(_regPass, 'Пароль', TextInputType.text, obscure: true),
    const SizedBox(height: 10),
    _addressField(),
  ];

  // Дарек — карта аркылуу тандалат же түз жазылат (экөө тең). Милдеттүү
  // эмес — каттоо учурунда так дарек түгөйлөбөсө да, кийин Профилден кошсо
  // болот.
  Widget _addressField() {
    return TextField(
      controller: _regAddress,
      maxLines: 2,
      minLines: 1,
      style: const TextStyle(fontSize: 15, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: 'Дарек (милдеттүү эмес)',
        hintStyle: const TextStyle(color: AppColors.zinc400),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brand500, width: 1.5),
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        suffixIcon: IconButton(
          icon: const Icon(Icons.map_outlined, color: AppColors.brand600),
          tooltip: 'Картадан тандоо',
          onPressed: () async {
            final result = await Navigator.of(context).push<LocationPickResult>(
              MaterialPageRoute(
                builder: (_) =>
                    LocationPickerScreen(initialAddress: _regAddress.text),
              ),
            );
            if (result != null)
              setState(() => _regAddress.text = result.address);
          },
        ),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .1),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
            color: active ? AppColors.ink : AppColors.zinc500,
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    TextInputType type, {
    bool obscure = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.zinc400),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brand500, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
