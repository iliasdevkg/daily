import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../cart.dart';
import '../favorites.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'glass.dart';

const _tileGradients = <List<Color>>[
  [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
  [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
  [Color(0xFFFFE4E6), Color(0xFFFECDD3)],
  [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
  [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
  [Color(0xFFECFCCB), Color(0xFFD9F99D)],
  [Color(0xFFF5F5F4), Color(0xFFE7E5E4)],
  [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
];

class ProductCard extends StatelessWidget {
  final Product product;
  final int index;
  final VoidCallback? onTap;
  final bool large;
  const ProductCard({
    super.key,
    required this.product,
    this.index = 0,
    this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartStore>();
    final favorites = context.watch<FavoritesStore>();
    final qty = cart.quantityOf(product.id);
    final isFav = favorites.isFavorite(product.id);
    final colors = _tileGradients[index % _tileGradients.length];

    return Hoverable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.zinc100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: large ? 16 / 9 : 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        iconForSlug(product.slug),
                        size: large ? 96 : 56,
                        color: AppColors.ink.withValues(alpha: 0.5),
                      ),
                    ),
                    if (product.badge != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            product.badge!.toUpperCase(),
                            style: AppTypography.mono(
                              size: 9,
                              color: Colors.white,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.read<FavoritesStore>().toggle(product.id);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 16,
                            color: isFav
                                ? const Color(0xFFEF4444)
                                : AppColors.zinc400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (product.categoryName != null)
              Text(
                product.categoryName!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono(size: 9, color: AppColors.zinc400),
              ),
            const SizedBox(height: 2),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: large ? 22 : 15),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatPrice(product.priceCents),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'за ${unitLabel(product.unit)}',
                        style: AppTypography.mono(
                          size: 10,
                          color: AppColors.zinc400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (qty == 0)
                  _AddButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.read<CartStore>().add(product);
                    },
                  )
                else
                  _QtyStepper(
                    qty: qty,
                    onMinus: () =>
                        context.read<CartStore>().setQty(product.id, qty - 1),
                    onPlus: () {
                      HapticFeedback.lightImpact();
                      context.read<CartStore>().setQty(product.id, qty + 1);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Hoverable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.zinc100,
        borderRadius: BorderRadius.circular(99),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepIcon(Icons.remove_rounded, onMinus),
          SizedBox(
            width: 28,
            child: Center(
              child: Text(
                '$qty',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          _stepIcon(Icons.add_rounded, onPlus),
        ],
      ),
    );
  }

  Widget _stepIcon(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: AppColors.ink),
    ),
  );
}
