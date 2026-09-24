import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../pages/notification_page.dart';

/// Tombol lonceng notifikasi + badge jumlah belum dibaca. Dipakai di header
/// Home & Explore, di sebelah ikon keranjang.
class NotificationBellButton extends StatelessWidget {
  final bool isDark;
  final double size;

  const NotificationBellButton({super.key, required this.isDark, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<AppState>().unreadNotificationCount;
    return Semantics(
      label: 'Notifikasi, $unread belum dibaca',
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationPage()),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3D2040) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.notifications_outlined, color: AppTheme.primary),
            ),
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
