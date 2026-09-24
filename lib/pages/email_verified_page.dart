import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import 'main_navigation.dart';

/// Muncul begitu link verifikasi email berhasil ditangani (deep link balik
/// ke app -- lihat main.dart `_handleIncomingLink`). Kasih tahu user
/// akunnya sudah "connected"/aktif, load data awal, lalu otomatis lanjut
/// ke halaman utama.
class EmailVerifiedPage extends StatefulWidget {
  const EmailVerifiedPage({super.key});

  @override
  State<EmailVerifiedPage> createState() => _EmailVerifiedPageState();
}

class _EmailVerifiedPageState extends State<EmailVerifiedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
    _proceed();
  }

  Future<void> _proceed() async {
    try {
      await context.read<AppState>().loadAllData().timeout(
            const Duration(seconds: 5),
          );
    } catch (e) {
      debugPrint('Peringatan: gagal load data awal setelah verifikasi: $e');
    }
    // Kasih jeda dikit biar animasi centang kelihatan dulu, jangan
    // langsung "lompat" ke halaman utama.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A0D1A) : AppTheme.blush,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Akun Terhubung! 🎉',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Email kamu berhasil diverifikasi.\nMenyiapkan akun...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[isDark ? 400 : 600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
