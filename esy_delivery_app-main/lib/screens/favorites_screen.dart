import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/product_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<Api>().myFavorites();
  }

  Future<void> _refresh() async {
    final fresh = context.read<Api>().myFavorites();
    setState(() => _future = fresh);
    await fresh;
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
              '/ избранное',
              style: AppTypography.mono(
                size: 10,
                color: AppColors.brand700,
                weight: FontWeight.w700,
              ),
            ),
            Text(
              'Избранное',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
        titleSpacing: 0,
        toolbarHeight: 76,
      ),
      body: RefreshIndicator(
        color: AppColors.brand600,
        onRefresh: _refresh,
        child: FutureBuilder<List<Product>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.brand600),
              );
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 56,
                      color: AppColors.zinc200,
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Избранных товаров пока нет',
                      style: TextStyle(color: AppColors.zinc500),
                    ),
                  ),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.60,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) => ProductCard(product: items[i], index: i),
            );
          },
        ),
      ),
    );
  }
}
