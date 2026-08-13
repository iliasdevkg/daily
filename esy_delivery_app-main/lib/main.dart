import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'api.dart';
import 'auth.dart';
import 'cart.dart';
import 'favorites.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'widgets/blob_background.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const EsyApp());
}

class EsyApp extends StatelessWidget {
  const EsyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = Api();
    return MultiProvider(
      providers: [
        Provider(create: (_) => api),
        ChangeNotifierProvider(create: (_) => AuthStore(api)..bootstrap()),
        ChangeNotifierProvider(create: (_) => CartStore()..load()),
        ChangeNotifierProvider(create: (_) => FavoritesStore(api)),
      ],
      child: Builder(
        builder: (ctx) => MaterialApp(
          title: 'Daily',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(ctx),
          home: const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    if (auth.loading) {
      return const BlobBackground(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.brand600),
        ),
      );
    }
    return auth.isLoggedIn ? const AppShell() : const LoginScreen();
  }
}
