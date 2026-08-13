import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../geocoding.dart';
import '../theme.dart';

class LocationPickResult {
  final String address;
  final double? lat;
  final double? lng;
  const LocationPickResult({required this.address, this.lat, this.lng});
}

// Дарек тандоо: карта (акысыз OpenStreetMap, API ачкыч керек эмес) же текст
// менен түз жазуу — экөө тең иштейт. Борбордо туруктуу пин турат, карта
// астынан жылат ("drag-to-position" стили); токтогондо борбордун дареги
// автоматтык түрдө текст талаасына жазылат, бирок ошол текстти кол менен да
// оңдоого/толугу менен өзгөртүүгө болот.
class LocationPickerScreen extends StatefulWidget {
  final String? initialAddress;
  const LocationPickerScreen({super.key, this.initialAddress});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _bishkek = LatLng(42.8746, 74.5698);

  final _mapController = MapController();
  final _addressCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _lastAutoText = '';
  bool _resolving = false;
  List<GeoResult> _suggestions = [];
  Timer? _moveDebounce;
  Timer? _searchDebounce;
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressCtrl.text = widget.initialAddress!;
    }
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _searchDebounce?.cancel();
    _addressCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent e) {
    if (e is! MapEventMoveEnd &&
        e is! MapEventFlingAnimationEnd &&
        e is! MapEventDoubleTapZoomEnd)
      return;
    _moveDebounce?.cancel();
    _moveDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _resolveCenter(),
    );
  }

  Future<void> _resolveCenter() async {
    final center = _mapController.camera.center;
    _picked = center;
    setState(() => _resolving = true);
    final name = await Geocoding.reverse(
      GeoPoint(center.latitude, center.longitude),
    );
    if (!mounted) return;
    setState(() {
      _resolving = false;
      // Колдонуучу карта жылып жатканда текстти кол менен өзгөртпөгөн болсо
      // гана — жаздырылган текстин үстүнөн жазып коюбашы үчүн.
      if (name != null &&
          (_addressCtrl.text.isEmpty || _addressCtrl.text == _lastAutoText)) {
        _addressCtrl.text = name;
        _lastAutoText = name;
      }
    });
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      final results = await Geocoding.search(q);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  void _selectSuggestion(GeoResult r) {
    setState(() {
      _suggestions = [];
      _searchCtrl.clear();
      _addressCtrl.text = r.displayName;
      _lastAutoText = r.displayName;
      _picked = LatLng(r.point.lat, r.point.lng);
    });
    _mapController.move(LatLng(r.point.lat, r.point.lng), 16);
    FocusScope.of(context).unfocus();
  }

  void _confirm() {
    final text = _addressCtrl.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      LocationPickResult(
        address: text,
        lat: _picked?.latitude,
        lng: _picked?.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _bishkek,
              initialZoom: 13,
              onMapEvent: _onMapEvent,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'kg.daily.esy_delivery_app',
                maxZoom: 19,
              ),
            ],
          ),

          // Борбордогу туруктуу пин — карта астынан жылат.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 44,
                  color: AppColors.brand600,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Артка баскыч + издөө талаасы.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.filled(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                        shape: const CircleBorder(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Дарек боюнча издөө...',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.zinc100),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.zinc500,
                        ),
                        title: Text(
                          _suggestions[i].displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () => _selectSuggestion(_suggestions[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Ылдыйда: дарек тексти (кол менен да оңдолот) + ырастоо баскычы.
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.edit_location_alt_outlined,
                        size: 16,
                        color: AppColors.zinc500,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Тандалган дарек',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.zinc500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_resolving)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _addressCtrl,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Дарек жазыңыз же картадан тандаңыз',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Ушул даректи тандоо',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
