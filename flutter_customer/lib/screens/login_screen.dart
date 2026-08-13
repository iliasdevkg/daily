import 'package:flutter/material.dart';
import '../api.dart';

const kGreen = Color(0xFF33D633);
const kDark = Color(0xFF0F0F0D);
const kBg = Color(0xFFFAFAF7);

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _loginEmail = TextEditingController(text: '');
  final _loginPass = TextEditingController();
  final _regName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPhone = TextEditingController();
  final _regPass = TextEditingController();
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await Api.post('/auth/login', {
        'email': _loginEmail.text.trim(),
        'password': _loginPass.text,
      });
      if (data['user']['role'] != 'customer') {
        setState(() => _error = 'Этот вход только для клиентов');
        return;
      }
      await Api.saveAuth(data['token'], data['user']);
      widget.onLogin();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_regName.text.isEmpty || _regEmail.text.isEmpty || _regPass.text.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await Api.post('/auth/register', {
        'name': _regName.text.trim(),
        'email': _regEmail.text.trim(),
        'phone': _regPhone.text.trim(),
        'password': _regPass.text,
      });
      await Api.saveAuth(data['token'], data['user']);
      widget.onLogin();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Logo
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: kGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: kGreen.withOpacity(.35), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Center(child: Text('D', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white))),
              ),
              const SizedBox(height: 16),
              const Text('Daily', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kDark, letterSpacing: -1)),
              const SizedBox(height: 4),
              const Text('Войти или зарегистрироваться', style: TextStyle(fontSize: 14, color: Color(0xFF71717A))),
              const SizedBox(height: 28),

              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(3),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.1), blurRadius: 4)],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: kDark,
                  unselectedLabelColor: const Color(0xFF71717A),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  tabs: const [Tab(text: 'Войти'), Tab(text: 'Регистрация')],
                  onTap: (_) => setState(() => _error = ''),
                ),
              ),
              const SizedBox(height: 20),

              // Error
              if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(.25)),
                  ),
                  child: Text(_error, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                ),

              if (_tab.index == 0)
                Column(children: [
                  _inp(_loginEmail, 'Email', TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _inp(_loginPass, 'Пароль', TextInputType.text, obscure: true),
                  const SizedBox(height: 20),
                  _btn('Войти →', _login),
                ])
              else
                Column(children: [
                  _inp(_regName, 'Имя и фамилия', TextInputType.name),
                  const SizedBox(height: 10),
                  _inp(_regPhone, '+996 700 000 000', TextInputType.phone),
                  const SizedBox(height: 10),
                  _inp(_regEmail, 'Email', TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  _inp(_regPass, 'Пароль', TextInputType.text, obscure: true),
                  const SizedBox(height: 20),
                  _btn('Регистрация →', _register),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inp(TextEditingController c, String hint, TextInputType type, {bool obscure = false}) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15, color: kDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA1A1AA)),
        filled: true,
        fillColor: const Color(0xFFF4F4F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
