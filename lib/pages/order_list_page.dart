import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Halaman "Pesanan Saya" (POV pembeli) -- daftar semua order yang pernah
/// dibuat user, dengan badge status yang bisa dipantau: Menunggu Konfirmasi
/// Seller -> Sedang Dikirim -> Selesai.
class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context.read<AppState>().loadMyOrders();
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

  Future<void> _complete(Order order) async {
    try {
      await context.read<AppState>().completeOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan ditandai selesai. Terima kasih!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
    final orders = context.watch<AppState>().myOrders;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Saya')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Belum ada pesanan', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => context.read<AppState>().loadMyOrders(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = orders[index];
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
                                    'Toko: ${order.sellerName ?? 'seller'}',
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
                            if (order.status != OrderStatus.cancelled) ...[
                              const SizedBox(height: 12),
                              _StatusStepper(status: order.status, isDark: isDark),
                              const SizedBox(height: 4),
                            ],
                            const Divider(height: 16),
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
                            if (order.status == OrderStatus.shipped) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => _complete(order),
                                  child: const Text('Pesanan Selesai / Sudah Diterima'),
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

// Progress stepper 4 tahap: Pesanan Dibuat -> Disiapkan Seller -> Dalam
// Perjalanan -> Sampai Tujuan. Sengaja TIDAK ada tracking kurir real-time
// (nomor resi, lokasi live, dst) -- begitu seller kirim ke kurir, status
// akan "diam" di step "Dalam Perjalanan" sampai PEMBELI sendiri yang
// menekan tombol "Pesanan Selesai / Sudah Diterima" di bawah.
class _StatusStepper extends StatelessWidget {
  final String status;
  final bool isDark;

  const _StatusStepper({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final steps = OrderStatus.trackingSteps;
    final currentIndex = OrderStatus.stepIndex(status);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        // Index genap = lingkaran step, index ganjil = garis penghubung
        if (i.isOdd) {
          final leftStepIndex = (i - 1) ~/ 2;
          final isDone = leftStepIndex < currentIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: isDone ? AppTheme.primary : (isDark ? Colors.white12 : Colors.grey[200]),
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final stepStatus = steps[stepIndex];
        final isDone = stepIndex < currentIndex;
        final isCurrent = stepIndex == currentIndex;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDone || isCurrent) ? AppTheme.primary : (isDark ? Colors.white12 : Colors.grey[200]),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 62,
              child: Text(
                OrderStatus.trackingLabels[stepStatus] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  color: (isDone || isCurrent)
                      ? (isDark ? Colors.white : const Color(0xFF2D1B2E))
                      : Colors.grey[400],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
