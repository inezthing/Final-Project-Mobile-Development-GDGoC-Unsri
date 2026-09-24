import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Halaman daftar notifikasi -- pesanan baru masuk, status pesanan
/// berubah, dst. Diisi otomatis oleh function Postgres di backend
/// (place_order, mark_order_processing, mark_order_shipped, ...).
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context.read<AppState>().loadNotifications();
    if (mounted) setState(() => _isLoading = false);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'order_placed':
        return Icons.check_circle_outline;
      case 'order_incoming':
        return Icons.storefront_outlined;
      case 'order_processing':
        return Icons.inventory_2_outlined;
      case 'order_shipped':
        return Icons.local_shipping_outlined;
      case 'order_completed':
        return Icons.task_alt;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<AppState>().notifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => context.read<AppState>().markAllNotificationsRead(),
              child: const Text('Tandai semua dibaca'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Belum ada notifikasi', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => context.read<AppState>().loadNotifications(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.read<AppState>().markNotificationRead(n.id),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: n.isRead
                                ? (isDark ? const Color(0xFF2D1B2E) : Colors.white)
                                : AppTheme.blush.withOpacity(isDark ? 0.15 : 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_iconFor(n.type), size: 18, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: TextStyle(
                                        fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                                        fontSize: 13,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      n.body,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _timeAgo(n.createdAt),
                                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                              if (!n.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
