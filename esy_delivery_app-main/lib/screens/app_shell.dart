import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../cart.dart';
import '../favorites.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'home_screen.dart';
import 'categories_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // AppShell кайра түзүлгөн сайын (ар бир логин) — тандалмаларды серверден
    // жаңыртат, ProductCard'дагы жүрөктөр туура көрүнүшү үчүн.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<FavoritesStore>().load(),
    );
  }

  static const _pages = <Widget>[
    HomeScreen(),
    CategoriesScreen(),
    SizedBox.shrink(),
    ProfileScreen(),
  ];

  void _go(int i) {
    if (i == 2) {
      _openCart();
    } else {
      setState(() => _index = i);
    }
  }

  Future<void> _openCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const CartSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _BottomDock(active: _index, onTap: _go),
        ),
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  final int active;
  final ValueChanged<int> onTap;
  const _BottomDock({required this.active, required this.onTap});

  static const _items = [
    ('Главная', Icons.home_rounded),
    ('Категории', Icons.grid_view_rounded),
    ('Корзина', Icons.shopping_bag_rounded),
    ('Профиль', Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartStore>();
    return Glass(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: List.generate(_items.length, (i) {
          if (i == 2)
            return Expanded(
              child: _CartButton(
                active: false,
                count: cart.totalItems,
                onTap: () => onTap(i),
              ),
            );
          final (label, icon) = _items[i];
          final isActive = active == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 56,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 22,
                  color: isActive ? Colors.white : AppColors.zinc500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onTap;
  const _CartButton({
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.brand600,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand600.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_rounded,
              color: Colors.white,
              size: 24,
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent500,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
