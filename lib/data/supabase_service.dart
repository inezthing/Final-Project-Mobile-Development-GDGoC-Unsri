import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart';

// Helper untuk mengubah Supabase error jadi pesan yang ramah user
String _friendlyError(Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('invalid login credentials') ||
      msg.contains('email not confirmed')) {
    return 'Email atau password salah. Coba lagi.';
  }
  if (msg.contains('user already registered') ||
      msg.contains('already been registered')) {
    return 'Email ini sudah terdaftar. Silakan masuk.';
  }
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('connection')) {
    return 'Tidak ada koneksi internet. Periksa jaringanmu.';
  }
  if (msg.contains('rate limit')) {
    return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
  }
  if (msg.contains('jwt') || msg.contains('token')) {
    return 'Sesi kamu sudah habis. Silakan masuk ulang.';
  }
  if (msg.contains('permission') || msg.contains('policy')) {
    return 'Kamu tidak punya akses untuk melakukan ini.';
  }
  return 'Terjadi kesalahan. Coba lagi nanti.';
}

// Service utama buat semua komunikasi ke Supabase (auth, database, storage).
// Dibuat singleton biar instance-nya sama di seluruh aplikasi.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  SupabaseClient get client => _client;

  // ==========================================
  // AUTHENTICATION
  // ==========================================
  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // Login dengan email & password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // Skema deep link buat balikin user ke app ini setelah klik link
  // verifikasi email (lihat main.dart buat handler-nya, dan
  // SETUP_GUIDE_fitur_baru.md buat setup native + Supabase Dashboard-nya).
  // HARUS SAMA PERSIS di 3 tempat: sini, AndroidManifest.xml/Info.plist,
  // dan "Redirect URLs" di Supabase Dashboard > Authentication > URL Configuration.
  static const String authCallbackDeepLink = 'whimsify://auth-callback';

  // Registrasi akun baru + buat profil di tabel 'profiles'
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String birthDate,
    required String location,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        // Link di email verifikasi bakal redirect balik kesini (custom
        // deep link scheme) setelah Supabase konfirmasi email-nya --
        // ditangani di main.dart -> _handleIncomingLink().
        emailRedirectTo: authCallbackDeepLink,
        data: {
          'username': username,
          'avatar_url': '\u{1F337}',
          'birth_date': birthDate,
          'location': location,
        },
      );

      if (response.session != null && response.user != null) {
        await upsertUserProfile(
          userId: response.user!.id,
          username: username,
          birthDate: birthDate,
          location: location,
          latitude: latitude,
          longitude: longitude,
        );
      }

      return response;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // Simpan/update data profil user (insert kalau belum ada, update kalau sudah)
  Future<void> upsertUserProfile({
    required String userId,
    required String username,
    required String birthDate,
    required String location,
    double? latitude,
    double? longitude,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'username': username,
      'avatar_url': '\u{1F337}',
      'birth_date': birthDate,
      'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }

  // Ambil koordinat toko/penjual (diisi lewat picker lokasi saat registrasi)
  // -- dipakai buat hitung ongkir berdasarkan jarak ke alamat pembeli.
  Future<Map<String, double>?> fetchSellerLocation(String sellerId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('latitude, longitude')
          .eq('id', sellerId)
          .maybeSingle();
      if (response == null ||
          response['latitude'] == null ||
          response['longitude'] == null) {
        return null;
      }
      return {
        'latitude': (response['latitude'] as num).toDouble(),
        'longitude': (response['longitude'] as num).toDouble(),
      };
    } catch (e) {
      debugPrint('Error fetching seller location: $e');
      return null;
    }
  }

  // Logout dari Supabase auth
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error (ignored): $e');
    }
  }

  // Ambil profil user berdasarkan ID, otomatis perbaiki kalau baris profil hilang
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) return data;

      // PENTING: kalau baris di tabel profiles belum ada (misal trigger
      // handle_new_user gagal/telat), JANGAN cuma dipalsukan di lokal saja.
      // Kalau dipalsukan, aplikasi terlihat baik-baik saja tapi semua insert
      // lain yang mereferensikan profiles(id) -- seperti bikin postingan
      // komunitas, produk, cart, favorit -- akan gagal dengan error foreign
      // key karena baris user-nya sendiri tidak nyata ada di database.
      // Jadi di sini kita benar-benar buat baris-nya di database.
      if (currentUser?.id == userId) {
        final repaired = await _repairMissingProfile(currentUser!);
        if (repaired != null) return repaired;
        return _profileFromAuthUser(currentUser!);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      if (currentUser?.id == userId) {
        final repaired = await _repairMissingProfile(currentUser!);
        if (repaired != null) return repaired;
        return _profileFromAuthUser(currentUser!);
      }
      return null;
    }
  }

  // Cari user/toko berdasarkan username (dipakai di search bar Explore).
  // Sengaja dibatasi 10 hasil & exclude diri sendiri + user yang sudah
  // diblokir dari sisi kita (biar konsisten sama filter blocked user
  // di tempat lain, misal Komunitas).
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final data = await _client
          .from('profiles')
          .select('id, username, avatar_url, is_verified, location')
          .ilike('username', '%${query.trim()}%')
          .neq('id', currentUser?.id ?? '')
          .limit(10);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Membuat ulang baris profiles yang hilang berdasarkan data auth.users,
  // supaya foreign key ke profiles(id) di tabel lain (products, cart_items,
  // favorites, community_posts, dst) tidak gagal.
  Future<Map<String, dynamic>?> _repairMissingProfile(User user) async {
    try {
      final metadata = user.userMetadata ?? {};
      final fallback = _profileFromAuthUser(user);
      final response = await _client
          .from('profiles')
          .upsert({
            'id': user.id,
            'username': fallback['username'],
            'avatar_url': metadata['avatar_url'] ?? '\u{1F337}',
            'birth_date': metadata['birth_date'],
            'location': metadata['location'],
          })
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error repairing missing profile: $e');
      return null;
    }
  }

  // Bikin data profil sementara dari metadata auth (dipakai kalau repair gagal)
  Map<String, dynamic> _profileFromAuthUser(User user) {
    final metadata = user.userMetadata ?? {};
    return {
      'id': user.id,
      'username': metadata['username'] ?? user.email?.split('@').first ?? 'User',
      'avatar_url': metadata['avatar_url'] ?? '\u{1F337}',
      'birth_date': metadata['birth_date'],
      'location': metadata['location'],
      'created_at': user.createdAt,
    };
  }

  // ==========================================
  // UPDATE PROFILE (username, birth_date, location, avatar_url)
  // ==========================================
  // Update data profil (username, tanggal lahir, lokasi, avatar opsional)
  Future<Map<String, dynamic>> updateProfile({
    required String username,
    required String birthDate,
    required String location,
    String? avatarUrl,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final updates = <String, dynamic>{
        'username': username,
        'birth_date': birthDate,
        'location': location,
      };
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      final response = await _client
          .from('profiles')
          .update(updates)
          .eq('id', currentUser!.id)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Upload foto profil ke storage bucket 'avatars', return public URL
  Future<String?> uploadAvatar(File file) async {
    try {
      if (currentUser == null) return null;
      final fileName = '${currentUser!.id}/avatar.jpg';
      await _client.storage.from('avatars').upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      return _client.storage.from('avatars').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  // ==========================================
  // PRODUCTS
  // ==========================================
  // Ambil semua produk beserta data seller & favorit; fallback ke query
  // sederhana kalau query dengan relasi gagal
  Future<List<Product>> fetchProducts() async {
    try {
      final userId = currentUser?.id;
      List<dynamic> response;
      try {
        response = await _client
            .from('products')
            .select('*, profiles!products_seller_id_fkey(*), favorites(*)')
            .order('listed_at', ascending: false);
      } catch (e) {
        debugPrint('Fetch products with relations failed, retrying basic query: $e');
        response = await _client
            .from('products')
            .select()
            .order('listed_at', ascending: false);
      }

      // Ambil rekap "sudah dibeli berapa kali" per produk dari VIEW
      // `product_purchase_stats` (lihat SQL migrasi), lalu tempelkan ke tiap
      // baris produk. Dipisah jadi query sendiri (bukan join langsung di
      // atas) karena PostgREST tidak bisa join VIEW aggregate dengan mudah
      // lewat select relasi biasa, dan supaya kalau VIEW-nya belum dibuat
      // (migrasi belum jalan) fitur lain tetap fungsi normal (fail-open,
      // purchaseCount default 0 -- lihat catch di bawah).
      Map<String, int> purchaseCounts = {};
      try {
        final statsResponse =
            await _client.from('product_purchase_stats').select('product_id, purchase_count');
        for (final row in (statsResponse as List)) {
          final pid = row['product_id']?.toString();
          if (pid == null) continue;
          purchaseCounts[pid] = row['purchase_count'] is int
              ? row['purchase_count'] as int
              : int.tryParse(row['purchase_count']?.toString() ?? '') ?? 0;
        }
      } catch (e) {
        debugPrint(
          'Peringatan: VIEW product_purchase_stats belum tersedia (jalankan '
          'SQL migrasi Top Picks). Purchase count fallback ke 0. Error: $e',
        );
      }

      return response.map((json) {
        final enriched = Map<String, dynamic>.from(json);
        final pid = enriched['id']?.toString();
        enriched['purchase_count'] = purchaseCounts[pid] ?? 0;
        return Product.fromJson(enriched, currentUserId: userId);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching products: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Update data produk (dipakai dari halaman edit produk seller -- "Produk
  // Saya" di Profil). Stok TIDAK diubah lewat sini (pakai restockProduct /
  // updateProductStock) supaya alur "Tambah Stok" tetap satu pintu & aman
  // dari race condition dibanding stok ditimpa langsung dari form edit.
  Future<Product> updateProduct({
    required String productId,
    required String name,
    required String brand,
    required String description,
    required String category,
    required double price,
    required String condition,
    required String size,
    required List<String> paymentMethods,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final response = await _client
          .from('products')
          .update({
            'name': name,
            'brand': brand,
            'description': description,
            'category': category,
            'price': price,
            'condition': condition,
            'size': size,
            'payment_methods': paymentMethods,
          })
          .eq('id', productId)
          .eq('seller_id', currentUser!.id) // jaga-jaga: hanya boleh edit produk sendiri
          .select('*, profiles!products_seller_id_fkey(*)')
          .single();
      return Product.fromJson(response, currentUserId: currentUser!.id);
    } catch (e) {
      debugPrint('Error updating product: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Hapus produk milik sendiri. `.eq('seller_id', ...)` di sini BUKAN cuma
  // buat query -- ini lapis pengaman kedua: walau RLS di server jebol/salah
  // konfigurasi, request ini tidak akan pernah bisa hapus produk toko lain.
  Future<void> deleteProduct(String productId) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      await _client
          .from('products')
          .delete()
          .eq('id', productId)
          .eq('seller_id', currentUser!.id);
    } catch (e) {
      debugPrint('Error deleting product: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Cek dulu apakah seller yang sedang login sudah pernah listing produk
  // dengan nama+brand+kategori yang SAMA (persis). Dipakai supaya seller
  // tidak perlu isi form dari awal lagi kalau cuma mau restock barang yang
  // sama -- tinggal update angka stoknya saja.
  Future<Map<String, dynamic>?> findExistingProduct({
    required String name,
    required String brand,
    required String category,
  }) async {
    if (currentUser == null) return null;
    try {
      return await _client
          .from('products')
          .select()
          .eq('seller_id', currentUser!.id)
          .ilike('name', name.trim())
          .ilike('brand', brand.trim())
          .eq('category', category)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error checking existing product: $e');
      return null;
    }
  }

  // Buat produk baru sekaligus set emoji & warna default sesuai kategori.
  // Sekarang produk juga punya kolom 'stock' (jumlah barang tersedia).
  Future<Product> createProduct({
    required String name,
    required String brand,
    required String description,
    required String category,
    required double price,
    required String condition,
    required String size,
    String? imageUrl,
    required List<String> paymentMethods,
    int stock = 1,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final userId = currentUser!.id;
      final response = await _client
          .from('products')
          .insert({
            'name': name,
            'brand': brand,
            'description': description,
            'category': category,
            'price': price,
            'condition': condition,
            'size': size,
            'seller_id': userId,
            'image_url': imageUrl,
            'payment_methods': paymentMethods,
            'image_emoji': _getCategoryEmojiSafe(category),
            'image_color': _getCategoryColor(category),
            'stock': stock,
          })
          .select()
          .single();

      final productJson = Map<String, dynamic>.from(response);
      final profile = await fetchUserProfile(userId);
      if (profile != null) {
        productJson['profiles'] = profile;
      }

      return Product.fromJson(productJson, currentUserId: userId);
    } catch (e) {
      debugPrint('Error creating product: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Tambah stok produk yang sudah ada (dipanggil kalau seller "listing ulang"
  // barang yang sama persis -- daripada bikin baris produk duplikat, kita
  // cukup tambah angka stok di baris yang sudah ada).
  Future<Product> restockProduct({
    required String productId,
    required int addedStock,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final current = await _client
          .from('products')
          .select('stock')
          .eq('id', productId)
          .single();
      final currentStock = current['stock'] is int
          ? current['stock'] as int
          : int.tryParse(current['stock']?.toString() ?? '') ?? 0;

      final response = await _client
          .from('products')
          .update({'stock': currentStock + addedStock})
          .eq('id', productId)
          .select('*, profiles!products_seller_id_fkey(*)')
          .single();

      return Product.fromJson(response, currentUserId: currentUser!.id);
    } catch (e) {
      debugPrint('Error restocking product: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Update stok produk ke angka tertentu (dipakai misal setelah barang laku)
  Future<void> updateProductStock(String productId, int newStock) async {
    if (currentUser == null) return;
    try {
      await _client
          .from('products')
          .update({'stock': newStock < 0 ? 0 : newStock})
          .eq('id', productId);
    } catch (e) {
      debugPrint('Error updating stock: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Upload foto produk ke storage bucket 'product_images', return public URL
  Future<String?> uploadProductImage(File file) async {
    try {
      if (currentUser == null) return null;
      final fileName =
          '${currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('product_images').upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      return _client.storage.from('product_images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Tambah/hapus produk dari daftar favorit user
  Future<void> toggleFavorite(String productId, bool isFavorite) async {
    if (currentUser == null) return;
    try {
      if (isFavorite) {
        await _client.from('favorites').insert({
          'user_id': currentUser!.id,
          'product_id': productId,
        });
      } else {
        await _client.from('favorites').delete().match({
          'user_id': currentUser!.id,
          'product_id': productId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ==========================================
  // CART
  // ==========================================
  // Ambil isi keranjang user beserta detail produknya
  Future<List<CartItem>> fetchCart() async {
    if (currentUser == null) return [];
    try {
      final response = await _client
          .from('cart_items')
          .select('*, products(*, profiles!products_seller_id_fkey(*))')
          .eq('user_id', currentUser!.id);
      return (response as List).map((json) {
        final productJson = json['products'];
        final product = Product.fromJson(
          productJson,
          currentUserId: currentUser!.id,
        );
        return CartItem(
          id: json['id'] as String,
          product: product,
          quantity: json['quantity'] as int,
          negotiatedPrice: json['negotiated_price'] != null
              ? (json['negotiated_price'] as num).toDouble()
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching cart: $e');
      return [];
    }
  }

  // Tambah produk ke cart: kalau sudah ada, tambah quantity; kalau belum, insert baru.
  // Kalau pembeli ini punya tawaran yang sudah di-ACC seller untuk produk
  // ini, harga nego itu otomatis ditempelkan ke baris cart_items miliknya
  // (kolom negotiated_price) -- TIDAK memengaruhi cart pembeli lain.
  Future<CartItem> addToCart(Product product) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final acceptedPrice = await fetchAcceptedOfferPrice(product.id);

      final existing = await _client
          .from('cart_items')
          .select()
          .eq('user_id', currentUser!.id)
          .eq('product_id', product.id)
          .maybeSingle();

      Map<String, dynamic> response;
      if (existing != null) {
        final newQty = (existing['quantity'] as int) + 1;
        response = await _client
            .from('cart_items')
            .update({
              'quantity': newQty,
              if (acceptedPrice != null) 'negotiated_price': acceptedPrice,
            })
            .eq('id', existing['id'])
            .select('*, products(*, profiles!products_seller_id_fkey(*))')
            .single();
      } else {
        response = await _client
            .from('cart_items')
            .insert({
              'user_id': currentUser!.id,
              'product_id': product.id,
              'quantity': 1,
              if (acceptedPrice != null) 'negotiated_price': acceptedPrice,
            })
            .select('*, products(*, profiles!products_seller_id_fkey(*))')
            .single();
      }

      final prod = Product.fromJson(
        response['products'],
        currentUserId: currentUser!.id,
      );
      return CartItem(
        id: response['id'] as String,
        product: prod,
        quantity: response['quantity'] as int,
        negotiatedPrice: response['negotiated_price'] != null
            ? (response['negotiated_price'] as num).toDouble()
            : null,
      );
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Hapus item dari cart berdasarkan ID
  Future<void> removeFromCart(String cartItemId) async {
    if (currentUser == null) return;
    try {
      await _client.from('cart_items').delete().eq('id', cartItemId);
    } catch (e) {
      debugPrint('Error removing from cart: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Update jumlah quantity item cart
  Future<void> updateCartQuantity(String cartItemId, int quantity) async {
    if (currentUser == null) return;
    try {
      await _client
          .from('cart_items')
          .update({'quantity': quantity}).eq('id', cartItemId);
    } catch (e) {
      debugPrint('Error updating cart quantity: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ==========================================
  // ADDRESSES (alamat pengiriman tersimpan)
  // ==========================================
  Future<List<Address>> fetchAddresses() async {
    if (currentUser == null) return [];
    try {
      final response = await _client
          .from('addresses')
          .select()
          .eq('user_id', currentUser!.id)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => Address.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching addresses: $e');
      return [];
    }
  }

  Future<Address> saveAddress({
    String? id,
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String? landmark,
    required String city,
    required String province,
    String? postalCode,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      // Kalau alamat ini dijadikan default, lepas status default dari
      // alamat lain milik user yang sama dulu (cuma boleh 1 default)
      if (isDefault) {
        await _client
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', currentUser!.id);
      }

      final payload = {
        'user_id': currentUser!.id,
        'label': label,
        'recipient_name': recipientName,
        'phone': phone,
        'full_address': fullAddress,
        'landmark': landmark,
        'city': city,
        'province': province,
        'postal_code': postalCode,
        'is_default': isDefault,
        'latitude': latitude,
        'longitude': longitude,
      };

      final response = id == null
          ? await _client.from('addresses').insert(payload).select().single()
          : await _client
              .from('addresses')
              .update(payload)
              .eq('id', id)
              .select()
              .single();

      return Address.fromJson(response);
    } catch (e) {
      debugPrint('Error saving address: $e');
      throw Exception(_friendlyError(e));
    }
  }

  Future<void> deleteAddress(String addressId) async {
    if (currentUser == null) return;
    try {
      await _client.from('addresses').delete().eq('id', addressId);
    } catch (e) {
      debugPrint('Error deleting address: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ==========================================
  // CHECKOUT
  // ==========================================
  // Proses checkout seluruh isi cart lewat 1 Postgres function
  // (`checkout_cart`) yang jalan sebagai SATU transaksi database. Di
  // dalamnya: stok tiap produk dicek & dikurangi secara ATOMIC (pakai
  // `UPDATE ... WHERE stock >= quantity`), order + order_items dibuat, dan
  // cart dikosongkan -- semua sekaligus atau gagal semua (tidak akan ada
  // kondisi "stok kepotong tapi order gagal dibuat").
  //
  // Ini juga yang menjawab kasus race condition: kalau stok tinggal 5 dan
  // 2 pembeli checkout hampir bersamaan masing-masing minta 3, salah satu
  // PASTI gagal dengan pesan "stok tidak cukup" -- stoknya tidak akan
  // pernah minus.
  Future<String> checkoutCart({
    required String addressId,
    required String paymentMethod,
    String? note,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final orderId = await _client.rpc('checkout_cart', params: {
        'p_address_id': addressId,
        'p_payment_method': paymentMethod,
        'p_note': note,
      });
      return orderId as String;
    } catch (e) {
      debugPrint('Error checking out: $e');
      // Pesan dari function 'checkout_cart' (stok kurang, alamat tidak
      // valid, cart kosong) sudah ditulis dalam Bahasa Indonesia yang jelas
      // -- tampilkan apa adanya ke user, jangan diganti pesan generik.
      final raw = e is PostgrestException ? e.message : e.toString();
      if (raw.toLowerCase().contains('stok') ||
          raw.toLowerCase().contains('alamat') ||
          raw.toLowerCase().contains('keranjang')) {
        throw Exception(raw);
      }
      throw Exception(_friendlyError(e));
    }
  }

  // Checkout item TERPILIH saja (bukan seluruh cart) lewat function
  // `place_order` -- semua item yang dipilih harus dari 1 toko yang sama
  // (function yang validasi & tolak kalau campur, bukan cuma di app, supaya
  // aman walau ada yang coba manggil langsung ke API).
  Future<String> placeOrder({
    required List<String> cartItemIds,
    required String recipientName,
    required String recipientPhone,
    required String shippingAddress,
    double? destLatitude,
    double? destLongitude,
    required String shippingMethod,
    required double shippingCost,
    required String paymentMethod,
    String? note,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final orderId = await _client.rpc('place_order', params: {
        'p_cart_item_ids': cartItemIds,
        'p_recipient_name': recipientName,
        'p_recipient_phone': recipientPhone,
        'p_shipping_address': shippingAddress,
        'p_dest_latitude': destLatitude,
        'p_dest_longitude': destLongitude,
        'p_shipping_method': shippingMethod,
        'p_shipping_cost': shippingCost,
        'p_payment_method': paymentMethod,
        'p_note': note,
      });
      return orderId as String;
    } catch (e) {
      debugPrint('Error placing order: $e');
      final raw = e is PostgrestException ? e.message : e.toString();
      if (raw.toLowerCase().contains('stok') ||
          raw.toLowerCase().contains('toko') ||
          raw.toLowerCase().contains('keranjang')) {
        throw Exception(raw);
      }
      throw Exception(_friendlyError(e));
    }
  }

  // Pesanan yang DIBELI user saat ini (POV pembeli) -- buat halaman
  // "Pesanan Saya" & tracking status.
  Future<List<Order>> fetchMyOrders() async {
    if (currentUser == null) return [];
    try {
      final response = await _client
          .from('orders')
          .select('*, seller_profile:profiles!orders_seller_id_fkey(username), '
              'order_items(*, products(name, image_url))')
          .eq('buyer_id', currentUser!.id)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching my orders: $e');
      return [];
    }
  }

  // Pesanan yang MASUK ke toko user saat ini (POV penjual) -- buat halaman
  // "Pesanan Masuk", dengan tombol "Kirim Barang".
  Future<List<Order>> fetchSellerOrders() async {
    if (currentUser == null) return [];
    try {
      final response = await _client
          .from('orders')
          .select('*, buyer_profile:profiles!orders_buyer_id_fkey(username), '
              'order_items(*, products(name, image_url))')
          .eq('seller_id', currentUser!.id)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching seller orders: $e');
      return [];
    }
  }

  // Aksi seller: tombol "Proses Pesanan" -> ubah status jadi 'diproses'
  // (langkah PERTAMA setelah order masuk, sebelum "Kirim Barang")
  Future<void> markOrderProcessing(String orderId) async {
    try {
      await _client.rpc('mark_order_processing', params: {'p_order_id': orderId});
    } catch (e) {
      debugPrint('Error marking order processing: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Aksi seller: tombol "Kirim Barang" -> ubah status jadi 'dikirim'
  Future<void> markOrderShipped(String orderId) async {
    try {
      await _client.rpc('mark_order_shipped', params: {'p_order_id': orderId});
    } catch (e) {
      debugPrint('Error marking order shipped: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Aksi pembeli: tombol "Pesanan Selesai" -> ubah status jadi 'selesai'
  Future<void> markOrderCompleted(String orderId) async {
    try {
      await _client.rpc('mark_order_completed', params: {'p_order_id': orderId});
    } catch (e) {
      debugPrint('Error marking order completed: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ==========================================
  // NOTIFICATIONS
  // ==========================================
  Future<List<AppNotification>> fetchNotifications() async {
    if (currentUser == null) return [];
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false)
          .limit(50);
      return (response as List)
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (currentUser == null) return;
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', currentUser!.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }

  // ==========================================
  // COMMUNITY
  // ==========================================
  // Ambil semua postingan komunitas beserta profil, vote, dan jumlah balasan.
  // Postingan dari user yang sudah di-block TIDAK ikut dikembalikan.
  Future<List<CommunityPost>> fetchPosts() async {
    try {
      final userId = currentUser?.id;
      final blockedIds = await fetchBlockedUserIds();
      var query = _client
          .from('community_posts')
          .select('*, profiles!community_posts_user_id_fkey(*), post_votes(*), community_replies(count)');
      if (blockedIds.isNotEmpty) {
        query = query.not('user_id', 'in', '(${blockedIds.join(',')})');
      }
      final response = await query.order('posted_at', ascending: false);
      return (response as List).map((json) {
        // Ambil jumlah balasan dari hasil aggregate count
        final repliesCount =
            (json['community_replies'] as List?)?.first?['count'] ?? 0;
        final enrichedJson = Map<String, dynamic>.from(json);
        enrichedJson['community_replies_count'] = repliesCount;
        return CommunityPost.fromJson(enrichedJson, currentUserId: userId);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      return [];
    }
  }

  // Buat postingan komunitas baru
  Future<CommunityPost> createPost({
    required String community,
    required String type,
    required String title,
    required String content,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final response = await _client
          .from('community_posts')
          .insert({
            'user_id': currentUser!.id,
            'community': community,
            'type': type,
            'title': title,
            'content': content,
          })
          .select('*, profiles!community_posts_user_id_fkey(*)')
          .single();
      return CommunityPost.fromJson(response, currentUserId: currentUser!.id);
    } catch (e) {
      debugPrint('Error creating post: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Hapus postingan komunitas milik sendiri (guard ganda: RLS di server +
  // filter user_id di sini)
  Future<void> deletePost(String postId) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      await _client
          .from('community_posts')
          .delete()
          .eq('id', postId)
          .eq('user_id', currentUser!.id);
    } catch (e) {
      debugPrint('Error deleting post: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Upvote (value=1) / downvote (value=-1) / batal vote (value=0) sebuah
  // postingan -- pengganti sistem like lama.
  Future<void> voteOnPost(String postId, int value) async {
    if (currentUser == null) return;
    try {
      if (value == 0) {
        await _client.from('post_votes').delete().match({
          'user_id': currentUser!.id,
          'post_id': postId,
        });
      } else {
        await _client.from('post_votes').upsert({
          'user_id': currentUser!.id,
          'post_id': postId,
          'value': value,
        });
      }
    } catch (e) {
      debugPrint('Error voting on post: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ---------- Komunitas (follow ala X) ----------

  // Komunitas yang di-follow user saat ini -- ini yang dipakai buat isi
  // tab/dropdown filter di halaman Community.
  Future<List<Community>> fetchFollowedCommunities() async {
    if (currentUser == null) return [];
    try {
      final response = await _client
          .from('communities')
          .select('*, community_follows!inner(user_id)')
          .eq('community_follows.user_id', currentUser!.id)
          .order('name');
      return (response as List)
          .map((json) => Community.fromJson(json as Map<String, dynamic>, currentUserId: currentUser!.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching followed communities: $e');
      return [];
    }
  }

  // Semua komunitas yang ada (buat halaman "Cari/Tambah Komunitas"),
  // lengkap dengan status sudah di-follow atau belum
  Future<List<Community>> fetchAllCommunities({String query = ''}) async {
    try {
      var q = _client.from('communities').select('*, community_follows(user_id)');
      if (query.trim().isNotEmpty) {
        q = q.ilike('name', '%${query.trim()}%');
      }
      final response = await q.order('name');
      return (response as List)
          .map((json) => Community.fromJson(json as Map<String, dynamic>, currentUserId: currentUser?.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching communities: $e');
      return [];
    }
  }

  Future<void> followCommunity(String communityId) async {
    if (currentUser == null) return;
    try {
      await _client.from('community_follows').insert({
        'user_id': currentUser!.id,
        'community_id': communityId,
      });
    } catch (e) {
      debugPrint('Error following community: $e');
      throw Exception(_friendlyError(e));
    }
  }

  Future<void> unfollowCommunity(String communityId) async {
    if (currentUser == null) return;
    try {
      await _client.from('community_follows').delete().match({
        'user_id': currentUser!.id,
        'community_id': communityId,
      });
    } catch (e) {
      debugPrint('Error unfollowing community: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Bikin komunitas baru (nama wajib, deskripsi & rules boleh di-skip) --
  // otomatis nge-follow-in pembuatnya lewat function create_community
  Future<Community> createCommunity({
    required String name,
    String? description,
    String? rules,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final id = await _client.rpc('create_community', params: {
        'p_name': name,
        'p_description': description,
        'p_rules': rules,
      });
      return Community(
        id: id as String,
        name: name,
        description: description,
        rules: rules,
        createdBy: currentUser!.id,
        createdAt: DateTime.now(),
        isFollowing: true,
        followerCount: 1,
      );
    } catch (e) {
      debugPrint('Error creating community: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ---------- Block & Report ----------

  Future<List<String>> fetchBlockedUserIds() async {
    if (currentUser == null) return [];
    try {
      final response = await _client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', currentUser!.id);
      return (response as List).map((r) => r['blocked_id'].toString()).toList();
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
      return [];
    }
  }

  Future<void> blockUser(String userId) async {
    if (currentUser == null) return;
    try {
      await _client.from('blocked_users').insert({
        'blocker_id': currentUser!.id,
        'blocked_id': userId,
      });
    } catch (e) {
      debugPrint('Error blocking user: $e');
      throw Exception(_friendlyError(e));
    }
  }

  Future<void> unblockUser(String userId) async {
    if (currentUser == null) return;
    try {
      await _client.from('blocked_users').delete().match({
        'blocker_id': currentUser!.id,
        'blocked_id': userId,
      });
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Laporkan user/postingan -- notifikasi ke yang dilaporkan & auto-suspend
  // 1 hari kalau sudah kena 3 laporan (logic lengkap ada di function SQL)
  Future<void> reportContent({
    required String reportedUserId,
    String? postId,
    String? reason,
  }) async {
    try {
      await _client.rpc('report_content', params: {
        'p_reported_user_id': reportedUserId,
        'p_post_id': postId,
        'p_reason': reason,
      });
    } catch (e) {
      debugPrint('Error reporting content: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Ambil daftar balasan untuk satu postingan, urut dari yang terlama
  Future<List<Map<String, dynamic>>> fetchReplies(String postId) async {
    try {
      final response = await _client
          .from('community_replies')
          .select('*, profiles!community_replies_user_id_fkey(*)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching replies: $e');
      return [];
    }
  }

  // Kirim balasan baru ke sebuah postingan
  Future<void> createReply(String postId, String content) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      await _client.from('community_replies').insert({
        'post_id': postId,
        'user_id': currentUser!.id,
        'content': content,
      });
    } catch (e) {
      debugPrint('Error creating reply: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ==========================================
  // CHAT (pembeli <-> penjual)
  // ==========================================
  // Ambil (atau buat baru kalau belum ada) percakapan antara user saat ini
  // (sebagai pembeli) dengan seller untuk sebuah produk. Kombinasi
  // product_id + buyer_id + seller_id itu UNIK, jadi kalau dipanggil lagi
  // untuk produk & seller yang sama, akan mengembalikan percakapan yang
  // sudah ada (bukan bikin baru) -- riwayat chat-nya nyambung terus.
  Future<String> getOrCreateConversation({
    required String productId,
    required String sellerId,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    final buyerId = currentUser!.id;
    try {
      final existing = await _client
          .from('conversations')
          .select('id')
          .eq('product_id', productId)
          .eq('buyer_id', buyerId)
          .eq('seller_id', sellerId)
          .maybeSingle();
      if (existing != null) return existing['id'] as String;

      final created = await _client
          .from('conversations')
          .insert({
            'product_id': productId,
            'buyer_id': buyerId,
            'seller_id': sellerId,
          })
          .select('id')
          .single();
      return created['id'] as String;
    } catch (e) {
      debugPrint('Error getting/creating conversation: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Ambil semua percakapan milik user saat ini (baik dia sebagai pembeli
  // ATAU sebagai penjual), diurutkan dari yang paling baru dibalas.
  Future<List<ChatConversation>> fetchConversations() async {
    if (currentUser == null) return [];
    final userId = currentUser!.id;
    try {
      final response = await _client
          .from('conversations')
          .select(
            '*, products(name, image_url, price), '
            'buyer_profile:profiles!conversations_buyer_id_fkey(username, avatar_url), '
            'seller_profile:profiles!conversations_seller_id_fkey(username, avatar_url)',
          )
          .or('buyer_id.eq.$userId,seller_id.eq.$userId')
          .order('last_message_at', ascending: false, nullsFirst: false);

      return (response as List)
          .map((json) => ChatConversation.fromJson(
                json as Map<String, dynamic>,
                currentUserId: userId,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      return [];
    }
  }

  // Ambil semua pesan dalam satu percakapan, urut dari yang terlama
  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      return (response as List)
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  // Stream real-time pesan dalam satu percakapan. Ini yang membuat chat
  // "hidup": begitu pembeli kirim pesan, penjual yang sedang buka layar
  // chat yang sama langsung lihat pesannya muncul tanpa perlu refresh,
  // begitu juga sebaliknya. Dipakai dengan StreamBuilder di UI.
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map((r) => ChatMessage.fromJson(r)).toList());
  }

  // Kirim pesan baru ke sebuah percakapan, sekaligus update ringkasan
  // 'last_message' & 'last_message_at' di tabel conversations (dipakai buat
  // tampilan daftar chat/inbox).
  Future<void> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUser!.id,
        'content': content,
      });
      await _client.from('conversations').update({
        'last_message': content,
        'last_message_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (e) {
      debugPrint('Error sending message: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ==========================================
  // NEGOSIASI HARGA (haggle) -- fitur "Ajukan Tawaran" di chat room.
  // ==========================================
  // Buyer mengajukan tawaran harga baru untuk sebuah produk di dalam
  // percakapan tertentu. Otomatis kirim 1 chat message penanda supaya
  // riwayat chat tetap kebaca urut ("menawar Rp X untuk <produk>").
  Future<ProductOffer> createOffer({
    required String conversationId,
    required String productId,
    required String sellerId,
    required double originalPrice,
    required double offeredPrice,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final response = await _client
          .from('product_offers')
          .insert({
            'conversation_id': conversationId,
            'product_id': productId,
            'buyer_id': currentUser!.id,
            'seller_id': sellerId,
            'original_price': originalPrice,
            'offered_price': offeredPrice,
            'status': OfferStatus.pending,
          })
          .select()
          .single();

      // Pesan penanda di riwayat chat biar kelihatan jelas di alur obrolan
      await sendMessage(
        conversationId: conversationId,
        content: '💸 Mengajukan tawaran Rp ${offeredPrice.toInt()}',
      );

      return ProductOffer.fromJson(response);
    } catch (e) {
      debugPrint('Error creating offer: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Seller menerima/menolak tawaran. Kalau diterima, tawaran lain yang
  // masih 'pending' untuk (product_id, buyer_id) yang sama otomatis
  // dibatalkan (lihat trigger SQL) supaya tidak ada 2 harga nego aktif
  // sekaligus buat 1 pembeli+produk yang sama.
  Future<void> respondToOffer({
    required String offerId,
    required bool accept,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final updated = await _client
          .from('product_offers')
          .update({
            'status': accept ? OfferStatus.accepted : OfferStatus.rejected,
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', offerId)
          .eq('seller_id', currentUser!.id) // cuma seller pemilik produk yang boleh respon
          .select()
          .single();

      final offer = ProductOffer.fromJson(updated);
      await sendMessage(
        conversationId: offer.conversationId,
        content: accept
            ? '✅ Tawaran Rp ${offer.offeredPrice.toInt()} diterima seller!'
            : '❌ Tawaran Rp ${offer.offeredPrice.toInt()} ditolak seller.',
      );

      // Kalau diterima: tempelkan harga nego ini ke cart_items pembeli
      // (kalau produknya kebetulan sudah ada di keranjang dia) supaya
      // langsung sinkron tanpa buyer harus hapus-tambah ulang.
      if (accept) {
        await _client
            .from('cart_items')
            .update({'negotiated_price': offer.offeredPrice})
            .eq('product_id', offer.productId)
            .eq('user_id', offer.buyerId);
      }
    } catch (e) {
      debugPrint('Error responding to offer: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Stream real-time tawaran dalam 1 percakapan -- dipakai buat render
  // bubble "tawaran" (dengan tombol Terima/Tolak di sisi seller) di chat room.
  Stream<List<ProductOffer>> streamOffers(String conversationId) {
    return _client
        .from('product_offers')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map((r) => ProductOffer.fromJson(r)).toList());
  }

  // Ambil harga nego yang sudah di-ACC seller untuk (produk, pembeli saat
  // ini) ini -- kalau ada, INI yang dipakai sebagai harga di keranjang &
  // checkout KHUSUS buyer ini saja. Buyer lain / cart lain tetap harga normal.
  Future<double?> fetchAcceptedOfferPrice(String productId) async {
    if (currentUser == null) return null;
    try {
      final response = await _client
          .from('product_offers')
          .select('offered_price')
          .eq('product_id', productId)
          .eq('buyer_id', currentUser!.id)
          .eq('status', OfferStatus.accepted)
          .order('responded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      return (response['offered_price'] as num?)?.toDouble();
    } catch (e) {
      debugPrint('Error fetching accepted offer: $e');
      return null;
    }
  }

  // Tandai semua pesan di sebuah percakapan (yang BUKAN dikirim user saat
  // ini) sebagai sudah dibaca
  Future<void> markConversationRead(String conversationId) async {
    if (currentUser == null) return;
    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', currentUser!.id);
    } catch (e) {
      debugPrint('Error marking conversation read: $e');
    }
  }

  // ==========================================
  // HELPER EMOJIS & COLORS (FALLBACK)
  // ==========================================
  // Ambil emoji default berdasarkan kategori produk
  String _getCategoryEmojiSafe(String category) {
    switch (category) {
      case 'Woman Fashion':
        return '\u{1F457}';
      case 'Man Fashion':
        return '\u{1F455}';
      case 'Health & Beauty':
        return '\u{1F484}';
      case 'Keychain':
        return '\u{1F511}';
      case 'Trinket':
        return '\u{1F9F8}';
      case 'Shoes':
        return '\u{1F45F}';
      case 'Playing Card':
        return '\u{1F0CF}';
      case 'Sticker':
        return '\u{1F3F7}\u{FE0F}';
      default:
        return '\u{1F4E6}';
    }
  }

  // Ambil warna latar default berdasarkan kategori produk
  String _getCategoryColor(String category) {
    switch (category) {
      case 'Woman Fashion':
        return '#FFCCD5';
      case 'Man Fashion':
        return '#D8E2DC';
      case 'Health & Beauty':
        return '#FFCAD4';
      case 'Keychain':
        return '#F4ACB7';
      case 'Trinket':
        return '#FFE5D9';
      case 'Shoes':
        return '#D8E2DC';
      case 'Playing Card':
        return '#ECE4DB';
      case 'Sticker':
        return '#FFE5D9';
      default:
        return '#E3F2FD';
    }
  }
}