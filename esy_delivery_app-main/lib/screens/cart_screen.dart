import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../cart.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'checkout_screen.dart';

class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 24),
      child: Container(
        height: h * 0.92,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const _DragHandle(),
            const _CartHeader(),
            const Expanded(child: _CartList()),
            const _CartFooter(),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.zinc200,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader();
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartStore>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '/ ${cart.totalItems > 0 ? "${cart.totalItems} в корзине" : "пусто"}',
                  style: AppTypography.mono(
                    size: 11,
                    color: AppColors.brand700,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ваш заказ',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ],
            ),
          ),
          if (!cart.isEmpty)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<CartStore>().clear();
              },
              child: const Text('Очистить'),
            ),
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.zinc100,
              foregroundColor: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartList extends StatelessWidget {
  const _CartList();
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartStore>();
    if (cart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  size: 40,
                  color: AppColors.brand600,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Пока пусто',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Добавьте что-нибудь из каталога',
                style: TextStyle(color: AppColors.zinc500),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => Navigator.maybePop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  'К каталогу',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CartRow(item: cart.items[i]),
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  const _CartRow({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.zinc100),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.zinc100,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              iconForSlug(item.slug),
              size: 26,
              color: AppColors.ink.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatPrice(item.priceCents)} / ${unitLabel(item.unit)}',
                  style: const TextStyle(
                    color: AppColors.zinc500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.zinc100,
              borderRadius: BorderRadius.circular(99),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _step(Icons.remove_rounded, () {
                  HapticFeedback.selectionClick();
                  context.read<CartStore>().setQty(
                    item.productId,
                    item.quantity - 1,
                  );
                }),
                SizedBox(
                  width: 30,
                  child: Center(
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                _step(Icons.add_rounded, () {
                  HapticFeedback.selectionClick();
                  context.read<CartStore>().setQty(
                    item.productId,
                    item.quantity + 1,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Icon(icon, size: 18, color: AppColors.ink),
    ),
  );
}

class _CartFooter extends StatelessWidget {
  const _CartFooter();
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartStore>();
    final empty = cart.isEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAF7),
        border: Border(top: BorderSide(color: AppColors.zinc100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Итого',
                style: TextStyle(color: AppColors.zinc600, fontSize: 15),
              ),
              const Spacer(),
              Text(
                formatPrice(cart.totalCents),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: empty
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand600,
              disabledBackgroundColor: AppColors.zinc200,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Оформить заказ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
