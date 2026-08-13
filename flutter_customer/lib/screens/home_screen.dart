import 'package:flutter/material.dart';
import '../api.dart';
import 'orders_screen.dart';

const kGreen = Color(0xFF33D633);
const kDark = Color(0xFF0F0F0D);
const kBg = Color(0xFFFAFAF7);

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List _products = [];
  Map<String, dynamic>? _user;
  final Map<int, int> _cart = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await Api.get('/products');
      _user = await Api.savedUser;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _addToCart(int id, double price) {
    setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
  }

  void _removeFromCart(int id) {
    setState(() {
      if ((_cart[id] ?? 0) > 1) {
        _cart[id] = _cart[id]! - 1;
      } else {
        _cart.remove(id);
      }
    });
  }

  int get _cartCount => _cart.values.fold(0, (a, b) => a + b);

  double get _cartTotal {
    double total = 0;
    for (final entry in _cart.entries) {
      final p = _products.firstWhere((x) => x['id'] == entry.key, orElse: () => null);
      if (p != null) total += double.parse(p['price'].toString()) * entry.value;
    }
    return total;
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    final items = _cart.entries.map((e) {
      final p = _products.firstWhere((x) => x['id'] == e.key);
      return {'product_id': e.key, 'quantity': e.value, 'price': double.parse(p['price'].toString())};
    }).toList();

    try {
      await Api.post('/orders', {
        'address': _user?['address'] ?? 'Бишкек',
        'items': items,
        'total': _cartTotal,
        'note': '',
      });
      setState(() => _cart.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Заказ принят!', style: TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: kGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logout() async {
    await Api.clearAuth();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(
        index: _tab,
        children: [
          _buildShop(),
          OrdersScreen(),
          _buildProfile(),
        ],
      ),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _navBtn(0, Icons.home_rounded, 'Магазин'),
              _navBtn(1, Icons.receipt_long_rounded, 'Заказы'),
              _navBtn(2, Icons.person_rounded, 'Профиль'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(int idx, IconData icon, String label) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? kGreen.withOpacity(.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? kGreen : const Color(0xFFA1A1AA), size: 24),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? kGreen : const Color(0xFFA1A1AA))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShop() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kGreen));
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 0),
            child: Row(
              children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('D', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)))),
                const SizedBox(width: 10),
                const Text('Daily', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kDark)),
                const Spacer(),
                if (_cartCount > 0)
                  GestureDetector(
                    onTap: _showCart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(99)),
                      child: Row(children: [
                        const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('$_cartCount · ${_cartTotal.toStringAsFixed(0)} с',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _productCard(_products[i]),
              childCount: _products.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .72,
            ),
          ),
        ),
      ],
    );
  }

  Widget _productCard(Map p) {
    final id = p['id'] as int;
    final qty = _cart[id] ?? 0;
    final price = double.parse(p['price'].toString());
    final emoji = p['image_url'] ?? '🛍️';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF4F4F5), width: 1.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80, width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 44))),
          ),
          const SizedBox(height: 10),
          Text(
            p['name'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kDark),
          ),
          Text('${price.toStringAsFixed(0)} сом', style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
          const Spacer(),
          qty == 0
              ? GestureDetector(
                  onTap: () => _addToCart(id, price),
                  child: Container(
                    width: double.infinity, height: 36,
                    decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(99)),
                    child: const Center(child: Icon(Icons.add, color: Colors.white, size: 20)),
                  ),
                )
              : Row(
                  children: [
                    _qtyBtn(Icons.remove, () => _removeFromCart(id)),
                    Expanded(child: Center(child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kDark)))),
                    _qtyBtn(Icons.add, () => _addToCart(id, price)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(99)),
        child: Icon(icon, size: 18, color: kDark),
      ),
    );
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          height: MediaQuery.of(context).size.height * .75,
          decoration: const BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFFE4E4E7), borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(alignment: Alignment.centerLeft, child: Text('Корзина', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kDark))),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _cart.entries.map((e) {
                    final p = _products.firstWhere((x) => x['id'] == e.key, orElse: () => null);
                    if (p == null) return const SizedBox();
                    final price = double.parse(p['price'].toString());
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF4F4F5)),
                      ),
                      child: Row(
                        children: [
                          Text(p['image_url'] ?? '🛍️', style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text('${(price * e.value).toStringAsFixed(0)} сом', style: const TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                            ],
                          )),
                          Row(children: [
                            GestureDetector(
                              onTap: () { _removeFromCart(e.key); setSt(() {}); },
                              child: Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(99)),
                                child: const Icon(Icons.remove, size: 16)),
                            ),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                            GestureDetector(
                              onTap: () { _addToCart(e.key, price); setSt(() {}); },
                              child: Container(width: 28, height: 28, decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(99)),
                                child: const Icon(Icons.add, size: 16, color: Colors.white)),
                            ),
                          ]),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Итого:', style: TextStyle(fontSize: 15, color: Color(0xFF71717A))),
                        Text('${_cartTotal.toStringAsFixed(0)} сом', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () { Navigator.pop(context); _checkout(); },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text('Заказать 🛒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfile() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF4F4F5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: kGreen.withOpacity(.12), borderRadius: BorderRadius.circular(99)),
                    child: const Center(child: Icon(Icons.person_rounded, size: 32, color: kGreen)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_user?['name'] ?? 'Клиент', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kDark)),
                      if (_user?['email'] != null)
                        Text(_user!['email'], style: const TextStyle(fontSize: 13, color: Color(0xFF71717A))),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: kGreen.withOpacity(.1), borderRadius: BorderRadius.circular(99)),
                    child: const Text('Клиент', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _menuTile(Icons.receipt_long_rounded, 'Мои заказы', 'История', () => setState(() => _tab = 1)),
            _menuTile(Icons.location_on_rounded, 'Адрес', 'Бишкек', null),
            _menuTile(Icons.notifications_rounded, 'Уведомления', 'О статусе', null),
            _menuTile(Icons.support_agent_rounded, 'Помощь', 'Служба поддержки', null),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Выйти', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, String sub, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF4F4F5)),
        ),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: kGreen.withOpacity(.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: kGreen, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kDark)),
                Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFA1A1AA)),
          ],
        ),
      ),
    );
  }
}
