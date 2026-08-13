import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';

// Живое отслеживание заказа: статус приходит с бэкенда (GET /orders/my,
// опрашивается раз в 5с), а не эмулируется таймером. packing = сборщик
// собирает заказ ("доставчик товарды чогулуп жатат"), transit = курьер в
// пути, delivered/completed = доставлен. Всё, что раньше было "красивой
// симуляцией" (плавающие анимации, конфетти, движение курьера по треку),
// осталось — но теперь это чисто декоративный слой поверх настоящего статуса,
// а не единственный источник правды.
enum _Stage { packing, transit, arrived }

_Stage _stageFor(String status) => switch (status) {
  'transit' => _Stage.transit,
  'delivered' || 'completed' => _Stage.arrived,
  _ => _Stage.packing, // pending | confirmed | packing
};

String _fmtDuration(Duration d) {
  final totalMin = d.inMinutes;
  if (totalMin < 60) return '$totalMin мин';
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  return '$h ч $m мин';
}

class OrderTrackingModal extends StatefulWidget {
  final Order order;
  const OrderTrackingModal({super.key, required this.order});

  static Future<void> show(BuildContext context, Order order) =>
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (_) => OrderTrackingModal(order: order),
      );

  @override
  State<OrderTrackingModal> createState() => _OrderTrackingModalState();
}

class _OrderTrackingModalState extends State<OrderTrackingModal>
    with TickerProviderStateMixin {
  late String _status;
  late _Stage _stage;
  DateTime _stageEnteredAt = DateTime.now();

  Timer? _tickTimer; // 1s — repaints elapsed-time text + cosmetic motion
  Timer? _pollTimer; // 5s — asks the backend for the real status

  late final AnimationController _floatCtrl;
  late final Animation<double> _floatY;

  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceY;

  late final AnimationController _confettiCtrl;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
    _stage = _stageFor(_status);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatY = Tween<double>(
      begin: -7,
      end: 7,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    _bounceY = Tween<double>(
      begin: 0,
      end: -12,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1.0,
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted)
        setState(() {}); // just repaints elapsed-time text + transit loop
    });
    _pollStatus();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollStatus(),
    );
  }

  Future<void> _pollStatus() async {
    if (!mounted) return;
    try {
      final orders = await context.read<Api>().myOrders();
      Order? match;
      for (final o in orders) {
        if (o.id == widget.order.id) {
          match = o;
          break;
        }
      }
      if (match == null || !mounted || match.status == _status) return;

      final nextStatus = match.status;
      setState(() => _status = nextStatus);

      if (nextStatus == 'cancelled') {
        _pollTimer?.cancel();
        return; // build() switches to the cancelled sheet below
      }

      final nextStage = _stageFor(nextStatus);
      if (nextStage != _stage) await _transitionTo(nextStage);
      if (nextStage == _Stage.arrived) _pollTimer?.cancel();
    } catch (_) {
      // Сеть могла моргнуть — просто попробуем ещё раз через 5с, старый
      // статус на экране остаётся видимым, ничего не ломаем.
    }
  }

  Future<void> _transitionTo(_Stage next) async {
    await _fadeCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _stage = next;
      _stageEnteredAt = DateTime.now();
    });
    _fadeCtrl.forward();
  }

  // Декоративная "всё ещё едет" анимация — курьер плавно ходит туда-сюда по
  // треку, пока статус остаётся transit. Не привязана к реальному расстоянию
  // или ETA (бэкенд их не считает), поэтому не должна выглядеть как таймер.
  double get _transitProgress {
    const cycle = 9.0;
    final secs =
        DateTime.now().difference(_stageEnteredAt).inMilliseconds / 1000;
    final tri = (secs % (cycle * 2)) / cycle; // 0..2
    return tri <= 1 ? tri : 2 - tri; // 0..1..0
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pollTimer?.cancel();
    _floatCtrl.dispose();
    _bounceCtrl.dispose();
    _confettiCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == 'cancelled') return _cancelledSheet();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _header(),
          _scene(),
          _steps(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _cancelledSheet() => Container(
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
    padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        const SizedBox(height: 14),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFFEE2E2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            color: Color(0xFFDC2626),
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Заказ отменён',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B0F0D),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Заказ #${widget.order.id} был отменён',
          style: const TextStyle(fontSize: 13, color: Color(0xFF71717A)),
        ),
        const SizedBox(height: 20),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Закрыть',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _handle() => Container(
    width: 36,
    height: 4,
    margin: const EdgeInsets.only(top: 10, bottom: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE4E4E7),
      borderRadius: BorderRadius.circular(99),
    ),
  );

  Widget _header() {
    final elapsed = DateTime.now().difference(widget.order.createdAt);
    final (title, sub) = switch (_stage) {
      _Stage.packing => ('Собираем заказ', 'Уже ${_fmtDuration(elapsed)}'),
      _Stage.transit => ('Курьер в пути', 'В пути ${_fmtDuration(elapsed)}'),
      _Stage.arrived => ('Заказ доставлен!', 'Заняло ${_fmtDuration(elapsed)}'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B0F0D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _stage == _Stage.arrived
                  ? AppColors.brand500
                  : Colors.black,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '#${widget.order.id}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scene() {
    final bg = switch (_stage) {
      _Stage.packing => const Color(0xFFF0FDF4),
      _Stage.transit => const Color(0xFFEFF6FF),
      _Stage.arrived => const Color(0xFFF0FDF4),
    };
    return FadeTransition(
      opacity: _fade,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        height: 230,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: switch (_stage) {
          _Stage.packing => _PackingScene(floatY: _floatY),
          _Stage.transit => _TransitScene(progress: _transitProgress),
          _Stage.arrived => _ArrivedScene(
            bounceY: _bounceY,
            confettiCtrl: _confettiCtrl,
          ),
        },
      ),
    );
  }

  Widget _steps() {
    const stages = [
      (Icons.inventory_2_outlined, 'Сборка'),
      (Icons.electric_scooter_outlined, 'В пути'),
      (Icons.door_front_door_outlined, 'Прибыл'),
    ];
    final idx = _stage.index;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: List.generate(stages.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = i ~/ 2 < idx;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                height: 2,
                margin: const EdgeInsets.only(bottom: 20),
                color: done ? AppColors.brand500 : const Color(0xFFE4E4E7),
              ),
            );
          }
          final si = i ~/ 2;
          final (icon, label) = stages[si];
          final active = si == idx;
          final done = si < idx;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: done || active
                      ? AppColors.brand500
                      : const Color(0xFFF4F4F5),
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.brand500.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  done ? Icons.check_rounded : icon,
                  size: 18,
                  color: done || active
                      ? Colors.white
                      : const Color(0xFF71717A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.brand500 : const Color(0xFF71717A),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Stage 1: Packing ────────────────────────────────────────────────────────

class _PackingScene extends StatelessWidget {
  final Animation<double> floatY;
  const _PackingScene({required this.floatY});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: floatY,
    builder: (_, child) =>
        Transform.translate(offset: Offset(0, floatY.value), child: child),
    child: const Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Image(
        image: AssetImage('assets/images/stage_packing.png'),
        fit: BoxFit.contain,
      ),
    ),
  );
}

// ─── Stage 2: Transit — courier moves left→right based on elapsed progress ───

class _TransitScene extends StatelessWidget {
  final double progress; // 0.0 = start, 1.0 = arrived
  const _TransitScene({required this.progress});

  @override
  Widget build(BuildContext context) {
    const courierW = 130.0;
    const roadPad = 20.0;
    const dotR = 7.0;

    return LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth;
        final trackW = w - roadPad * 2 - courierW;
        final courierLeft = roadPad + progress * trackW;
        final roadProgress = progress * (w - roadPad * 2);

        return Stack(
          children: [
            // Road track (unfilled)
            Positioned(
              bottom: 50,
              left: roadPad,
              right: roadPad,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE3F0),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            // Road track (filled = traveled)
            Positioned(
              bottom: 50,
              left: roadPad,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                width: roadProgress.clamp(0.0, w - roadPad * 2),
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.brand500.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            // Start dot
            Positioned(
              bottom: 50 - dotR / 2 + 1,
              left: roadPad - dotR / 2,
              child: Container(
                width: dotR + 4,
                height: dotR + 4,
                decoration: BoxDecoration(
                  color: AppColors.brand500,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // End dot
            Positioned(
              bottom: 50 - dotR / 2 + 1,
              right: roadPad - dotR / 2,
              child: Container(
                width: dotR + 4,
                height: dotR + 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE3F0),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Courier — position updates every second, smooth with AnimatedPositioned
            AnimatedPositioned(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              bottom: 53,
              left: courierLeft,
              child: Image.asset(
                'assets/images/stage_transit.png',
                width: courierW,
                fit: BoxFit.contain,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Stage 3: Arrived ────────────────────────────────────────────────────────

class _ArrivedScene extends StatelessWidget {
  final Animation<double> bounceY;
  final AnimationController confettiCtrl;
  const _ArrivedScene({required this.bounceY, required this.confettiCtrl});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AnimatedBuilder(
        animation: confettiCtrl,
        builder: (_, __) => CustomPaint(
          size: const Size(double.infinity, double.infinity),
          painter: _ConfettiPainter(confettiCtrl.value),
        ),
      ),
      AnimatedBuilder(
        animation: bounceY,
        builder: (_, child) =>
            Transform.translate(offset: Offset(0, bounceY.value), child: child),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 36),
            child: Image(
              image: AssetImage('assets/images/stage_arrived.png'),
              height: 172,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      Positioned(
        top: 12,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brand500,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand500.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text(
              'Заказ доставлен!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static const _colors = [
    Color(0xFF33D633),
    Color(0xFF60A5FA),
    Color(0xFFFBBF24),
    Color(0xFFF472B6),
    Color(0xFFA78BFA),
    Color(0xFFFB923C),
    Color(0xFF34D399),
    Color(0xFFFC8181),
  ];
  static const _positions = [
    (0.12, 0.18),
    (0.32, 0.08),
    (0.52, 0.22),
    (0.74, 0.12),
    (0.90, 0.28),
    (0.08, 0.48),
    (0.42, 0.38),
    (0.62, 0.52),
    (0.82, 0.58),
    (0.22, 0.62),
    (0.48, 0.72),
    (0.70, 0.78),
    (0.28, 0.82),
    (0.60, 0.88),
    (0.85, 0.85),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _positions.length; i++) {
      final (px, py) = _positions[i];
      final phase = (t + i * 0.067) % 1.0;
      final x = px * size.width;
      final y = (py + phase * 0.65) % 1.0 * size.height;
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: 0.75);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(phase * 6.28);
      canvas.drawRect(const Rect.fromLTWH(-4.5, -4.5, 9, 9), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
