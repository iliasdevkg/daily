import 'package:flutter/material.dart';
import '../api.dart';

const kBlue = Color(0xFF38BDF8);
const kBg = Color(0xFF0A0A0F);
const kSurface = Color(0xFF18181B);

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'delivery@daily.kg');
  final _pass = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await Api.post('/auth/login', {'email': _email.text.trim(), 'password': _pass.text});
      if (data['user']['role'] != 'delivery') throw Exception('Этот вход только для доставщиков');
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
              const SizedBox(height: 40),
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: kBlue.withOpacity(.35), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Center(child: Text('🚴', style: TextStyle(fontSize: 34))),
              ),
              const SizedBox(height: 20),
              const Text('Daily Доставщик', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.5)),
              const Text('Платформа для доставщиков', style: TextStyle(fontSize: 13, color: Color(0xFF71717A))),
              const SizedBox(height: 36),
              _inp(_email, 'Email', TextInputType.emailAddress),
              const SizedBox(height: 12),
              _inp(_pass, 'Пароль', TextInputType.text, obscure: true),
              const SizedBox(height: 16),
              if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(_error, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Войти →', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kBlue.withOpacity(.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBlue.withOpacity(.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Demo вход:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kBlue)),
                    SizedBox(height: 6),
                    Text('Email: delivery@daily.kg', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                    Text('Пароль: password', style: TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inp(TextEditingController c, String hint, TextInputType type, {bool obscure = false}) {
    return TextField(
      controller: c, keyboardType: type, obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Color(0xFF52525B)),
        filled: true, fillColor: kSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
