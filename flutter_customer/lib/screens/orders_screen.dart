import 'package:flutter/material.dart';
import '../api.dart';

const kGreen = Color(0xFF33D633);
const kDark = Color(0xFF0F0F0D);
const kBg = Color(0xFFFAFAF7);

const _statusMap = {
  'pending':   {'label': 'В ожидании',     'color': 0xFFD97706},
  'confirmed': {'label': 'Подтверждён',    'color': 0xFF0284C7},
  'packing':   {'label': 'Собирается',     'color': 0xFF9333EA},
  'transit':   {'label': 'В пути 🛵',      'color': 0xFFEA580C},
  'delivered': {'label': 'Доставлен ✅',   'color': 0xFF16A34A},
  'cancelled': {'label': 'Отменён',        'color': 0xFFDC2626},
};

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Api.get('/orders/my');
      setState(() { _orders = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: kGreen,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('/ заказы', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGreen, letterSpacing: .6)),
                      const SizedBox(height: 4),
                      const Text('Мои заказы', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kDark, letterSpacing: -.5)),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kGreen)))
              else if (_orders.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 80, height: 80, decoration: BoxDecoration(color: kGreen.withOpacity(.08), borderRadius: BorderRadius.circular(24)),
                          child: const Center(child: Text('📋', style: TextStyle(fontSize: 38)))),
                        const SizedBox(height: 14),
                        const Text('Нет заказов', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF71717A))),
                        const SizedBox(height: 6),
                        const Text('Заказывайте товары в магазине', style: TextStyle(fontSize: 13, color: Color(0xFFA1A1AA))),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _orderCard(_orders[i]),
                      childCount: _orders.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderCard(Map o) {
    final status = _statusMap[o['status']] ?? {'label': o['status'], 'color': 0xFFA1A1AA};
    final color = Color(status['color'] as int);
    final items = (o['items'] as List?)?.where((i) => i != null && i['name'] != null).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF4F4F5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Заказ #${o['id']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kDark)),
                  Text(_formatDate(o['created_at']), style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(99)),
                child: Text(status['label'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              items.map((i) => '${i['name']}${(i['quantity'] ?? 1) > 1 ? ' ×${i['quantity']}' : ''}').join(', '),
              style: const TextStyle(fontSize: 13, color: Color(0xFF71717A)),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFA1A1AA)),
              const SizedBox(width: 4),
              Expanded(child: Text(o['address'] ?? '—', style: const TextStyle(fontSize: 13, color: Color(0xFF71717A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${double.parse(o['total'].toString()).toStringAsFixed(0)} сом',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kDark)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String? d) {
    if (d == null) return '';
    final dt = DateTime.tryParse(d);
    if (dt == null) return '';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
