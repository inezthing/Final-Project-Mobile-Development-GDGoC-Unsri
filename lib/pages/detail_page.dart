import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../data/app_state.dart';
import '../data/supabase_service.dart';
import '../theme/app_theme.dart';
import 'seller_product_edit_page.dart';
import 'seller_shop_page.dart';
import 'chat_room_page.dart';
import 'order_detail_page.dart';

class DetailPage extends StatefulWidget {
  final Product product;
  const DetailPage({super.key, required this.product});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool _isOpeningChat = false;

  // Buka (atau buat baru kalau belum ada) percakapan dengan seller, lalu
  // LANGSUNG masuk ke ChatRoomPage -- tidak ada lagi kotak chat inline di
  // halaman ini. Room chat itu dibuka default untuk nego harga, tapi
  // pembeli tetap bebas nanya hal lain juga di sana (lihat ChatRoomPage).
  Future<void> _openChat(Product product) async {
    final api = SupabaseService();
    if (api.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masuk dulu untuk chat seller.')),
      );
      return;
    }
    if (api.currentUser!.id == product.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Ini produkmu sendiri, tidak bisa chat diri sendiri.')),
      );
      return;
    }

    setState(() => _isOpeningChat = true);
    try {
      final conversationId = await api.getOrCreateConversation(
        productId: product.id,
        sellerId: product.sellerId,
      );
      if (!mounted) return;
      setState(() => _isOpeningChat = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            conversationId: conversationId,
            otherUsername: product.sellerName,
            otherAvatar: '\u{1F464}',
            productName: product.name,
            productId: product.id,
            productPrice: product.price,
            sellerId: product.sellerId,
            otherUserId: product.sellerId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOpeningChat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka chat: $e')),
      );
    }
  }

  String _formatPrice(double price) {
    final p = price.toInt();
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
    // Gunakan read untuk action, watch hanya untuk data yang berubah
    final product = widget.product;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2D1B2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Hero(
                          tag: 'product_${product.id}',
                          child: Container(
                            height: 300,
                            width: double.infinity,
                            color: Color(
                              int.parse(
                                product.imageColor.replaceFirst('#', 'FF'),
                                radix: 16,
                              ),
                            ),
                            child: product.imageUrl != null &&
                                    product.imageUrl!.isNotEmpty
                                ? Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return const Center(
                                        child: SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          product.imageEmoji,
                                          style: const TextStyle(fontSize: 100),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      product.imageEmoji,
                                      style: const TextStyle(fontSize: 100),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 16,
                          child: Semantics(
                            label: 'Kembali ke halaman sebelumnya',
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 18,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 16,
                          child: Consumer<AppState>(
                            builder: (context, state, _) {
                              final isFav = state.products
                                  .firstWhere(
                                    (p) => p.id == product.id,
                                    orElse: () => product,
                                  )
                                  .isFavorite;
                              return GestureDetector(
                                onTap: () => state.toggleFavorite(product.id),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFav
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 20,
                                    color: isFav
                                        ? AppTheme.primary
                                        : Colors.grey[400],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    Container(
                      color: bgColor,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product.brand,
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Rp ${_formatPrice(product.price)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _tag(product.category, Icons.category_outlined),
                              _tag(product.condition, Icons.star_outline),
                              _tag(
                                product.stock > 0
                                    ? 'Stok: ${product.stock}'
                                    : 'Stok habis',
                                Icons.inventory_2_outlined,
                              ),
                              _tag(
                                'Size: ${product.size}',
                                Icons.straighten_outlined,
                              ),
                              // Badge "sudah dibeli X kali" -- cuma muncul
                              // kalau minimal sudah pernah laku 1x, dihitung
                              // dari VIEW product_purchase_stats (lihat
                              // SupabaseService.fetchProducts).
                              if (product.purchaseCount > 0)
                                _tag(
                                  'Sudah dibeli ${product.purchaseCount}x',
                                  Icons.local_fire_department_outlined,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            color: isDark ? Colors.white12 : Colors.grey[200],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Deskripsi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.grey[700],
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            color: isDark ? Colors.white12 : Colors.grey[200],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Metode Pembayaran',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: product.paymentMethods
                                .map(
                                  (m) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.blush,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      m,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            color: isDark ? Colors.white12 : Colors.grey[200],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SellerShopPage(
                                      sellerId: product.sellerId,
                                      initialSellerName: product.sellerName,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.blush,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🛍️',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SellerShopPage(
                                        sellerId: product.sellerId,
                                        initialSellerName: product.sellerName,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '@${product.sellerName}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (product.sellerVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.verified,
                                              size: 14,
                                              color: AppTheme.primary,
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        'Seller · lihat toko',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color:
                                    isDark ? Colors.white38 : Colors.grey[400],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _isOpeningChat
                                ? null
                                : () => _openChat(product),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF3D2040)
                                    : AppTheme.blush,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Chat seller untuk nego harga',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _isOpeningChat
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.primary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: AppTheme.primary,
                                        ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Builder(builder: (context) {
                      final api = SupabaseService();
                      final isOwnProduct = api.currentUser != null &&
                          api.currentUser!.id == product.sellerId;

                      if (isOwnProduct) {
                        // Seller lihat produk jualannya sendiri -> tidak
                        // bisa dimasukkan ke keranjang, arahkan ke halaman
                        // edit produk (yang juga ada tombol Tambah Stok di
                        // bawahnya) -- sama kayak alur "Produk Saya" di Profil.
                        return ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SellerProductEditPage(product: product),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Ini Produkmu · Kelola'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.grey[400],
                          ),
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await context
                                      .read<AppState>()
                                      .addToCart(product);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Ditambahkan ke keranjang! 🛍️'),
                                        backgroundColor: AppTheme.primary,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e
                                            .toString()
                                            .replaceFirst('Exception: ', '')),
                                        backgroundColor: Colors.red[400],
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon:
                                  const Icon(Icons.add_shopping_cart, size: 18),
                              label: const Text('Keranjang'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final state = context.read<AppState>();
                                try {
                                  final existing = state.cart
                                      .where((i) => i.product.id == product.id)
                                      .toList();
                                  CartItem? item =
                                      existing.isEmpty ? null : existing.first;
                                  if (item == null) {
                                    await state.addToCart(product);
                                    final added = state.cart
                                        .where(
                                            (i) => i.product.id == product.id)
                                        .toList();
                                    item = added.isEmpty ? null : added.first;
                                  }
                                  if (item == null)
                                    throw Exception(
                                        'Produk gagal disiapkan untuk checkout.');
                                  if (!context.mounted) return;
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            OrderDetailPage(items: [item!])),
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(e
                                              .toString()
                                              .replaceFirst(
                                                  'Exception: ', ''))),
                                    );
                                  }
                                }
                              },
                              icon:
                                  const Icon(Icons.flash_on_outlined, size: 18),
                              label: const Text('Beli Sekarang'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.rose),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
