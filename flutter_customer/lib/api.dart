import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

const _base = apiBaseUrl;

class Api {
  static Future<String?> get token async {
    final p = await SharedPreferences.getInstance();
    return p.getString('token');
  }

  static Future<Map<String, String>> get _headers async {
    final t = await token;
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  static Future<Map<String, dynamic>> post(String path, Map body) async {
    final res = await http.post(Uri.parse('$_base$path'),
        headers: await _headers, body: jsonEncode(body));
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(data['message'] ?? 'Ошибка');
    return data;
  }

  static Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$_base$path'), headers: await _headers);
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) throw Exception(data['message'] ?? 'Ошибка');
    return data;
  }

  static Future<Map<String, dynamic>> patch(String path, Map body) async {
    final res = await http.patch(Uri.parse('$_base$path'),
        headers: await _headers, body: jsonEncode(body));
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) throw Exception(data['message'] ?? 'Ошибка');
    return data;
  }

  static Future<void> saveAuth(String t, Map user) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token', t);
    await p.setString('user', jsonEncode(user));
  }

  static Future<void> clearAuth() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
  }

  static Future<Map<String, dynamic>?> get savedUser async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('user');
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }
}
