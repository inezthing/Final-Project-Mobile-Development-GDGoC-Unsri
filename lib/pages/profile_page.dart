import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'seller_product_edit_page.dart';
import 'settings_page.dart';
import 'chat_list_page.dart';
import '../data/supabase_service.dart';
import 'order_list_page.dart';
import 'seller_orders_page.dart';

// Halaman profil: info user, statistik, produk & postingan milik sendiri
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // StatelessWidget boleh pakai watch hanya jika di dalam MaterialApp tree
    // Tapi lebih aman pakai Consumer
    return Consumer<AppState>(
      builder: (context, state, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);
        final subColor = isDark ? Colors.white54 : Colors.grey[500]!;
        final currentUserId = SupabaseService().currentUser?.id;
        // Filter produk & post milik user yang sedang login
        final myProducts =
            state.products.where((p) => p.sellerId == currentUserId).toList();
        final myPosts =
            state.posts.where((p) => p.userId == currentUserId).toList();
        final username = state.userProfile?['username'] ?? 'User';
        final age = _ageFromBirthDate(state.userProfile?['birth_date']);
        final joinedAt = _formatJoinedAt(
          state.userProfile?['joined_at'] ?? state.userProfile?['created_at'],
        );
        final location = _profileText(
          state.userProfile?['location'],
          fallback: 'Belum diisi',
        );
        final avatarUrl = (state.userProfile?['avatar_url'] as String?) ?? '🐰';

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header gradient: nama, avatar, tombol settings
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Profil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Row(
                                children: [
                                  Semantics(
                                    label: 'Buka pesan',
                                    child: IconButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ChatListPage(),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.chat_bubble_outline,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Semantics(
                                    label: 'Buka pengaturan',
                                    child: IconButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SettingsPage(),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.settings_outlined,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 2,
                              ),
                              image: avatarUrl.startsWith('http')
                                  ? DecorationImage(
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: avatarUrl.startsWith('http')
                                ? null
                                : Center(
                                    child: Text(
                                      avatarUrl,
                                      style: const TextStyle(fontSize: 36),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Info ringkas: umur, tanggal bergabung, lokasi
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _infoItem(age, 'Tahun', isDark),
                        _divider(),
                        _infoItem(joinedAt, 'Bergabung', isDark),
                        _divider(),
                        _infoItem(location, 'Lokasi', isDark),
                      ],
                    ),
                  ),

                  // Statistik: jumlah produk dijual, favorit, dan postingan
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            '${myProducts.length}',
                            'Produk Dijual',
                            '🛍️',
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            '${state.products.where((p) => p.isFavorite).length}',
                            'Favorit',
                            '❤️',
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            '${myPosts.length}',
                            'Postingan',
                            '💬',
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Shortcut to order tracking, available directly from profile.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFE7F2),
                          child: Icon(
                            Icons.local_shipping_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                        title: const Text(
                          'Pesanan Saya',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('Lihat dan lacak status pesanan'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${state.myOrders.length}',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OrderListPage(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEDE7F6),
                          child: Icon(Icons.storefront_outlined,
                              color: AppTheme.primary),
                        ),
                        title: const Text('Pesanan Masuk',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle:
                            const Text('Kelola pesanan dari pembeli di tokomu'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SellerOrdersPage()),
                        ),
                      ),
                    ),
                  ),

                  // Header section "Produk Saya"
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Produk Saya',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tampilkan list produk milik user, atau pesan kosong kalau belum ada
                  if (myProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            const Text('🛍️', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 8),
                            Text(
                              'Belum ada produk dijual',
                              style: TextStyle(
                                color: subColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 230,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: myProducts.length,
                        itemBuilder: (context, index) => SizedBox(
                          width: 150,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ProductCard(
                              product: myProducts[index],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SellerProductEditPage(
                                    product: myProducts[index],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Header section "Postingan Komunitas"
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Postingan Komunitas',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tampilkan list postingan milik user, atau pesan kosong kalau belum ada
                  if (myPosts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Center(
                        child: Text(
                          'Belum ada postingan di komunitas',
                          style: TextStyle(
                            color: subColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    ...myPosts.map(
                      (post) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.blush,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        post.type,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        post.community,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey[500],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  post.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subColor,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget kecil untuk satu item info (nilai + label) di kartu info
  Widget _infoItem(String value, String label, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  // Garis pemisah vertikal antar info item
  Widget _divider() => Container(width: 1, height: 30, color: AppTheme.rose);

  // Helper: ambil teks profil, fallback kalau kosong/null
  String _profileText(dynamic value, {required String fallback}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  // Hitung umur dari tanggal lahir
  String _ageFromBirthDate(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '-';

    final now = DateTime.now();
    var age = now.year - date.year;
    final birthdayThisYear = DateTime(now.year, date.month, date.day);
    if (birthdayThisYear.isAfter(now)) age--;

    return age < 0 ? '-' : age.toString();
  }

  // Format tanggal bergabung jadi "Bulan Tahun" (mis. "Jan 2025")
  String _formatJoinedAt(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '-';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // Helper: parse tanggal dari DateTime atau String, null kalau gagal
  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  // Widget kartu statistik kecil (emoji, angka, label)
  Widget _statCard(String value, String label, String emoji, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.blush.withOpacity(isDark ? 0.3 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppTheme.primary,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
