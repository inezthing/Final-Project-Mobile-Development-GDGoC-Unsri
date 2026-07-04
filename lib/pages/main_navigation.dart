import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'community_page.dart';
import 'explore_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'sell_page.dart';

/// Halaman "shell" utama setelah login — berisi bottom navigation bar
/// (Home, Explore, tombol Jual di tengah, Komunitas, Profil) dan menampilkan
/// halaman yang sesuai berdasarkan tab yang sedang aktif.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Index tab yang sedang aktif (0=Home, 1=Explore, 3=Komunitas, 4=Profil).
  // Catatan: index 2 sengaja dilewati karena itu "slot" untuk tombol Jual (FAB)
  int _currentIndex = 0;

  /// Pilih halaman mana yang ditampilkan berdasarkan tab aktif.
  Widget _buildPage() {
    switch (_currentIndex) {
      case 0:
        return const HomePage();
      case 1:
        return const ExplorePage();
      case 3:
        return const CommunityPage();
      case 4:
        return const ProfilePage();
      default:
        return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPage(),
      // Tombol bulat "+" untuk jual barang, posisinya nyempil di tengah
      // bottom nav (mengambang di atas notch)
      floatingActionButton: const _SellFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

/// Tombol bulat mengambang (Floating Action Button) untuk membuka halaman Sell.
class _SellFab extends StatelessWidget {
  const _SellFab();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Jual barang baru', // label accessibility
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SellPage()),
        ),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// Bottom navigation bar dengan lekukan (notch) di tengah untuk tempat
/// tombol Sell "duduk". Berisi 4 tombol navigasi + 1 spasi kosong di tengah.
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BottomAppBar(
      color: isDark ? const Color(0xFF1A0D1A) : Colors.white,
      elevation: 8,
      notchMargin: 8, // jarak antara notch dan tombol FAB
      shape: const CircularNotchedRectangle(), // bentuk lekukan melingkar untuk FAB
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              index: 0,
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              index: 1,
              icon: Icons.explore_outlined,
              activeIcon: Icons.explore,
              label: 'Explore',
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            // Ruang kosong selebar tombol FAB, supaya tombol Sell (index 2)
            // punya tempat "duduk" di tengah tanpa nabrak nav item lain
            const SizedBox(width: 60),
            _NavItem(
              index: 3,
              icon: Icons.people_outline,
              activeIcon: Icons.people,
              label: 'Komunitas',
              currentIndex: currentIndex,
              onTap: onTap,
            ),
            _NavItem(
              index: 4,
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profil',
              currentIndex: currentIndex,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu tombol item di bottom nav (icon + label), berubah warna & icon
/// (outline -> filled) kalau sedang aktif/dipilih.
class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final void Function(int) onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    return Semantics(
      label: label,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque, // area kosong di sekitar icon tetap bisa di-tap
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppTheme.primary : Colors.grey[400],
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? AppTheme.primary : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}