import 'package:flutter/foundation.dart';
import 'api.dart';

// CartStore'дон айырмаланып — тандалмалар (favorites) SharedPreferences'та
// эмес, серверде (колдонуучуга байланыштуу) сакталат. Ушул жерде set гана
// (product id'лер), UI ProductCard'та дароо "толуп/куру жүрөк" көрсөтүү үчүн.
class FavoritesStore extends ChangeNotifier {
  final Api api;
  FavoritesStore(this.api);

  final Set<int> _ids = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;

  bool isFavorite(int productId) => _ids.contains(productId);

  Future<void> load() async {
    if (!api.isLoggedIn) {
      _ids.clear();
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      final products = await api.myFavorites();
      _ids
        ..clear()
        ..addAll(products.map((p) => p.id));
    } catch (_) {
      // Тармак жок болсо — эски абалда калат, кийинки жолу кайра аракет кылынат.
    }
    _loaded = true;
    notifyListeners();
  }

  // Optimistic: экранда дароо өзгөрөт, backend чакырык фондо жүрөт; ката
  // болсо гана артка кайтарылат.
  Future<void> toggle(int productId) async {
    final wasFavorite = _ids.contains(productId);
    if (wasFavorite) {
      _ids.remove(productId);
    } else {
      _ids.add(productId);
    }
    notifyListeners();
    try {
      if (wasFavorite) {
        await api.removeFavorite(productId);
      } else {
        await api.addFavorite(productId);
      }
    } catch (_) {
      if (wasFavorite) {
        _ids.add(productId);
      } else {
        _ids.remove(productId);
      }
      notifyListeners();
    }
  }
}
