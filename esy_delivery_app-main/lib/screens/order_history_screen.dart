import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'order_tracking_modal.dart';
import 'receipt_screen.dart';

const _statusLabel = {
  'pending': 'В ожидании',
  'confirmed': 'Подтверждён',
  'packing': 'Собирается',
  'transit': 'В пути',
  'delivered': 'Доставлен',
  'completed': 'Завершён',
  'cancelled': 'Отменён',
};

const _statusColor = {
  'pending': Color(0xFFD97706),
  'confirmed': Color(0xFF0284C7),
  'packing': Color(0xFF9333EA),
  'transit': Color(0xFFEA580C),
  'delivered': Color(0xFF16A34A),
  'completed': Color(0xFF15803D),
  'cancelled': Color(0xFFDC2626),
};

// Заполняет мёртвый пункт меню "История заказов" в профиле: список всех
// заказов клиента, активные открываются в живом отслеживании
// (order_tracking_modal.dart), остальные — просто запись в списке.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<Api>().myOrders();
  }

  Future<void> _refresh() async {
    final fresh = context.read<Api>().myOrders();
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
              '/ история',
              style: AppTypography.mono(
                size: 10,
                color: AppColors.brand700,
                weight: FontWeight.w700,
              ),
            ),
            Text(
              'Ваши заказы',
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
        child: FutureBuilder<List<Order>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.brand600),
              );
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Text(
                      'Не удалось загрузить заказы',
                      style: TextStyle(color: AppColors.zinc500),
                    ),
                  ),
                ],
              );
            }
            final orders = snap.data ?? [];
            if (orders.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 56,
                      color: AppColors.zinc200,
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Заказов пока нет',
                      style: TextStyle(color: AppColors.zinc500),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: orders.length,
              itemBuilder: (context, i) => _OrderTile(order: orders[i]),
            );
          },
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor[order.status] ?? AppColors.zinc500;
    final label = _statusLabel[order.status] ?? order.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.zinc100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: order.isActive
              ? () => OrderTrackingModal.show(context, order)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    order.isActive
                        ? Icons.local_shipping_outlined
                        : Icons.check_circle_outline_rounded,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Заказ #${order.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _fmtDate(order.createdAt),
                        style: const TextStyle(
                          color: AppColors.zinc500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPrice(order.totalCents),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => showReceipt(context, order),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.zinc100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 16,
                      color: AppColors.zinc600,
                    ),
                  ),
                ),
                if (order.isActive) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.zinc400,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${d.day} ${months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
