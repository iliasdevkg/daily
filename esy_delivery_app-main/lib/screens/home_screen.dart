import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/blob_background.dart';
import '../widgets/category_pill.dart';
import '../widgets/glass.dart';
import '../widgets/product_card.dart';
import 'categories_screen.dart';
import 'category_detail_screen.dart';
import 'order_tracking_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<({List<Category> cats, List<Product> products})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<Category> cats, List<Product> products})> _load() async {
    final api = context.read<Api>();
    final results = await Future.wait([
      api.categories(),
      api.products(limit: 12),
    ]);
    return (
      cats: results[0] as List<Category>,
      products: results[1] as List<Product>,
    );
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlobBackground(
        child: RefreshIndicator(
          color: AppColors.brand600,
          backgroundColor: Colors.white,
          onRefresh: _refresh,
          child: FutureBuilder(
            future: _future,
            builder: (context, snap) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _IslandAppBar(),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(child: _Hero()),
                  const SliverToBoxAdapter(child: _PromoCarousel()),
                  if (snap.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brand600,
                          ),
                        ),
                      ),
                    )
                  else if (snap.hasError)
                    SliverToBoxAdapter(
                      child: _ErrorBanner(error: snap.error.toString()),
                    )
                  else if (snap.hasData) ...[
                    SliverToBoxAdapter(
                      child: _CategoriesRow(cats: snap.data!.cats),
                    ),
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        small: 'популярное',
                        big: 'Свежее и любимое',
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.60,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => ProductCard(
                            product: snap.data!.products[i],
                            index: i,
                          ),
                          childCount: snap.data!.products.length,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Верхняя таблетка теперь ведёт на живое отслеживание настоящего активного
// заказа (если он есть), а не на фиксированную демо-анимацию.
Future<void> _openActiveOrderTracking(BuildContext context) async {
  try {
    final orders = await context.read<Api>().myOrders();
    final active = orders.where((o) => o.isActive).toList();
    if (active.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Активных заказов нет')));
      }
      return;
    }
    if (context.mounted) await OrderTrackingModal.show(context, active.first);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось получить статус заказа')),
      );
    }
  }
}

class _IslandAppBar extends StatelessWidget {
  const _IslandAppBar();
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).top;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, pad + 8, 12, 4),
        child: Row(
          children: [
            Glass(
              borderRadius: BorderRadius.circular(99),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.brand500,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand500.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'D',
                      style: GoogleFonts.pacifico(
                        color: Colors.white,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Daily',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openActiveOrderTracking(context),
              child: Glass(
                borderRadius: BorderRadius.circular(99),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.brand500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Бишкек · 30 мин',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.zinc500,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.displaySmall,
          children: [
            const TextSpan(text: 'Свежее к двери '),
            TextSpan(
              text: 'за 30 минут.',
              style: const TextStyle(color: AppColors.brand500),
            ),
          ],
        ),
      ),
    );
  }
}

// Скидка/акция баннерлери — купон-стилиндеги жарнама (белги + сан + баскыч),
// мурунку "статистика" карточкаларынын ордуна. Backend'де чыныгы купон-
// система жок болгондуктан (колдонуучу менен макулдашылды — таза визуалдык
// кайра дизайн), белгилер so куратталган/статикалык, бирок баскычтын өзү
// бош эмес — Категорияларга алып барат, "өлүк баскыч" болбошу үчүн.
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();
  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  static const _kInitPage = 5000;
  late final PageController _ctrl;
  Timer? _timer;
  double _page = _kInitPage.toDouble();
  int _current = 0;

  static const _items = [
    (
      icon: Icons.eco_rounded,
      badge: '-20%',
      title: 'Овощи и зелень',
      sub: 'Акция до конца недели',
      cta: 'Получить',
      c1: Color(0xFF4ADE80),
      c2: Color(0xFF16A34A),
    ),
    (
      icon: Icons.pedal_bike_rounded,
      badge: '0 сом',
      title: 'Бесплатная доставка',
      sub: 'При заказе от 1500 сом',
      cta: 'Заказать',
      c1: Color(0xFF38BDF8),
      c2: Color(0xFF0284C7),
    ),
    (
      icon: Icons.bakery_dining_rounded,
      badge: '-15%',
      title: 'Свежая выпечка',
      sub: 'Только сегодня',
      cta: 'Получить',
      c1: Color(0xFFFBBF24),
      c2: Color(0xFFD97706),
    ),
    (
      icon: Icons.icecream_rounded,
      badge: '-10%',
      title: 'Молочные продукты',
      sub: 'На весь ассортимент',
      cta: 'Получить',
      c1: Color(0xFF60A5FA),
      c2: Color(0xFF2563EB),
    ),
    (
      icon: Icons.celebration_rounded,
      badge: '-25%',
      title: 'Первый заказ',
      sub: 'Промокод: DAILY25',
      cta: 'Заказать',
      c1: Color(0xFFC084FC),
      c2: Color(0xFF7C3AED),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.80, initialPage: _kInitPage);
    _ctrl.addListener(() {
      final p = _ctrl.page ?? _kInitPage.toDouble();
      if ((p - _page).abs() > 0.003) setState(() => _page = p);
    });
    _timer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      _ctrl.animateToPage(
        (_ctrl.page?.round() ?? _kInitPage) + 1,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: PageView.builder(
              controller: _ctrl,
              padEnds: false,
              itemCount: _items.length * 99999,
              onPageChanged: (i) =>
                  setState(() => _current = i % _items.length),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemBuilder: (_, i) {
                final diff = (_page - i).abs().clamp(0.0, 1.0);
                final scale = 1.0 - diff * 0.048;
                final item = _items[i % _items.length];
                return Padding(
                  padding: const EdgeInsets.only(
                    left: 9,
                    right: 0,
                    top: 3,
                    bottom: 10,
                  ),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoriesScreen(),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [item.c1, item.c2],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: item.c1.withValues(alpha: 0.30),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              right: -28,
                              top: -28,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.07),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              bottom: -18,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 4,
                              child: Icon(
                                item.icon,
                                size: 76,
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                18,
                                22,
                                18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      item.badge,
                                      style: TextStyle(
                                        color: item.c2,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      height: 1.08,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.sub,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.cta,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_items.length, (i) {
              final active = i == _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.brand500 : AppColors.zinc200,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CategoriesRow extends StatelessWidget {
  final List<Category> cats;
  const _CategoriesRow({required this.cats});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(small: 'категории', big: 'Что вам сегодня?'),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => CategoryPill(
              category: cats[i],
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CategoryDetailScreen(category: cats[i]),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cats.length.clamp(0, 6),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (_, i) => CategoryTile(
              category: cats[i],
              index: i,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CategoryDetailScreen(category: cats[i]),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String small;
  final String big;
  const _SectionHeader({required this.small, required this.big});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Text(big, style: Theme.of(context).textTheme.headlineLarge),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Text(
          'Не удалось загрузить данные.\n$error',
          style: const TextStyle(color: Color(0xFF92400E)),
        ),
      ),
    );
  }
}
