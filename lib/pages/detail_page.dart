import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';

class DetailPage extends StatefulWidget {
  final Product product;
  const DetailPage({super.key, required this.product});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool _chatVisible = false;
  final TextEditingController _chatController = TextEditingController();

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
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
                            child:
                                product.imageUrl != null &&
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
                                'Size: ${product.size}',
                                Icons.straighten_outlined,
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
                              Container(
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      'Seller',
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
                            ],
                          ),

                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _chatVisible = !_chatVisible),
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
                                  const Text(
                                    'Chat seller untuk nego harga',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    _chatVisible
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: AppTheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_chatVisible) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _chatController,
                                    decoration: InputDecoration(
                                      hintText: 'Tulis penawaran...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[400],
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                    ),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    if (_chatController.text.isNotEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Pesan terkirim ke @${product.sellerName}!',
                                          ),
                                          backgroundColor: AppTheme.primary,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      );
                                      _chatController.clear();
                                      setState(() => _chatVisible = false);
                                    }
                                  },
                                  child: const Text('Kirim'),
                                ),
                              ],
                            ),
                          ],

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
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await context.read<AppState>().addToCart(product);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Ditambahkan ke keranjang! 🛍️'),
                                backgroundColor: AppTheme.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal menambahkan ke keranjang: $e'),
                                backgroundColor: Colors.red[400],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Masukkan Keranjang'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
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
