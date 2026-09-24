import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'address_form_page.dart';

/// Daftar alamat tersimpan milik user.
///
/// Dipakai untuk 2 keperluan sekaligus lewat [pickMode]:
/// - `pickMode: true` (dipanggil dari checkout) -> tap alamat langsung
///   `Navigator.pop(context, address)` mengembalikan alamat yang dipilih.
/// - `pickMode: false` (dipanggil dari halaman pengaturan/profil) -> tap
///   alamat membuka form edit, ada tombol hapus di tiap kartu.
class AddressListPage extends StatelessWidget {
  final bool pickMode;

  const AddressListPage({super.key, this.pickMode = false});

  Future<void> _addNew(BuildContext context) async {
    final saved = await Navigator.push<Address>(
      context,
      MaterialPageRoute(builder: (_) => const AddressFormPage()),
    );
    if (saved != null && pickMode && context.mounted) {
      Navigator.pop(context, saved);
    }
  }

  Future<void> _edit(BuildContext context, Address address) async {
    await Navigator.push<Address>(
      context,
      MaterialPageRoute(builder: (_) => AddressFormPage(existing: address)),
    );
  }

  Future<void> _delete(BuildContext context, Address address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus alamat ini?'),
        content: Text(address.shortSummary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AppState>().deleteAddress(address.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = context.watch<AppState>().addresses;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    return Scaffold(
      appBar: AppBar(
        title: Text(pickMode ? 'Pilih Alamat' : 'Alamat Saya'),
      ),
      body: addresses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada alamat tersimpan',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return Material(
                  color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: pickMode
                        ? () => Navigator.pop(context, address)
                        : () => _edit(context, address),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.blush,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        address.label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    if (address.isDefault) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.star,
                                          size: 14, color: Colors.amber),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${address.recipientName} · ${address.phone}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  address.shortSummary,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                if (address.landmark != null &&
                                    address.landmark!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Patokan: ${address.landmark}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!pickMode)
                            IconButton(
                              onPressed: () => _delete(context, address),
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red[300], size: 20),
                            )
                          else
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNew(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Alamat'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }
}
