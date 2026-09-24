import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'address_list_page.dart';

/// Halaman "Detail Pesanan" -- muncul setelah user pilih item di keranjang
/// lalu tekan Checkout (mirip Detail Pesanan-nya Shopee). Semua [items] di
/// sini WAJIB dari 1 seller yang sama (divalidasi & disaring di CartPage
/// sebelum navigasi ke sini).
///
/// Isi halaman: nama penerima (autofill dari akun, bisa diubah), alamat
/// pengiriman (tap untuk cari/pilih via picker peta + Google Geocoding),
/// opsi pengiriman Reguler/Express dengan harga yang bervariasi sesuai
/// jarak pembeli-penjual, metode pembayaran, lalu tombol "Buat Pesanan".
class OrderDetailPage extends StatefulWidget {
  final List<CartItem> items;

  const OrderDetailPage({super.key, required this.items});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late final TextEditingController _nameController;
  final _noteController = TextEditingController();

  Address? _selectedAddress;
  String? _selectedPayment;
  String _shippingCode = 'reguler';
  List<ShippingOption> _shippingOptions = [];
  double? _sellerLat;
  double? _sellerLng;
  bool _isLoadingShipping = true;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    // Autofill nama penerima dari username akun -- tetap bisa diubah user
    // (misal barang dikirim atas nama orang lain di rumah yang sama)
    _nameController = TextEditingController(
      text: (state.userProfile?['username'] ?? '').toString(),
    );
    _selectedAddress = state.addresses.isNotEmpty
        ? state.addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => state.addresses.first,
          )
        : null;
    final commonMethods = _commonPaymentMethods();
    if (commonMethods.length == 1) _selectedPayment = commonMethods.first;
    _loadShipping();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> _commonPaymentMethods() {
    if (widget.items.isEmpty) return [];
    Set<String> common = widget.items.first.product.paymentMethods.toSet();
    for (final item in widget.items.skip(1)) {
      common = common.intersection(item.product.paymentMethods.toSet());
    }
    return common.toList();
  }

  // Ambil koordinat toko penjual, lalu hitung opsi ongkir berdasarkan
  // jaraknya ke alamat pembeli yang sedang dipilih.
  Future<void> _loadShipping() async {
    setState(() => _isLoadingShipping = true);
    final sellerId = widget.items.first.product.sellerId;
    final loc = await context.read<AppState>().fetchSellerLocation(sellerId);
    _sellerLat = loc?['latitude'];
    _sellerLng = loc?['longitude'];
    _recomputeShipping();
  }

  void _recomputeShipping() {
    final options = context.read<AppState>().buildShippingOptions(
          buyerLat: _selectedAddress?.latitude,
          buyerLng: _selectedAddress?.longitude,
          sellerLat: _sellerLat,
          sellerLng: _sellerLng,
        );
    setState(() {
      _shippingOptions = options;
      _isLoadingShipping = false;
    });
  }

  Future<void> _pickAddress() async {
    final picked = await Navigator.push<Address>(
      context,
      MaterialPageRoute(builder: (_) => const AddressListPage(pickMode: true)),
    );
    if (picked != null) {
      setState(() => _selectedAddress = picked);
      _recomputeShipping();
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

  Future<void> _placeOrder() async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Nama penerima wajib diisi.');
      return;
    }
    if (_selectedAddress == null) {
      _showMessage('Pilih alamat pengiriman dulu.');
      return;
    }
    if (_selectedPayment == null) {
      _showMessage('Pilih metode pembayaran dulu.');
      return;
    }
    final shipping = _shippingOptions.firstWhere((s) => s.code == _shippingCode);

    setState(() => _isPlacingOrder = true);
    try {
      await context.read<AppState>().placeOrder(
            cartItemIds: widget.items.map((i) => i.id).toList(),
            recipientName: _nameController.text.trim(),
            recipientPhone: _selectedAddress!.phone,
            shippingAddress: _selectedAddress!.shortSummary,
            destLatitude: _selectedAddress!.latitude,
            destLongitude: _selectedAddress!.longitude,
            shippingMethod: shipping.code,
            shippingCost: shipping.price,
            paymentMethod: _selectedPayment!,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (!mounted) return;
      // Pesanan berhasil dibuat: tampilkan konfirmasi, lalu balik sampai ke
      // halaman Explore (pop 2x -- lewati Cart yang isinya sudah berkurang)
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📦', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Pesanan dibuat!',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Menunggu konfirmasi seller. Kamu bisa pantau status di '
                'Profil > Pesanan Saya.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);
    final subtotal = widget.items.fold<double>(
      0,
      (sum, item) => sum + item.product.price * item.quantity,
    );
    final selectedShipping = _shippingOptions.isEmpty
        ? null
        : _shippingOptions.firstWhere(
            (s) => s.code == _shippingCode,
            orElse: () => _shippingOptions.first,
          );
    final total = subtotal + (selectedShipping?.price ?? 0);
    final paymentOptions = _commonPaymentMethods();

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section(
                    isDark: isDark,
                    title: 'Penerima',
                    icon: Icons.person_outline,
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(fontSize: 13, color: textColor),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Nama penerima',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _section(
                    isDark: isDark,
                    title: 'Alamat Pengiriman',
                    icon: Icons.location_on_outlined,
                    onTap: _pickAddress,
                    child: _selectedAddress == null
                        ? Text(
                            'Belum ada alamat dipilih. Ketuk untuk pilih/tambah.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selectedAddress!.recipientName} · ${_selectedAddress!.phone}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _selectedAddress!.shortSummary,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                              if (!_selectedAddress!.hasCoordinates)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Alamat ini belum punya titik lokasi presisi, '
                                    'ongkir pakai estimasi standar.',
                                    style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 10),
                  _section(
                    isDark: isDark,
                    title: 'Opsi Pengiriman',
                    icon: Icons.local_shipping_outlined,
                    child: _isLoadingShipping
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Column(
                            children: _shippingOptions.map((opt) {
                              final selected = _shippingCode == opt.code;
                              return RadioListTile<String>(
                                value: opt.code,
                                groupValue: _shippingCode,
                                onChanged: (v) => setState(() => _shippingCode = v!),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppTheme.primary,
                                title: Text(
                                  opt.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Text(
                                  'Estimasi ${opt.etaLabel}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                                secondary: Text(
                                  'Rp ${_formatPrice(opt.price)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 10),
                  _section(
                    isDark: isDark,
                    title: 'Metode Pembayaran',
                    icon: Icons.payments_outlined,
                    child: paymentOptions.isEmpty
                        ? Text(
                            'Tidak ada metode pembayaran yang cocok untuk item ini.',
                            style: TextStyle(fontSize: 12, color: Colors.red[300]),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: paymentOptions.map((method) {
                              final selected = _selectedPayment == method;
                              return ChoiceChip(
                                label: Text(method),
                                selected: selected,
                                onSelected: (_) => setState(() => _selectedPayment = method),
                                selectedColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : null,
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 10),
                  _section(
                    isDark: isDark,
                    title: 'Catatan (opsional)',
                    icon: Icons.edit_note,
                    child: TextField(
                      controller: _noteController,
                      maxLines: 2,
                      style: TextStyle(fontSize: 13, color: textColor),
                      decoration: const InputDecoration(
                        hintText: 'Contoh: dibungkus rapi ya',
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _section(
                    isDark: isDark,
                    title: 'Barang (${widget.items.length})',
                    icon: Icons.shopping_bag_outlined,
                    child: Column(
                      children: widget.items
                          .map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.product.name} x${item.quantity}',
                                        style: TextStyle(fontSize: 12, color: textColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${_formatPrice(item.product.price * item.quantity)}',
                                      style: TextStyle(fontSize: 12, color: textColor),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
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
              child: Column(
                children: [
                  _summaryRow('Subtotal', 'Rp ${_formatPrice(subtotal)}', textColor),
                  const SizedBox(height: 4),
                  _summaryRow(
                    'Ongkos Kirim',
                    selectedShipping == null ? '-' : 'Rp ${_formatPrice(selectedShipping.price)}',
                    textColor,
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 16)),
                      Text(
                        'Rp ${_formatPrice(total)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPlacingOrder ? null : _placeOrder,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isPlacingOrder
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Buat Pesanan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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

  Widget _summaryRow(String label, String value, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        Text(value, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }

  Widget _section({
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);
    return Material(
      color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
                  const Spacer(),
                  if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
