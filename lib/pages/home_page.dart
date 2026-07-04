import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/category_slider.dart';
import '../widgets/product_card.dart';
import 'cart_page.dart';

/// Halaman utama (tab pertama). Isinya: sapaan + tombol cart, banner promo,
/// slider kategori, dan grid produk "Top Picks". Semua data diambil dari
/// AppState lewat Consumer, jadi otomatis update kalau datanya berubah.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// Bangun grid "skeleton loading" (efek kilau abu-abu) yang ditampilkan
  /// selagi data produk masih dimuat dari server, biar user tidak lihat
  /// layar kosong/blank.
  Widget _buildShimmerGrid(int cols) {
    return GridView.builder(
      shrinkWrap: true, // grid menyesuaikan tinggi kontennya, bukan memenuhi layar
      physics: const NeverScrollableScrollPhysics(), // scroll ditangani parent (CustomScrollView)
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 0.72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: cols * 2, // tampilkan 2 baris kartu shimmer
      itemBuilder: (context, index) {
        // Shimmer.fromColors bikin efek animasi "berkilau" khas skeleton loading
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            // Bentuk kartu shimmer meniru layout ProductCard asli
            // (kotak gambar di atas, garis-garis teks placeholder di bawah)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 12, width: 80, color: Colors.white),
                        const SizedBox(height: 6),
                        Container(height: 10, width: 50, color: Colors.white),
                        const Spacer(),
                        Container(height: 14, width: 70, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);
    final subColor = isDark ? Colors.white60 : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        // Consumer<AppState>: widget ini rebuild otomatis tiap kali AppState
        // memanggil notifyListeners() (misal produk selesai dimuat, cart berubah, dst)
        child: Consumer<AppState>(
          builder: (context, state, _) {
            final username = state.userProfile?['username'] ?? 'Nadia';

            // CustomScrollView + slivers dipakai supaya bisa gabungkan
            // berbagai jenis konten (header, banner, grid) dalam satu scroll
            // yang halus, tanpa nested scroll view yang bikin error.
            return CustomScrollView(
              slivers: [
                // ==== Header: sapaan nama user + tombol keranjang ====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, $username! 🌷',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Temukan barang kesayanganmu',
                              style: TextStyle(fontSize: 13, color: subColor),
                            ),
                          ],
                        ),
                        // Ikon keranjang + badge angka jumlah item di cart
                        Semantics(
                          label: 'Keranjang belanja, ${state.cartCount} item',
                          button: true,
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CartPage(),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF3D2040)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(
                                          0.12,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                // Badge merah muda kecil, cuma muncul kalau ada isi di cart
                                if (state.cartCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${state.cartCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ==== Banner promo auto-scroll ====
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: BannerCarousel(),
                  ),
                ),
                // ==== Judul "Kategori" + slider kategori horizontal ====
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Text(
                          'Kategori',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                      const CategorySlider(),
                    ],
                  ),
                ),
                // ==== Judul "Top Picks" + tombol "Lihat semua" ====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Garis kecil vertikal sebagai aksen di samping judul
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Top Picks ✨',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Lihat semua',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ==== Grid produk Top Picks (responsif jumlah kolom) ====
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Tentukan jumlah kolom grid berdasarkan lebar layar
                        // (2 kolom di HP, 3 di tablet, 4 di layar besar)
                        final screenWidth = MediaQuery.of(context).size.width;
                        final cols = screenWidth >= 1000
                            ? 4
                            : screenWidth >= 600
                            ? 3
                            : 2;

                        // Selagi data masih loading, tampilkan shimmer placeholder
                        if (state.isLoading) {
                          return _buildShimmerGrid(cols);
                        }

                        final products = state.topPicksProducts;
                        // Kalau belum ada produk yang di-favorite siapapun, tampilkan pesan kosong
                        if (products.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'Belum ada produk yang di-favoritkan 🛍️',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        }

                        // Tampilkan grid kartu produk yang sesungguhnya
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: products.length,
                          itemBuilder: (context, index) =>
                              ProductCard(product: products[index]),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            );
          },
        ),
      ),
    );
  }
}