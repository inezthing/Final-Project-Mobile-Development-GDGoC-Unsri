import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Halaman "Pesanan Masuk" (POV penjual) -- daftar order yang masuk ke
/// toko user, lengkap dengan nama & alamat pembeli, lalu 1 tombol aksi:
/// "Kirim Barang" (mengubah status order jadi 'dikirim').
class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  bool _isLoading = true;
  String? _actingOnId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context.read<AppState>().loadSellerOrders();
    if (mounted) setState(() => _isLoading = false);
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

  Future<void> _process(Order order) async {
    setState(() => _actingOnId = order.id);
    try {
      await context.read<AppState>().processOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan diproses. Siapkan barangnya ya!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  Future<void> _ship(Order order) async {
    setState(() => _actingOnId = order.id);
    try {
      await context.read<AppState>().shipOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan ditandai sudah dikirim.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _actingOnId = null);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case OrderStatus.processing:
        return Colors.purple;
      case OrderStatus.shipped:
        return Colors.blue;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<AppState>().sellerOrders;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Masuk')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Belum ada pesanan masuk', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => context.read<AppState>().loadSellerOrders(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final isActingOnThis = _actingOnId == order.id;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Dari: ${order.buyerName ?? 'pembeli'}',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textColor),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(order.status).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    OrderStatus.label(order.status),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _statusColor(order.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...order.items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '${item.productName} x${item.quantity}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Detail alamat pembeli -- baru terlihat oleh
                            // seller setelah ada order masuk (privasi alamat
                            // pembeli terjaga sebelum transaksi terjadi)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.blush.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${order.recipientName} · ${order.recipientPhone}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.shippingAddress,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${order.shippingMethod == 'express' ? 'Express' : 'Reguler'} · ${order.paymentMethod}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                                Text(
                                  'Rp ${_formatPrice(order.totalPrice)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primary),
                                ),
                              ],
                            ),
                            if (order.status == OrderStatus.waitingSeller) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isActingOnThis ? null : () => _process(order),
                                  icon: isActingOnThis
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.inventory_2_outlined, size: 18),
                                  label: const Text('Proses Pesanan'),
                                ),
                              ),
                            ] else if (order.status == OrderStatus.processing) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isActingOnThis ? null : () => _ship(order),
                                  icon: isActingOnThis
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.local_shipping_outlined, size: 18),
                                  label: const Text('Sudah Dikirim ke Kurir'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
