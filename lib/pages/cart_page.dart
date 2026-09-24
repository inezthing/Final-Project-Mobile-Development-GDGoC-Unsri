import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'order_detail_page.dart';

/// Halaman keranjang belanja (mirip alur Shopee terbaru): daftar item
/// dengan CHECKBOX buat milih item mana yang mau di-checkout (tidak harus
/// semua sekaligus), kontrol quantity, lalu tombol "Checkout" membawa item
/// TERPILIH ke halaman Detail Pesanan (alamat, ongkir, pembayaran, dst).
///
/// Kenapa checkout-nya dipindah ke halaman terpisah (bukan di sini kayak
/// sebelumnya): supaya alurnya konsisten dengan marketplace beneran --
/// Cart cuma buat milih barang, detail pesanan (alamat/ongkir/pembayaran)
/// punya halaman sendiri yang lebih leluasa.
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selectedIds = {};

  /// Format harga jadi punya titik pemisah ribuan (misal 150000 -> "150.000").
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

  void _toggleSelect(CartItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        _selectedIds.add(item.id);
      }
    });
  }

  void _toggleSelectAll(List<CartItem> cart) {
    setState(() {
      if (_selectedIds.length == cart.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(cart.map((i) => i.id));
      }
    });
  }

  Future<void> _goToCheckout(List<CartItem> selected) async {
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 barang dulu.')),
      );
      return;
    }
    // Checkout HARUS 1 toko per transaksi (sama seperti Shopee) -- kalau
    // item yang dicentang campur dari beberapa seller, tolak di sini
    // sebelum ke halaman detail, bukan pas submit ke server.
    final sellerIds = selected.map((i) => i.product.sellerId).toSet();
    if (sellerIds.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Barang yang dipilih dari toko berbeda. Checkout terpisah per toko ya.',
          ),
        ),
      );
      return;
    }
    final overStock = selected.where((i) => i.quantity > i.product.stock).toList();
    if (overStock.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stok ${overStock.first.product.name} tinggal '
            '${overStock.first.product.stock}. Kurangi jumlahnya dulu.',
          ),
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailPage(items: selected)),
    );
    // Kalau pesanan berhasil dibuat, item yang di-checkout otomatis hilang
    // dari cart (AppState.placeOrder sudah handle) -- bersihkan seleksi lokal
    if (result == true && mounted) {
      setState(() => _selectedIds.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);
    final cart = state.cart;
    // Buang seleksi yang item-nya sudah tidak ada lagi di cart (misal
    // dihapus di device lain)
    _selectedIds.retainWhere((id) => cart.any((i) => i.id == id));
    final selectedItems = cart.where((i) => _selectedIds.contains(i.id)).toList();
    final subtotal = selectedItems.fold<double>(
      0,
      (sum, item) => sum + item.effectivePrice * item.quantity,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang 🛍️'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: cart.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🛒', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      'Keranjang masih kosong',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Yuk temukan barang impianmu!',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[500]),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Explore Produk'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selectedIds.length == cart.length,
                          onChanged: (_) => _toggleSelectAll(cart),
                          activeColor: AppTheme.primary,
                        ),
                        Text('Pilih Semua', style: TextStyle(fontSize: 13, color: textColor)),
                        const Spacer(),
                        Text(
                          '${_selectedIds.length} dipilih',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: cart
                          .map((item) => _CartItemCard(
                                item: item,
                                isDark: isDark,
                                textColor: textColor,
                                formatPrice: _formatPrice,
                                selected: _selectedIds.contains(item.id),
                                onToggleSelect: () => _toggleSelect(item),
                              ))
                          .toList(),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Subtotal', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              Text(
                                'Rp ${_formatPrice(subtotal)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primary),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _goToCheckout(selectedItems),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
                          ),
                          child: Text(
                            'Checkout (${_selectedIds.length})',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
}

// Kartu 1 item cart (checkbox, thumbnail, nama, harga, kontrol quantity, hapus)
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final bool isDark;
  final Color textColor;
  final String Function(double) formatPrice;
  final bool selected;
  final VoidCallback onToggleSelect;

  const _CartItemCard({
    required this.item,
    required this.isDark,
    required this.textColor,
    required this.formatPrice,
    required this.selected,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final overStock = item.quantity > item.product.stock;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (_) => onToggleSelect(),
                  activeColor: AppTheme.primary,
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(int.parse(item.product.imageColor.replaceFirst('#', 'FF'), radix: 16)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
                        ? Image.network(
                            item.product.imageUrl!,
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(child: Text(item.product.imageEmoji, style: const TextStyle(fontSize: 28))),
                          )
                        : Center(child: Text(item.product.imageEmoji, style: const TextStyle(fontSize: 28))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Rp ${formatPrice(item.effectivePrice)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
                          ),
                          if (item.isNegotiated) ...[
                            const SizedBox(width: 6),
                            Text(
                              'Rp ${formatPrice(item.product.price)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Harga Nego',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.green),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => state.decrementCartItem(item),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.remove, size: 10, color: textColor),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('${item.quantity}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor)),
                          ),
                          GestureDetector(
                            onTap: () => state.incrementCartItem(item),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.add, size: 10, color: textColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stok: ${item.product.stock}',
                            style: TextStyle(fontSize: 10, color: overStock ? Colors.red[300] : Colors.grey[400]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => state.removeFromCart(item.id),
                  icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 20),
                ),
              ],
            ),
            if (overStock)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Stok tidak cukup, kurangi jumlahnya',
                      style: TextStyle(fontSize: 11, color: Colors.red[300])),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
