import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';

const kBlue = Color(0xFF38BDF8);
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

  @override
  void initState() {
    super.initState();
    _loadUser();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _loadUser() async {
    _user = await Api.savedUser;
  }

  Future<void> _load() async {
    try {
      final data = await Api.get('/orders/delivery');
      setState(() { _orders = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _accept(Map order) async {
    try {
      await Api.patch('/orders/${order['id']}/status', {'status': 'transit', 'delivery_user_id': _user?['id']});
      await _load();
    } catch (e) {
      _snack('Ошибка: $e', isError: true);
    }
  }

  Future<void> _deliver(Map order) async {
    try {
      await Api.patch('/orders/${order['id']}/status', {'status': 'delivered'});
      await _load();
      _snack('✅ Доставлено!');
    } catch (e) {
      _snack('Ошибка: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.red : kBlue,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ));
  }

  List get _available => _orders.where((o) => o['status'] == 'transit' && o['delivery_user_id'] == null).toList();
  List get _mine => _orders.where((o) => o['delivery_user_id'] == _user?['id'] && o['status'] == 'transit').toList();
  List get _history => _orders.where((o) => o['status'] == 'delivered').toList();

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
          _navBtn(0, '🏠', 'Активные'),
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
        decoration: BoxDecoration(
          color: active ? kBlue.withOpacity(.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? kBlue : const Color(0xFF71717A))),
        ]),
      ),
    ));
  }

  Widget _buildHome() {
    return RefreshIndicator(
      color: kBlue,
      backgroundColor: kSurface,
      onRefresh: _load,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 0),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('/ доставщик', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlue, letterSpacing: .8)),
              const Text('Заказы', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: kBlue.withOpacity(.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: kBlue.withOpacity(.25))),
              child: Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Онлайн', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBlue)),
              ]),
            ),
          ]),
        )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(child: Row(children: [
            _statCard('🚴', 'У меня', _mine.length, kBlue),
            const SizedBox(width: 10),
            _statCard('📦', 'Готовы', _available.length, const Color(0xFFFBBF24)),
          ])),
        ),
        if (_mine.isNotEmpty) ...[
          _sectionHeader('Мои заказы', '${_mine.length} в пути', kBlue),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _orderCard(_mine[i], isMine: true),
              childCount: _mine.length,
            )),
          ),
        ],
        _sectionHeader('Готовы к доставке', '${_available.length} заказов', const Color(0xFFFBBF24)),
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kBlue)))
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
    return GestureDetector(
      onTap: () => _showOrderDetail(o),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isMine ? kBlue.withOpacity(.3) : kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['customer_name'] ?? 'Заказ #${o['id']}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('#${o['id']} · ${double.parse(o['total'].toString()).toStringAsFixed(0)} сом',
                style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
            ])),
            if (isMine)
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kBlue.withOpacity(.15), borderRadius: BorderRadius.circular(99)),
                child: const Text('У меня', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlue))),
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

  void _showOrderDetail(Map o) {
    final isMine = o['delivery_user_id'] == _user?['id'];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .85),
        decoration: const BoxDecoration(color: Color(0xFF1C1C22), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(99))),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('/ заказ #${o['id']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlue, letterSpacing: .6)),
              const SizedBox(height: 4),
              Text(o['customer_name'] ?? 'Клиент', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 20),
              _infoRow('📍', 'Адрес', o['address'] ?? '—'),
              _infoRow('📱', 'Телефон', o['customer_phone'] ?? '—'),
              _infoRow('💰', 'Сумма', '${double.parse(o['total'].toString()).toStringAsFixed(0)} сом'),
              if (o['note'] != null && o['note'].toString().isNotEmpty)
                _infoRow('📝', 'Примечание', o['note']),
              const SizedBox(height: 20),
              if (!isMine)
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _accept(o); },
                  style: ElevatedButton.styleFrom(backgroundColor: kBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: const Text('✅ Принять', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                )),
              if (isMine) ...[
                if (o['customer_phone'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: const Text('Позвонить клиенту', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      style: OutlinedButton.styleFrom(foregroundColor: kBlue,
                        side: const BorderSide(color: kBlue, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _deliver(o); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF33D633), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: const Text('🏁 Доставлено!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                )),
              ],
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _infoRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }

  Widget _buildHistory() {
    final delivered = _history;
    final total = delivered.fold(0.0, (s, o) => s + double.parse(o['total'].toString()));
    return SafeArea(child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('/ история', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlue, letterSpacing: .8)),
          const Text('История доставок', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.5)),
          const SizedBox(height: 16),
          Row(children: [
            _statCard('✅', 'Доставлено', delivered.length, const Color(0xFF33D633)),
            const SizedBox(width: 10),
            _statCard('💰', 'Всего сом', total.toInt(), const Color(0xFFFBBF24)),
          ]),
          const SizedBox(height: 16),
        ]),
      )),
      if (delivered.isEmpty)
        SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [
          Text('📋', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('История пуста', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF71717A))),
        ])))
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (_, i) {
              final o = delivered[i];
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
                    Text('📍 ${o['address'] ?? '—'}', style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA))),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF33D633).withOpacity(.15), borderRadius: BorderRadius.circular(99)),
                      child: const Text('✅ Доставлено', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF33D633)))),
                    const SizedBox(height: 6),
                    Text('${double.parse(o['total'].toString()).toStringAsFixed(0)} сом',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ]),
              );
            },
            childCount: delivered.length,
          )),
        ),
    ]));
  }

  Widget _buildProfile() {
    return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [kBlue.withOpacity(.12), kBlue.withOpacity(.04)]),
          borderRadius: BorderRadius.circular(24), border: Border.all(color: kBlue.withOpacity(.2)),
        ),
        child: Row(children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: kBlue.withOpacity(.2), shape: BoxShape.circle),
            child: const Center(child: Text('🚴', style: TextStyle(fontSize: 32)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_user?['name'] ?? 'Доставщик', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            if (_user?['email'] != null) Text(_user!['email'], style: const TextStyle(fontSize: 13, color: Color(0xFF71717A))),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kBlue.withOpacity(.15), borderRadius: BorderRadius.circular(99)),
              child: const Text('Доставщик', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBlue))),
          ])),
        ]),
      ),
      const SizedBox(height: 16),
      _profTile('📞', 'Контакты', _user?['phone'] ?? '+996 — — —'),
      _profTile('📍', 'Регион', 'Бишкек'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
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
