import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class CartStore extends ChangeNotifier {
  static const _storageKey = 'esy.cart.v1';
  final List<CartItem> _items = [];
  bool _loaded = false;

  List<CartItem> get items => List.unmodifiable(_items);
  int get totalItems => _items.fold(0, (a, b) => a + b.quantity);
  int get totalCents => _items.fold(0, (a, b) => a + b.subtotalCents);
  bool get isEmpty => _items.isEmpty;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _items
          ..clear()
          ..addAll(list.map(CartItem.fromJson));
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  void add(Product p, [int qty = 1]) {
    final idx = _items.indexWhere((i) => i.productId == p.id);
    if (idx >= 0) {
      _items[idx].quantity = (_items[idx].quantity + qty).clamp(1, 99);
    } else {
      _items.add(
        CartItem(
          productId: p.id,
          name: p.name,
          slug: p.slug,
          priceCents: p.priceCents,
          unit: p.unit,
          quantity: qty,
        ),
      );
    }
    notifyListeners();
    _persist();
  }

  void setQty(int productId, int qty) {
    final idx = _items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    if (qty <= 0) {
      _items.removeAt(idx);
    } else {
      _items[idx].quantity = qty.clamp(1, 99);
    }
    notifyListeners();
    _persist();
  }

  void remove(int productId) {
    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
    _persist();
  }

  int quantityOf(int productId) {
    final idx = _items.indexWhere((i) => i.productId == productId);
    return idx < 0 ? 0 : _items[idx].quantity;
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _persist();
  }
}
