import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';

const kOrange = Color(0xFFFB923C);
const kBg = Color(0xFF0A0A0F);
const kSurface = Color(0xFF18181B);
const kBorder = Color(0xFF27272A);

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List _orders = [];
  Map<String, dynamic>? _user;
  bool _loading = true;
  Timer? _timer;
  // checklist state: orderId -> Set of checked item indices
  final Map<int, Set<int>> _checked = {};

  @override
  void initState() {
    super.initState();
    _loadUser();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _loadUser() async { _user = await Api.savedUser; }

  Future<void> _load() async {
    try {
      final data = await Api.get('/orders/picker');
      setState(() { _orders = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _accept(Map order) async {
    try {
      await Api.patch('/orders/${order['id']}/status', {'status': 'packing', 'picker_user_id': _user?['id']});
      await _load();
      _snack('📦 Начал сборку!');
    } catch (e) { _snack('Ошибка: $e', isError: true); }
  }

  Future<void> _sendToDelivery(Map order) async {
    final items = (order['items'] as List?)?.where((i) => i != null && i['name'] != null).toList() ?? [];
    final checkedSet = _checked[order['id'] as int] ?? {};
    if (items.isNotEmpty && checkedSet.length < items.length) {
      _snack('Отметьте все товары!', isError: true);
      return;
    }
    try {
      await Api.patch('/orders/${order['id']}/status', {'status': 'transit'});
      await _load();
      Navigator.of(context).pop();
      _snack('🚀 Передано на доставку!');
    } catch (e) { _snack('Ошибка: $e', isError: true); }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.red : kOrange,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ));
  }

  List get _available => _orders.where((o) => o['status'] == 'confirmed' && o['picker_user_id'] == null).toList();
  List get _mine => _orders.where((o) => o['picker_user_id'] == _user?['id'] && o['status'] == 'packing').toList();
  List get _history => _orders.where((o) => o['status'] == 'transit' || o['status'] == 'delivered').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(index: _tab, children: [_buildHome(), _buildHistory(), _buildProfile()]),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF111115), border: Border(top: BorderSide(color: kBorder))),
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          _navBtn(0, '📦', 'Заказы'),
          _navBtn(1, '📋', 'История'),
          _navBtn(2, '👤', 'Профиль'),
        ]),
      )),
    );
  }

  Widget _navBtn(int idx, String emoji, String label) {
    final active = _tab == idx;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: active ? kOrange.withOpacity(.12) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? kOrange : const Color(0xFF71717A))),
        ]),
      ),
    ));
  }

  Widget _buildHome() {
    return RefreshIndicator(
      color: kOrange, backgroundColor: kSurface, onRefresh: _load,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 0),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('/ сборщик', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOrange, letterSpacing: .8)),
              const Text('Заказы', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: kOrange.withOpacity(.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: kOrange.withOpacity(.25))),
              child: Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Онлайн', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOrange)),
              ]),
            ),
          ]),
        )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(child: Row(children: [
            _statCard('📦', 'Собирается', _mine.length, kOrange),
            const SizedBox(width: 10),
            _statCard('🛒', 'Новые', _available.length, const Color(0xFFFBBF24)),
          ])),
        ),
        if (_mine.isNotEmpty) ...[
          _sectionHeader('Собирается', '${_mine.length} заказов', kOrange),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _orderCard(_mine[i], isMine: true),
              childCount: _mine.length,
            )),
          ),
        ],
        _sectionHeader('Новые заказы', '${_available.length} заказов', const Color(0xFFFBBF24)),
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kOrange)))
        else if (_available.isEmpty)
          SliverToBoxAdapter(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
            child: const Center(child: Column(children: [
              Text('📭', style: TextStyle(fontSize: 44)),
              SizedBox(height: 10),
              Text('Нет заказов', style: TextStyle(color: Color(0xFF52525B), fontSize: 14, fontWeight: FontWeight.w600)),
            ])),
          ))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _orderCard(_available[i]),
              childCount: _available.length,
            )),
          ),
      ]),
    );
  }

  Widget _statCard(String emoji, String label, int value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color, letterSpacing: -1)),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A))),
      ]),
    ));
  }

  Widget _sectionHeader(String title, String sub, Color color) {
    return SliverToBoxAdapter(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(width: 8),
        Text(sub, style: TextStyle(fontSize: 12, color: color)),
      ]),
    ));
  }

  Widget _orderCard(Map o, {bool isMine = false}) {
    final items = (o['items'] as List?)?.where((i) => i != null && i['name'] != null).toList() ?? [];
    return GestureDetector(
      onTap: () => _showDetail(o),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isMine ? kOrange.withOpacity(.3) : kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['customer_name'] ?? 'Заказ #${o['id']}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('#${o['id']} · ${items.length} товаров · ${double.parse(o['total'].toString()).toStringAsFixed(0)} сом',
                style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
            ])),
            if (isMine) Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kOrange.withOpacity(.15), borderRadius: BorderRadius.circular(99)),
              child: const Text('У меня', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOrange))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF71717A)),
            const SizedBox(width: 4),
            Expanded(child: Text(o['address'] ?? '—',
              style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ]),
      ),
    );
  }

  void _showDetail(Map o) {
    final isMine = o['picker_user_id'] == _user?['id'];
    final orderId = o['id'] as int;
    final items = (o['items'] as List?)?.where((i) => i != null && i['name'] != null).toList() ?? [];

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        final checkedSet = _checked[orderId] ?? <int>{};
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88),
          decoration: const BoxDecoration(color: Color(0xFF1C1C22), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 44, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(99))),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('/ заказ #$orderId', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOrange, letterSpacing: .6)),
                const SizedBox(height: 4),
                Text(o['customer_name'] ?? 'Клиент', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('${double.parse(o['total'].toString()).toStringAsFixed(0)} сом', style: const TextStyle(fontSize: 13, color: Color(0xFF71717A))),
                const SizedBox(height: 20),

                // Item checklist
                if (items.isNotEmpty) ...[
                  Row(children: [
                    const Text('СПИСОК ТОВАРОВ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF71717A), letterSpacing: .5)),
                    const Spacer(),
                    Text('${checkedSet.length} / ${items.length}', style: const TextStyle(fontSize: 12, color: kOrange, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                  ...List.generate(items.length, (i) {
                    final item = items[i];
                    final done = checkedSet.contains(i);
                    return GestureDetector(
                      onTap: isMine ? () {
                        setState(() {
                          final s = _checked.putIfAbsent(orderId, () => <int>{});
                          if (done) s.remove(i); else s.add(i);
                        });
                        setSt(() {});
                      } : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: done ? kOrange.withOpacity(.08) : Colors.white.withOpacity(.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: done ? kOrange.withOpacity(.3) : kBorder),
                        ),
                        child: Row(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: done ? kOrange : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: done ? kOrange : const Color(0xFF52525B), width: 2),
                            ),
                            child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: done ? kOrange : Colors.white, decoration: done ? TextDecoration.lineThrough : null)),
                            Text('× ${item['quantity'] ?? 1} · ${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(0)} сом',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                          ])),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                _infoRow('📍', 'Адрес', o['address'] ?? '—'),
                _infoRow('📱', 'Телефон', o['customer_phone'] ?? '—'),
                const SizedBox(height: 20),

                if (!isMine)
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: () { Navigator.pop(context); _accept(o); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: const Text('✅ Начать сборку', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  )),
                if (isMine)
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: checkedSet.length >= items.length || items.isEmpty ? () => _sendToDelivery(o) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF33D633), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
                      disabledBackgroundColor: const Color(0xFF33D633).withOpacity(.4)),
                    child: const Text('🏁 Готово! Передать на доставку', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  )),
              ]),
            )),
          ]),
        );
      }),
    );
  }

  Widget _infoRow(String emoji, String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
      ])),
    ]));
  }

  Widget _buildHistory() {
    final packed = _history;
    return SafeArea(child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('/ история', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOrange, letterSpacing: .8)),
          const Text('История сборки', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.5)),
          const SizedBox(height: 16),
          Row(children: [
            _statCard('📦', 'Собрано', packed.length, kOrange),
            const SizedBox(width: 10),
            _statCard('🛒', 'Кол-во товаров', packed.fold(0, (s, o) => s + ((o['items'] as List?)?.where((i) => i?['name'] != null).length ?? 0)), const Color(0xFFFBBF24)),
          ]),
          const SizedBox(height: 16),
        ]),
      )),
      if (packed.isEmpty)
        SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [
          Text('📋', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('История пуста', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF71717A))),
        ])))
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) {
            final o = packed[i];
            final isDelivered = o['status'] == 'delivered';
            final itemCnt = (o['items'] as List?)?.where((i) => i?['name'] != null).length ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o['customer_name'] ?? 'Заказ #${o['id']}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('#${o['id']}', style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
                  const SizedBox(height: 4),
                  Text('📦 $itemCnt товаров собрано', style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA))),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isDelivered ? const Color(0xFF33D633) : kOrange).withOpacity(.15),
                    borderRadius: BorderRadius.circular(99)),
                  child: Text(isDelivered ? '✅ Доставлено' : '🚀 В пути',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDelivered ? const Color(0xFF33D633) : kOrange)),
                ),
              ]),
            );
          }, childCount: packed.length)),
        ),
    ]));
  }

  Widget _buildProfile() {
    return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [kOrange.withOpacity(.12), kOrange.withOpacity(.04)]),
          borderRadius: BorderRadius.circular(24), border: Border.all(color: kOrange.withOpacity(.2))),
        child: Row(children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: kOrange.withOpacity(.2), shape: BoxShape.circle),
            child: const Center(child: Text('📦', style: TextStyle(fontSize: 32)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_user?['name'] ?? 'Сборщик', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            if (_user?['email'] != null) Text(_user!['email'], style: const TextStyle(fontSize: 13, color: Color(0xFF71717A))),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kOrange.withOpacity(.15), borderRadius: BorderRadius.circular(99)),
              child: const Text('Сборщик', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kOrange))),
          ])),
        ]),
      ),
      const SizedBox(height: 16),
      _profTile('📞', 'Контакты', _user?['phone'] ?? '+996 — — —'),
      _profTile('🏪', 'Склад', 'Склад Бишкек'),
      _profTile('⚙️', 'Настройки', 'Уведомления, язык'),
      _profTile('❓', 'Помощь', 'Служба поддержки'),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: () async { await Api.clearAuth(); widget.onLogout(); },
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Выйти', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFCA5A5),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      )),
    ])));
  }

  Widget _profTile(String emoji, String title, String sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(.05), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
        ])),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF52525B)),
      ]),
    );
  }
}
