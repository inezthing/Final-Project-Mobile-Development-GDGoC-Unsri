import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';

/// Dialog cepat buat nambah stok produk milik sendiri -- dipanggil dari tap
/// kartu produk di Profil > "Produk Saya", atau dari tombol "Kelola Stok"
/// di Detail Produk saat seller melihat produknya sendiri. Tidak perlu buka
/// form "Jual Barang" penuh cuma buat nambah stok.
void showAddStockDialog(BuildContext context, Product product) {
  final controller = TextEditingController(text: '1');
  final state = context.read<AppState>();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Tambah Stok "${product.name}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stok saat ini: ${product.stock}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Jumlah stok ditambah',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            final amount = int.tryParse(controller.text.trim()) ?? 0;
            if (amount <= 0) return;
            Navigator.pop(ctx);
            try {
              await state.addProductStock(product.id, amount);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Stok "${product.name}" ditambah $amount.')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menambah stok: $e')),
                );
              }
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}
