import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../data/supabase_service.dart';
import '../models/models.dart';

// Halaman form untuk membuat listing produk baru
class SellPage extends StatefulWidget {
  const SellPage({super.key});

  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _sizeController = TextEditingController();
  final _stockController = TextEditingController(text: '1');

  String _selectedCategory = 'Woman Fashion';
  String _selectedCondition = 'Preloved - Like New';
  final List<String> _selectedPayments = [];
  bool _hasUnsavedChanges = false;
  bool _isLoading = false;

  File? _imageFile;
  final _picker = ImagePicker();

  // Ambil foto dari sumber (kamera/galeri) yang dipilih
  Future<void> _pickImageFrom(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _markChanged();
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  // Tampilkan pilihan sumber foto (kamera/galeri) via bottom sheet
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;
    await _pickImageFrom(source);
  }

  // Daftar pilihan kategori produk
  static const List<String> _categories = [
    'Woman Fashion',
    'Man Fashion',
    'Health & Beauty',
    'Keychain',
    'Trinket',
    'Shoes',
    'Playing Card',
    'Sticker',
  ];

  // Daftar pilihan kondisi produk
  static const List<String> _conditions = [
    'Brand New - Sealed',
    'Brand New',
    'Preloved - Like New',
    'Preloved - Good',
    'Used - Good',
  ];

  // Daftar pilihan metode pembayaran
  static const List<String> _paymentOptions = [
    'Transfer Bank',
    'GoPay',
    'OVO',
    'DANA',
    'ShopeePay',
    'COD',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _sizeController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  // Tandai form ada perubahan yang belum disimpan (buat konfirmasi keluar)
  void _markChanged() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  // Ambil angka murni dari input harga (buang selain digit)
  double? _parsePrice(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;
    return double.tryParse(digitsOnly);
  }

  // Konfirmasi dialog saat user coba keluar padahal ada perubahan belum disimpan
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Batalkan listing?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Data yang sudah kamu isi akan hilang. Yakin mau keluar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Lanjutkan isi',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[400]),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Validasi form, upload gambar (kalau ada), lalu kirim produk baru ke server
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPayments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pilih minimal satu metode pembayaran'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final addedStock = int.tryParse(_stockController.text.trim()) ?? 1;

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final name = _nameController.text.trim();
      final brand = _brandController.text.trim();

      // Cek dulu: seller ini sudah pernah listing barang yang PERSIS sama
      // (nama + brand + kategori) belum? Kalau sudah, jangan bikin listing
      // duplikat -- cukup tambah stoknya saja di listing yang sudah ada.
      final existing = await SupabaseService().findExistingProduct(
        name: name,
        brand: brand,
        category: _selectedCategory,
      );

      Product product;
      var isRestock = false;

      if (existing != null) {
        isRestock = true;
        product = await SupabaseService().restockProduct(
          productId: existing['id'] as String,
          addedStock: addedStock,
        );
        if (!mounted) return;
        context.read<AppState>().upsertProduct(product);
      } else {
        // Upload foto dulu (kalau user pilih foto), baru buat produknya
        String? imageUrl;
        if (_imageFile != null) {
          imageUrl = await SupabaseService().uploadProductImage(_imageFile!);
        }

        product = await SupabaseService().createProduct(
          name: name,
          brand: brand,
          description: _descController.text.trim(),
          category: _selectedCategory,
          price: _parsePrice(_priceController.text.trim())!,
          condition: _selectedCondition,
          size: _sizeController.text.trim().isEmpty
              ? 'One Size'
              : _sizeController.text.trim(),
          imageUrl: imageUrl,
          paymentMethods: List.from(_selectedPayments),
          stock: addedStock,
        );
        if (!mounted) return;
        context.read<AppState>().addProduct(product);
      }

      if (!mounted) return;
      setState(() => _hasUnsavedChanges = false);

      // Tampilkan dialog sukses setelah produk berhasil dilisting/direstock
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: isRestock
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📦', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text(
                      'Stok berhasil ditambah!',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$name sekarang punya stok ${product.stock}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                )
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Produk berhasil dilisting!',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${_nameController.text} sudah aktif dan bisa ditemukan pembeli.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('Lihat di Explore'),
            ),
          ],
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal melisting produk: ${e.toString()}'),
          backgroundColor: Colors.red[400],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    // PopScope: cegah keluar tanpa konfirmasi kalau ada perubahan belum disimpan
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _hasUnsavedChanges) {
          final should = await _onWillPop();
          if (!context.mounted) return;
          if (should) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jual Barang 🏷️'),
          // Tombol close juga cek perubahan belum disimpan sebelum keluar
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (_hasUnsavedChanges) {
                final should = await _onWillPop();
                if (!context.mounted) return;
                if (should) Navigator.of(context).pop();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        // LayoutBuilder untuk menyesuaikan padding di layar lebar (rubrik C)
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              return SingleChildScrollView(
                padding: EdgeInsets.all(isWide ? 32 : 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Foto placeholder: tap untuk pilih foto produk ──
                          Semantics(
                            label: 'Tombol tambah foto produk',
                            button: true,
                            child: GestureDetector(
                              onTap: _isLoading ? null : _pickImage,
                              child: Container(
                                height: 160,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2D1B2E)
                                      : AppTheme.blush,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.rose,
                                    width: 2,
                                  ),
                                  image: _imageFile != null
                                      ? DecorationImage(
                                          image: FileImage(_imageFile!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _imageFile == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            '📷',
                                            style: TextStyle(fontSize: 36),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Tambah Foto',
                                            style: TextStyle(
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Tap untuk pilih dari galeri',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.grey[400],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Align(
                                        alignment: Alignment.topRight,
                                        child: Container(
                                          margin: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            onPressed: () => setState(
                                              () => _imageFile = null,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          // ── Section: Informasi Produk ──
                          _sectionLabel('Informasi Produk', textColor),
                          const SizedBox(height: 12),

                          _buildField(
                            context: context,
                            controller: _nameController,
                            label: 'Nama Produk',
                            hint: 'Contoh: Hirono Macaron Keychain',
                            onChanged: (_) => _markChanged(),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Nama produk wajib diisi';
                              }
                              if (v.trim().length < 3) {
                                return 'Minimal 3 karakter';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),
                          _buildField(
                            context: context,
                            controller: _brandController,
                            label: 'Merek / Brand',
                            hint: 'Contoh: Pop Mart, Uniqlo',
                            onChanged: (_) => _markChanged(),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Merek wajib diisi';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),
                          // Row untuk Kategori + Kondisi (pakai Row+Expanded rubrik B)
                          isWide
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: _dropdownField(
                                        context: context,
                                        label: 'Kategori',
                                        value: _selectedCategory,
                                        items: _categories,
                                        onChanged: (v) => setState(() {
                                          _selectedCategory = v!;
                                          _markChanged();
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _dropdownField(
                                        context: context,
                                        label: 'Kondisi',
                                        value: _selectedCondition,
                                        items: _conditions,
                                        onChanged: (v) => setState(() {
                                          _selectedCondition = v!;
                                          _markChanged();
                                        }),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _dropdownField(
                                      context: context,
                                      label: 'Kategori',
                                      value: _selectedCategory,
                                      items: _categories,
                                      onChanged: (v) => setState(() {
                                        _selectedCategory = v!;
                                        _markChanged();
                                      }),
                                    ),
                                    const SizedBox(height: 12),
                                    _dropdownField(
                                      context: context,
                                      label: 'Kondisi',
                                      value: _selectedCondition,
                                      items: _conditions,
                                      onChanged: (v) => setState(() {
                                        _selectedCondition = v!;
                                        _markChanged();
                                      }),
                                    ),
                                  ],
                                ),

                          const SizedBox(height: 12),
                          _buildField(
                            context: context,
                            controller: _sizeController,
                            label: 'Ukuran (opsional)',
                            hint: 'Contoh: M, 37, One Size',
                            onChanged: (_) => _markChanged(),
                          ),

                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descController,
                            maxLines: 4,
                            onChanged: (_) => _markChanged(),
                            style: TextStyle(color: textColor, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Deskripsi',
                              hintText:
                                  'Ceritakan kondisi, alasan jual, kelengkapan...',
                              hintStyle: TextStyle(
                                color:
                                    isDark ? Colors.white38 : Colors.grey[400],
                                fontSize: 12,
                              ),
                              alignLabelWithHint: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Deskripsi wajib diisi';
                              }
                              if (v.trim().length < 10) {
                                return 'Minimal 10 karakter';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),
                          // ── Section: Harga & Pembayaran ──
                          _sectionLabel('Harga & Pembayaran', textColor),
                          const SizedBox(height: 12),

                          _buildField(
                            context: context,
                            controller: _priceController,
                            label: 'Harga (Rp)',
                            hint: 'Contoh: 85000',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _markChanged(),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Harga wajib diisi';
                              }
                              final parsed = _parsePrice(v.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Masukkan harga yang valid';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),
                          _buildField(
                            context: context,
                            controller: _stockController,
                            label: 'Stok (jumlah barang)',
                            hint: 'Contoh: 3',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _markChanged(),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Stok wajib diisi';
                              }
                              final parsed = int.tryParse(v.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Masukkan jumlah stok yang valid';
                              }
                              return null;
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Kalau kamu sudah pernah listing barang yang sama '
                              '(nama, brand & kategori sama persis), stok ini '
                              'otomatis ditambahkan ke listing lama -- bukan '
                              'bikin listing baru.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.grey[400],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Text(
                            'Metode Pembayaran',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Chip pilihan metode pembayaran (bisa pilih lebih dari satu)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _paymentOptions.map((option) {
                              final isSelected = _selectedPayments.contains(
                                option,
                              );
                              return Semantics(
                                label:
                                    '$option, ${isSelected ? 'dipilih' : 'belum dipilih'}',
                                button: true,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedPayments.remove(option);
                                      } else {
                                        _selectedPayments.add(option);
                                      }
                                      _markChanged();
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primary
                                          : (isDark
                                              ? const Color(0xFF3D2040)
                                              : AppTheme.blush),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.primaryDark,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 32),
                          // Tombol submit form: nonaktif & tampil loading saat proses upload
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _submit,
                              icon: _isLoading
                                  ? null
                                  : const Icon(Icons.sell_outlined, size: 18),
                              label: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Listing Sekarang!'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Label section dengan garis aksen kecil di kiri
  Widget _sectionLabel(String label, Color textColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // Widget reusable untuk text field form (label, hint, validator)
  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF2D1B2E),
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.grey[400],
          fontSize: 12,
        ),
      ),
      validator: validator,
    );
  }

  // Widget reusable untuk dropdown pilihan (kategori/kondisi)
  Widget _dropdownField({
    required BuildContext context,
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF2D1B2E),
        fontSize: 13,
        fontFamily: 'Nunito',
      ),
      dropdownColor: isDark ? const Color(0xFF2D1B2E) : Colors.white,
      isExpanded: true,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
