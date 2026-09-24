import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../data/supabase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/add_stock_dialog.dart';

/// Halaman "Produk Saya > detail" dari sudut pandang SELLER: nampilin
/// harga/deskripsi/dll produk sendiri dalam bentuk form yang BISA diedit
/// langsung, dan di paling bawah ada tombol "Tambah Stok" terpisah (stok
/// tetap lewat alur `showAddStockDialog` yang sudah ada -- supaya
/// penambahan stok selalu nambah, bukan bisa ketimpa nilai asal-asalan
/// dari form edit ini).
class SellerProductEditPage extends StatefulWidget {
  final Product product;
  const SellerProductEditPage({super.key, required this.product});

  @override
  State<SellerProductEditPage> createState() => _SellerProductEditPageState();
}

class _SellerProductEditPageState extends State<SellerProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _sizeCtrl;
  late String _category;
  late String _condition;
  late Set<String> _selectedPayments;
  bool _isSaving = false;

  static const _categories = [
    'Woman Fashion',
    'Man Fashion',
    'Health & Beauty',
    'Keychain',
    'Trinket',
    'Shoes',
    'Playing Card',
    'Sticker',
  ];

  static const _conditions = [
    'Brand New - Sealed',
    'Brand New',
    'Preloved - Like New',
    'Preloved - Good',
    'Used - Good',
  ];

  static const _paymentOptions = [
    'Transfer Bank',
    'GoPay',
    'OVO',
    'DANA',
    'ShopeePay',
    'COD',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p.name);
    _brandCtrl = TextEditingController(text: p.brand);
    _descCtrl = TextEditingController(text: p.description);
    _priceCtrl = TextEditingController(text: p.price.toInt().toString());
    _sizeCtrl = TextEditingController(text: p.size);
    _category = _categories.contains(p.category) ? p.category : _categories.first;
    _condition = _conditions.contains(p.condition) ? p.condition : _conditions.first;
    _selectedPayments = p.paymentMethods.toSet();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPayments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 metode pembayaran.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final updated = await SupabaseService().updateProduct(
        productId: widget.product.id,
        name: _nameCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        price: double.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? widget.product.price,
        condition: _condition,
        size: _sizeCtrl.text.trim(),
        paymentMethods: _selectedPayments.toList(),
      );
      if (!mounted) return;
      context.read<AppState>().upsertProduct(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Perubahan produk tersimpan! ✨'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus produk ini?'),
        content: const Text(
          'Produk akan dihapus permanen dan tidak akan muncul lagi di toko kamu. Aksi ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await context.read<AppState>().deleteProduct(widget.product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk berhasil dihapus.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // Ambil versi terbaru dari state (misal stok baru saja ditambah)
        // supaya angka stok yang ditampilkan selalu up to date.
        final live = state.products.firstWhere(
          (p) => p.id == widget.product.id,
          orElse: () => widget.product,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Produk Saya')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama produk'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandCtrl,
                  decoration: const InputDecoration(labelText: 'Brand'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga (Rp)',
                    prefixText: 'Rp ',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), ''));
                    if (n == null || n <= 0) return 'Harga tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _condition,
                  decoration: const InputDecoration(labelText: 'Kondisi'),
                  items: _conditions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _condition = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sizeCtrl,
                  decoration: const InputDecoration(labelText: 'Ukuran / Size'),
                ),
                const SizedBox(height: 16),
                const Text('Metode Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _paymentOptions.map((m) {
                    final selected = _selectedPayments.contains(m);
                    return FilterChip(
                      label: Text(m),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedPayments.add(m);
                        } else {
                          _selectedPayments.remove(m);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Simpan Perubahan'),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Stok saat ini: ${live.stock}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tombol tambah stok TERPISAH & di bawah form edit (sesuai
                // permintaan) -- tetap pakai dialog & alur addProductStock
                // yang sudah ada supaya logic-nya tidak dobel/berantakan.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showAddStockDialog(context, live),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Tambah Stok'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Delete produk -- terpisah & warna merah supaya jelas ini
                // aksi destruktif, beda visual dari tombol simpan/tambah stok
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _confirmDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Hapus Produk', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
