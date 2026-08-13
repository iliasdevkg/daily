import 'dart:convert';
import 'package:http/http.dart' as http;

// Акысыз геокодтоо — OpenStreetMap'тин Nominatim кызматы (API ачкыч керек
// эмес, Google Maps'тен айырмаланып). Колдонуу эрежеси (usage policy)
// талап кылган нерселер: чыныгы User-Agent жана 1 сурам/секунд ашпоо —
// издөө талаасында debounce колдонуу керек (location_picker.dart'та бар).
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);
}

class GeoResult {
  final String displayName;
  final GeoPoint point;
  const GeoResult(this.displayName, this.point);
}

class Geocoding {
  static const _base = 'https://nominatim.openstreetmap.org';
  static const _headers = {
    'User-Agent': 'EsyDeliveryApp/1.0 (esy delivery — grocery client)',
    'Accept-Language': 'ru,ky',
  };

  // Дарек боюнча издөө (текст -> координаттар тизмеси). Бишкекке/Кыргызстанга
  // артыкчылык берүү үчүн countrycodes=kg жана viewbox колдонулат.
  static Future<List<GeoResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '6',
        'countrycodes': 'kg',
        'addressdetails': '0',
      },
    );
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as List;
      return data.map((e) {
        final m = e as Map<String, dynamic>;
        return GeoResult(
          m['display_name'] as String,
          GeoPoint(
            double.parse(m['lat'] as String),
            double.parse(m['lon'] as String),
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // Координаттар -> дарек текст (карта жылганда борбордогу пиндин дарегин
  // көрсөтүү үчүн).
  static Future<String?> reverse(GeoPoint p) async {
    final uri = Uri.parse('$_base/reverse').replace(
      queryParameters: {'lat': '${p.lat}', 'lon': '${p.lng}', 'format': 'json'},
    );
    try {
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
