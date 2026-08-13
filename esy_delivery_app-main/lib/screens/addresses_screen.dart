import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'location_picker_screen.dart';

const _labelOptions = ['Үй', 'Иш', 'Башка'];

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Address>? _addresses;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<Api>().myAddresses();
      if (mounted)
        setState(() {
          _addresses = list;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось загрузить адреса');
    }
  }

  Future<void> _addAddress() async {
    final result = await Navigator.of(context).push<LocationPickResult>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result == null || !mounted) return;

    final label = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _LabelPickerSheet(address: result.address),
    );
    if (label == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<Api>().createAddress(
        label: label,
        addressText: result.address,
        lat: result.lat,
        lng: result.lng,
      );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Кошуу мүмкүн болбоду: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setDefault(Address a) async {
    setState(() => _busy = true);
    try {
      await context.read<Api>().setDefaultAddress(a.id);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Address a) async {
    final result = await Navigator.of(context).push<LocationPickResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialAddress: a.addressText),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<Api>().updateAddress(
        a.id,
        label: a.label,
        addressText: result.address,
        lat: result.lat,
        lng: result.lng,
      );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Жаңыртуу мүмкүн болбоду: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Address a) async {
    setState(() => _busy = true);
    try {
      await context.read<Api>().deleteAddress(a.id);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton.filled(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              shape: const CircleBorder(),
              side: const BorderSide(color: AppColors.zinc100),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '/ адреса',
              style: AppTypography.mono(
                size: 10,
                color: AppColors.brand700,
                weight: FontWeight.w700,
              ),
            ),
            Text(
              'Ваши адреса',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
        titleSpacing: 0,
        toolbarHeight: 76,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              onPressed: _busy ? null : _addAddress,
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brand500,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
      body: _addresses == null
          ? Center(
              child: _error != null
                  ? Text(
                      _error!,
                      style: const TextStyle(color: AppColors.zinc500),
                    )
                  : const CircularProgressIndicator(color: AppColors.brand600),
            )
          : _addresses!.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                const Center(
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 56,
                    color: AppColors.zinc200,
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Сакталган дарек жок',
                    style: TextStyle(color: AppColors.zinc500),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _addAddress,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Дарек кошуу'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.zinc200),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _addresses!.length,
              itemBuilder: (context, i) {
                final a = _addresses![i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: a.isDefault
                          ? AppColors.brand300
                          : AppColors.zinc100,
                      width: a.isDefault ? 1.5 : 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _busy ? null : () => _edit(a),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.brand50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _iconFor(a.label),
                                color: AppColors.brand600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        a.label?.isNotEmpty == true
                                            ? a.label!
                                            : 'Дарек',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (a.isDefault) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.brand500,
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
                                          ),
                                          child: const Text(
                                            'по умолчанию',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    a.addressText,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.zinc600,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                if (!a.isDefault)
                                  IconButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _setDefault(a),
                                    icon: const Icon(
                                      Icons.star_border_rounded,
                                      size: 20,
                                      color: AppColors.zinc400,
                                    ),
                                    tooltip: 'Негизги кылуу',
                                    visualDensity: VisualDensity.compact,
                                  ),
                                IconButton(
                                  onPressed: _busy ? null : () => _delete(a),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                    color: Color(0xFFEF4444),
                                  ),
                                  tooltip: 'Өчүрүү',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _iconFor(String? label) => switch (label) {
    'Үй' => Icons.home_rounded,
    'Иш' => Icons.work_rounded,
    _ => Icons.location_on_rounded,
  };
}

class _LabelPickerSheet extends StatelessWidget {
  final String address;
  const _LabelPickerSheet({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.zinc200,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Дарек кандай аталсын?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.zinc500, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _labelOptions
                .map(
                  (l) => OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(l),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.zinc200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(l),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
