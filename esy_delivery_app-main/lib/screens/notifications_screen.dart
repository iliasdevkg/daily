import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<Api>().myNotifications();
  }

  Future<void> _refresh() async {
    final fresh = context.read<Api>().myNotifications();
    setState(() => _future = fresh);
    await fresh;
  }

  Future<void> _markRead(NotificationItem n, List<NotificationItem> all) async {
    if (n.read) return;
    try {
      await context.read<Api>().markNotificationRead(n.id);
      final idx = all.indexWhere((x) => x.id == n.id);
      if (idx >= 0) {
        setState(() {
          all[idx] = NotificationItem(
            id: n.id,
            title: n.title,
            message: n.message,
            read: true,
            orderId: n.orderId,
            createdAt: n.createdAt,
          );
        });
      }
    } catch (_) {}
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
              '/ билдирмелер',
              style: AppTypography.mono(
                size: 10,
                color: AppColors.brand700,
                weight: FontWeight.w700,
              ),
            ),
            Text(
              'Уведомления',
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
        child: FutureBuilder<List<NotificationItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.brand600),
              );
            }
            if (snap.hasError) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      'Не удалось загрузить уведомления',
                      style: TextStyle(color: AppColors.zinc500),
                    ),
                  ),
                ],
              );
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: AppColors.zinc200,
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Уведомлений пока нет',
                      style: TextStyle(color: AppColors.zinc500),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final n = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: n.read ? Colors.white : AppColors.brand50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: n.read
                          ? AppColors.zinc100
                          : AppColors.brand200.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _markRead(n, items),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!n.read)
                              Container(
                                margin: const EdgeInsets.only(
                                  top: 5,
                                  right: 10,
                                ),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.brand500,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontWeight: n.read
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (n.message != null &&
                                      n.message!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      n.message!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.zinc600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    _fmt(n.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.zinc400,
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
            );
          },
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
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
