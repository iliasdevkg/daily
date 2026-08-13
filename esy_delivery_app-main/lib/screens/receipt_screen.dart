import 'package:flutter/material.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';

// Чек: M-Bank менен келишим азырынча жок болгондуктан (расчёт эсеби
// туташтырылганча), чыныгы банк транзакциясын ырастоонун ордуна — заказдын
// кабыл алынганын көрсөткөн жөнөкөй квитанция чыгарылат. Бул жерде эч кандай
// накта төлөм текшерилбейт (mbank_payment_screen.dart мурунку deep-link
// аракети алынып салынды — келишимсиз чыныгы номерге акча жиберүү коркунучтуу
// болмок). Чыныгы M-Bank интеграциясы кошулганда, бул модалдын ордуна накта
// транзакция ырастоосу коюлат.
Future<void> showReceipt(BuildContext context, Order order) =>
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ReceiptSheet(order: order),
    );

class ReceiptSheet extends StatelessWidget {
  final Order order;
  const ReceiptSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE4E4E7),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.brand500,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand500.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Чек',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0B0F0D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Заказ #${order.id} кабыл алынды',
            style: const TextStyle(fontSize: 13, color: Color(0xFF71717A)),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _row('Дата', _fmtDate(order.createdAt)),
                if (order.address != null) ...[
                  const SizedBox(height: 10),
                  _divider(),
                  const SizedBox(height: 10),
                  _row('Дарек', order.address!),
                ],
                const SizedBox(height: 10),
                _divider(),
                const SizedBox(height: 10),
                _row('Сумма', formatPrice(order.totalCents), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brand50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.brand700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Оплата — курьерге накталай же картага, тапшыруу учурунда',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF3F3F46),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
              ),
              child: const Text(
                'Түшүндүм',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: Color(0xFF71717A)),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: bold ? 16 : 13.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: const Color(0xFF0B0F0D),
          ),
        ),
      ),
    ],
  );

  Widget _divider() => Container(height: 1, color: const Color(0xFFE4E4E7));

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
