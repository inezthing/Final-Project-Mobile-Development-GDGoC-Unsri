import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoggingOut = false; // BARU: loading state untuk logout

  // ==========================================
  // LOGOUT — pakai AppState.signOut() agar state bersih
  // ==========================================
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Keluar dari akun?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Kamu akan keluar dari akun Whimsify kamu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      // signOut di AppState membersihkan semua state lokal sekaligus
      await context.read<AppState>().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal keluar: ${e.toString()}'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan ⚙️'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Tampilan'),
              const SizedBox(height: 10),

              _settingsCard(
                isDark: isDark,
                children: [
                  Semantics(
                    label: 'Pilihan tema aplikasi',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎨 Tema',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _themeOption(
                              label: '☀️ Terang',
                              isSelected: state.themeMode == ThemeMode.light,
                              // setThemeMode di AppState sekarang auto-persist ke SharedPreferences
                              onTap: () => state.setThemeMode(ThemeMode.light),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _themeOption(
                              label: '🌙 Gelap',
                              isSelected: state.themeMode == ThemeMode.dark,
                              onTap: () => state.setThemeMode(ThemeMode.dark),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _themeOption(
                              label: '⚙️ Sistem',
                              isSelected: state.themeMode == ThemeMode.system,
                              onTap: () => state.setThemeMode(ThemeMode.system),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _sectionHeader('Akun'),
              const SizedBox(height: 10),

              _settingsCard(
                isDark: isDark,
                children: [
                  _navRow(
                    label: '👤 Edit Profil',
                    isDark: isDark,
                    textColor: textColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfilePage(),
                      ),
                    ),
                  ),
                  Divider(
                    color: isDark ? Colors.white10 : Colors.grey[100],
                    height: 20,
                  ),
                  _navRow(
                    label: '🔒 Keamanan & Privasi',
                    isDark: isDark,
                    textColor: textColor,
                  ),
                  Divider(
                    color: isDark ? Colors.white10 : Colors.grey[100],
                    height: 20,
                  ),
                  _navRow(
                    label: '📦 Pesanan Saya',
                    isDark: isDark,
                    textColor: textColor,
                  ),
                ],
              ),

              const SizedBox(height: 16),
              _sectionHeader('Tentang'),
              const SizedBox(height: 10),

              _settingsCard(
                isDark: isDark,
                children: [
                  _infoRow('Versi Aplikasi', '1.0.0', isDark, textColor),
                  Divider(
                    color: isDark ? Colors.white10 : Colors.grey[100],
                    height: 20,
                  ),
                  _infoRow('Developer', 'Whimsify Team', isDark, textColor),
                  Divider(
                    color: isDark ? Colors.white10 : Colors.grey[100],
                    height: 20,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💚 Misi Kami',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Whimsify hadir untuk membantu barang preloved menemukan rumah baru, mengurangi waste, dan membangun komunitas yang saling mendukung.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[500],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ==========================================
              // TOMBOL LOGOUT — pakai _handleLogout()
              // ==========================================
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoggingOut ? null : _handleLogout,
                  icon: _isLoggingOut
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        )
                      : const Icon(Icons.logout, size: 16, color: Colors.red),
                  label: Text(
                    _isLoggingOut ? 'Keluar...' : 'Keluar',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red[200]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _settingsCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _themeOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? const Color(0xFF3D2040) : AppTheme.blush),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : AppTheme.primaryDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navRow({
    required String label,
    required bool isDark,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: textColor,
                fontSize: 14,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white30 : Colors.grey[300],
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: textColor,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.grey[400],
          ),
        ),
      ],
    );
  }
}
