import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

// Web client ID from Google Cloud Console -> APIs & Services -> Credentials.
// Pass at build/run time: --dart-define=GOOGLE_WEB_CLIENT_ID=...
const String _googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
);

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class Api {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kDebugMode
        ? 'http://172.27.108.64:3001/api'
        : 'https://daily-backend-srmr.onrender.com/api',
  );

  String? _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth.token');
  }

  bool get isLoggedIn => _token != null;

  Future<User> login(String email, String password) async {
    final data = await _post('/auth/login', {
      'email': email,
      'password': password,
    }, auth: false);
    await _saveSession(data);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? address,
  }) async {
    final data = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
    }, auth: false);
    await _saveSession(data);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> loginWithGoogle() async {
    final googleSignIn = GoogleSignIn(serverClientId: _googleWebClientId);
    final account = await googleSignIn.signIn();
    if (account == null) throw ApiException('Вход через Google отменён');
    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw ApiException('Не удалось получить токен Google');
    final data = await _post('/auth/google', {'idToken': idToken}, auth: false);
    await _saveSession(data as Map<String, dynamic>);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    _token = data['token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth.token', _token!);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth.token');
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> _get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _parse(res);
  }

  Future<dynamic> _post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: auth ? _headers : {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<dynamic> _patch(String path, [Map<String, dynamic>? body]) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _parse(res);
  }

  Future<dynamic> _delete(String path) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    return _parse(res);
  }

  dynamic _parse(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg =
        (body is Map ? body['message']?.toString() : null) ??
        'http_${res.statusCode}';
    throw ApiException(msg, res.statusCode);
  }

  Future<List<Category>> categories() async {
    final data = await _get('/categories') as List;
    return data
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Product>> products({
    int? categoryId,
    String? search,
    int limit = 50,
  }) async {
    final q = <String, String>{};
    if (categoryId != null) q['category_id'] = '$categoryId';
    if (search != null && search.isNotEmpty) q['search'] = search;
    final qs = q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final data = await _get('/products${qs.isEmpty ? '' : '?$qs'}') as List;
    return data
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Собственные заказы клиента (сортировка от новых к старым — как отдаёт
  // GET /orders/my на бэкенде). Используется и для истории заказов, и для
  // живого отслеживания статуса (пока просто ищем нужный id в этом списке —
  // отдельного GET /orders/:id для клиента на бэкенде нет).
  Future<List<Order>> myOrders() async {
    final data = await _get('/orders/my') as List;
    return data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> createOrder({
    required String address,
    String? comment,
    required List<CartItem> items,
  }) async {
    final data = await _post('/orders', {
      'address': address,
      if (comment != null && comment.isNotEmpty) 'note': comment,
      'items': items
          .map(
            (it) => {
              'product_id': it.productId,
              'quantity': it.quantity,
              'price': it.priceCents / 100,
            },
          )
          .toList(),
    });
    return Order.fromJson(data as Map<String, dynamic>);
  }

  // ─── Сакталган даректер ──────────────────────────────────────────────
  Future<List<Address>> myAddresses() async {
    final data = await _get('/addresses/my') as List;
    return data
        .map((e) => Address.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Address> createAddress({
    String? label,
    required String addressText,
    double? lat,
    double? lng,
  }) async {
    final data = await _post('/addresses', {
      if (label != null && label.isNotEmpty) 'label': label,
      'address_text': addressText,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    return Address.fromJson(data as Map<String, dynamic>);
  }

  Future<Address> updateAddress(
    int id, {
    String? label,
    required String addressText,
    double? lat,
    double? lng,
  }) async {
    final data = await _put('/addresses/$id', {
      if (label != null && label.isNotEmpty) 'label': label,
      'address_text': addressText,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    return Address.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteAddress(int id) => _delete('/addresses/$id');

  Future<void> setDefaultAddress(int id) => _patch('/addresses/$id/default');

  // ─── Тандалмалар (избранное) ────────────────────────────────────────
  Future<List<Product>> myFavorites() async {
    final data = await _get('/favorites/my') as List;
    return data
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addFavorite(int productId) =>
      _post('/favorites/$productId', const {});

  Future<void> removeFavorite(int productId) =>
      _delete('/favorites/$productId');

  // ─── Билдирмелер (уведомления) ──────────────────────────────────────
  Future<List<NotificationItem>> myNotifications() async {
    final data = await _get('/notifications/my') as List;
    return data
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(int id) =>
      _patch('/notifications/$id/read');
}
