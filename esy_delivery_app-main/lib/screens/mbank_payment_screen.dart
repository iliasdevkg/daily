import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/blob_background.dart';
import '../widgets/glass.dart';
import 'order_success_screen.dart';
import 'receipt_screen.dart';

// M-Bank менен келишим азырынча жок болгондуктан, чыныгы банк deep-link'ине
// акча жиберүү аракети (мурун: mbank://p2p?phone=... менен таптакыр белгисиз/
// коюлбаган номерге которуу) алынып салынды — бул чыныгы акчаны туура эмес
// дарекке жиберип коюшу мүмкүн болчу. Азыр: заказ ырасталат, чек көрсөтүлөт,
// төлөм тапшыруу учурунда (накталай/картага) чогултулат — receipt_screen.dart.
class MBankPaymentScreen extends StatelessWidget {
  final Order order;
  const MBankPaymentScreen({super.key, required this.order});

  Future<void> _confirm(BuildContext context) async {
    HapticFeedback.heavyImpact();
    await showReceipt(context, order);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = formatPrice(order.totalCents);
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: BlobBackground(
        dark: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton.filled(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '/ подтверждение',
                          style: AppTypography.mono(
                            size: 10,
                            color: AppColors.brand300,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Ваш заказ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassDark(
                  borderRadius: BorderRadius.circular(32),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.brand500,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brand500.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        amount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Заказ #${order.id}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 24),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.brand600.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.brand600.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.brand300,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Онлайн-төлөм азырынча жеткиликсиз — сумма курьерге накталай же картага тапшыруу учурунда өткөрүлөт',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _confirm(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand500,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Подтвердить заказ',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
