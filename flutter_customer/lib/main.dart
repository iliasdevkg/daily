import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// CHANGED: lets AuthGate show a SnackBar from anywhere without needing a
// BuildContext that has a Scaffold ancestor at that exact moment.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const DailyApp());
}

class DailyApp extends StatelessWidget {
  const DailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey, // CHANGED
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF33D633),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAF7),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _loggedIn = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    _check();
    _watchConnectivity(); // CHANGED
    _wakeBackend(); // CHANGED
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _loggedIn = p.getString('token') != null;
      _loading = false;
    });
  }

  // CHANGED: offline notice. Doesn't gate navigation — purely informational.
  void _watchConnectivity() {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (offline) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Нет интернета. Если сервер «спит», подождите 30 секунд')),
        );
      }
    });
  }

  // CHANGED: fire-and-forget nudge so a sleeping Render free-tier instance
  // starts waking up immediately on app open, before the user even reaches
  // a screen that calls the API. Only surfaces a message if it actually
  // took a while (a warm backend responds in well under 3s, silently).
  Future<void> _wakeBackend() async {
    final started = DateTime.now();
    try {
      await http.get(Uri.parse('$apiBaseUrl/health')).timeout(const Duration(seconds: 35));
    } catch (_) {
      // Individual screens already handle their own request errors.
    }
    if (mounted && DateTime.now().difference(started) > const Duration(seconds: 3)) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Сервер пробудился. Если страница не загрузилась, попробуйте снова.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAF7),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF33D633))),
      );
    }
    return _loggedIn
        ? HomeScreen(onLogout: () => setState(() => _loggedIn = false))
        : LoginScreen(onLogin: () => setState(() => _loggedIn = true));
  }
}
