import 'package:flutter/material.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'glass.dart';

class CategoryPill extends StatelessWidget {
  final Category category;
  final bool active;
  final VoidCallback? onTap;
  const CategoryPill({
    super.key,
    required this.category,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? AppColors.ink : AppColors.zinc100),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconForSlug(category.slug),
              size: 16,
              color: active ? Colors.white : AppColors.ink,
            ),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: TextStyle(
                color: active ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback? onTap;
  final int index;
  const CategoryTile({
    super.key,
    required this.category,
    this.onTap,
    this.index = 0,
  });

  static const _gradients = <List<Color>>[
    [Color(0xFFECFDF5), Color(0xFFA7F3D0)],
    [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
    [Color(0xFFFFE4E6), Color(0xFFFECDD3)],
    [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
    [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
    [Color(0xFFECFCCB), Color(0xFFD9F99D)],
    [Color(0xFFF5F5F4), Color(0xFFE7E5E4)],
    [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[index % _gradients.length];
    return Hoverable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors[1].withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -16,
              child: Icon(
                iconForSlug(category.slug),
                size: 72,
                color: colors[1].withValues(alpha: 0.35),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Открыть',
                      style: AppTypography.mono(
                        size: 10,
                        color: AppColors.brand700,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: AppColors.brand700,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
