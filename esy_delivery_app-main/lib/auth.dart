import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models.dart';

class AuthStore extends ChangeNotifier {
  final Api api;
  AuthStore(this.api);

  User? user;
  bool _loading = true;
  bool get loading => _loading;
  bool get isLoggedIn => api.isLoggedIn;

  Future<void> bootstrap() async {
    await api.loadToken();
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    user = await api.login(email, password);
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? address,
  }) async {
    user = await api.register(
      name: name,
      email: email,
      password: password,
      phone: phone,
      address: address,
    );
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    user = await api.loginWithGoogle();
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    notifyListeners();
  }
}
