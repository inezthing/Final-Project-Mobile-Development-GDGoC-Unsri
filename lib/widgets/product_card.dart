import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../pages/detail_page.dart';

// Kartu produk untuk ditampilkan di grid/list (home, explore, dll)
class ProductCard extends StatelessWidget {
  final Product product;
  // Override opsional: kalau diisi, tap kartu manggil ini alih-alih buka
  // DetailPage seperti biasa -- dipakai di Profil > Produk Saya buat buka
  // dialog tambah stok cepat.
  final VoidCallback? onTap;
  const ProductCard({super.key, required this.product, this.onTap});

  // Format harga jadi lebih ringkas, contoh: 1500000 -> "1.5jt", 25000 -> "25.000"
  String _formatPrice(double price) {
    final p = price.toInt();
    if (p >= 1000000) {
      return '${(p / 1000000).toStringAsFixed(1)}jt';
    }
    final str = p.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write('.');
      result.write(str[i]);
    }
    return result.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tap kartu -> buka halaman detail produk (atau jalankan onTap custom
    // kalau ada, misal dialog tambah stok di Profil > Produk Saya)
    return GestureDetector(
      onTap: onTap ??
          () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailPage(product: product)),
              ),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  // Gambar produk (atau emoji + warna sebagai fallback)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color(
                        int.parse(
                          product.imageColor.replaceFirst('#', 'FF'),
                          radix: 16,
                        ),
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child:
                          product.imageUrl != null &&
                              product.imageUrl!.isNotEmpty
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    product.imageEmoji,
                                    style: const TextStyle(fontSize: 52),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                product.imageEmoji,
                                style: const TextStyle(fontSize: 52),
                              ),
                            ),
                    ),
                  ),
                  // Favorite — pakai Consumer biar hanya bagian ini yang rebuild
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Consumer<AppState>(
                      builder: (context, state, _) {
                        final isFav = state.products
                            .firstWhere(
                              (p) => p.id == product.id,
                              orElse: () => product,
                            )
                            .isFavorite;
                        return Semantics(
                          label: isFav
                              ? 'Hapus dari favorit'
                              : 'Tambahkan ke favorit',
                          child: GestureDetector(
                            onTap: () => state.toggleFavorite(product.id),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: isFav
                                    ? AppTheme.primary
                                    : Colors.grey[400],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Badge "Verified" untuk seller yang sudah terverifikasi
                  if (product.sellerVerified)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info produk: nama, brand, harga, kondisi
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF2D1B2E),
                        height: 1.1,
                      ),
                    ),
                    Text(
                      product.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? Colors.white54 : Colors.grey[500],
                      ),
                    ),
                    Text(
                      'Rp ${_formatPrice(product.price)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      product.condition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.white38 : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
