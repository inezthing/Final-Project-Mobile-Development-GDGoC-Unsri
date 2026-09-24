import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../data/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/product_card.dart';

/// Halaman "Toko" seorang seller -- showcase semua produk yang lagi dia
/// jual. Dibuka dari dua tempat: (1) tap nama seller di Detail Produk,
/// (2) tap hasil pencarian user di Explore.
///
/// Produk diambil dari list yang SUDAH ada di AppState (bukan query baru
/// ke server) lalu difilter client-side by sellerId -- sama seperti pola
/// filter kategori/pencarian di ExplorePage, supaya konsisten dan tidak
/// nambah round-trip server yang tidak perlu.
///
/// Chat sengaja TIDAK ditaruh di sini: skema `conversations` selalu terikat
/// ke satu product_id spesifik (chat itu tentang SATU barang), jadi kalau
/// mau ngobrol sama seller ini, buka produknya dulu lewat grid di bawah,
/// tombol Chat Seller sudah ada di Detail Produk.
class SellerShopPage extends StatefulWidget {
  final String sellerId;
  // Dikirim dari halaman asal supaya header bisa langsung tampil sebelum
  // fetchUserProfile() selesai -- menghindari layar kosong sesaat.
  final String? initialSellerName;

  const SellerShopPage({
    super.key,
    required this.sellerId,
    this.initialSellerName,
  });

  @override
  State<SellerShopPage> createState() => _SellerShopPageState();
}

class _SellerShopPageState extends State<SellerShopPage> {
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await SupabaseService().fetchUserProfile(widget.sellerId);
    if (!mounted) return;
    setState(() {
      _profile = data;
      _loadingProfile = false;
    });
  }

  String get _displayName =>
      (_profile?['username'] as String?) ?? widget.initialSellerName ?? 'Seller';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);
    final isVerified = _profile?['is_verified'] == true;
    final location = _profile?['location'] as String?;
    final avatar = (_profile?['avatar_url'] as String?) ?? '\u{1F337}';

    // Ambil produk milik seller ini dari state global yang sudah dimuat,
    // hanya yang masih ada stoknya (produk habis tidak perlu ditampilkan
    // di showcase toko)
    final products = context
        .watch<AppState>()
        .products
        .where((p) => p.sellerId == widget.sellerId && p.stock > 0)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          'Toko',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ── Header profil toko ─────────────────────────────
                    Row(
                      children: [
                        _loadingProfile
                            ? const SizedBox(
                                width: 56,
                                height: 56,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : AvatarWidget(avatar: avatar, radius: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '@$_displayName',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, size: 16, color: AppTheme.primary),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                location?.isNotEmpty == true
                                    ? '📍 $location  •  ${products.length} produk'
                                    : '${products.length} produk dijual',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
                    const SizedBox(height: 4),
                    Text(
                      'Etalase',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
            if (products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Belum ada produk yang dijual toko ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[500]),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ProductCard(product: products[index]),
                    childCount: products.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
